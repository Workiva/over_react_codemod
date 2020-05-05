// Copyright 2020 Workiva Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:meta/meta.dart';
import 'package:over_react_codemod/src/util.dart';

import 'boilerplate_utilities.dart';

/// A data model used to inform whether a migration should occur,
/// and also - optionally - what comment should be left in place if a migration cannot occur.
class MigrationDecision {
  /// Whether the migration should take place.
  final bool yee;

  /// An optional "reason" comment that can be patched onto the node by calling [patchWithReasonComment].
  final String reason;

  MigrationDecision(this.yee, {this.reason});

  /// Patch the provided [node] with a "FIX ME" comment giving the [reason] that the migration was short-circuited.
  void patchWithReasonComment(
      ClassOrMixinDeclaration node, YieldPatch yieldPatch) {
    var fixmeCommentAlreadyAdded = false;
    if (reason != null) {
      final firstLineOfReasonComment = reason.trim().split('\n').first.trim();

      // Use allComments instead of the first one since comments on previous lines
      // separated by whitespace (e.g., the ignore comment on a factory when node is a props class)
      // are picked up.
      fixmeCommentAlreadyAdded = allCommentsForNode(node).any(
          (comment) => comment.toString().trim() == firstLineOfReasonComment);
    }

    if (reason == null || fixmeCommentAlreadyAdded) {
      return;
    }

    yieldPatch(node.offset, node.offset, reason);
  }
}

const _docsPage = 'https://github.com/Workiva/over_react_codemod/tree/master'
    '/docs/boilerplate_upgrade.md';

/// Converts a header name to its ID the same way GitHub does it.
///
/// _I couldn't find a definitive source on how it works, so this is a best guess based on what I've seen._
///
/// - Convert to lowercase
/// - Convert spaces to dashes
/// - Remove all punctuation besides underscores and dashes
String _markdownHeaderToId(String headerName) => headerName
    .toLowerCase()
    .replaceAll(RegExp(r'\s'), '-')
    .replaceAll(RegExp(r'[^\w-]'), '');

String boilerplateDocLink(String headerName) =>
    '$_docsPage#${_markdownHeaderToId(headerName)}';

String getExternalSuperclassReasonComment(
    String nodeName, String superclassName) {
  return '''
// FIXME: `$nodeName` could not be auto-migrated to the new over_react boilerplate because it extends from $superclassName, which comes from an external library.
// Once that component has been upgraded to the new boilerplate, see instructions here: ${boilerplateDocLink('External Superclass')}
''';
}

String getPublicApiReasonComment(String nodeName, List<String> locations) {
  if (locations.first == semverReportNotAvailable) {
    return '''
// FIXME: A Workiva Semver report was not found. `$nodeName` is assumed to be exported from a library in this repo and thus was not auto-migrated to the new over_react boilerplate.
//
// --------- If you are migrating an OSS library outside of Workiva ---------
// You do not have access to Workiva's internal Semver audit tool. 
// To complete the migration, you should:
//
//   1. Revert all changes to remove this FIX-ME comment
//   2. Re-run the migration script with the following flag:    
//
//        pub global run over_react_codemod:boilerplate_upgrade --treat-all-components-as-private
//
//   NOTE: The changes made to props / state classes by the codemod constitute breaking changes
//   if you publicly export them from your library. We strongly recommend that you release 
//   the subsequent changes in a major version.
//
// --------- If you are migrating a Workiva library ---------
// To complete the migration, you should:
//   1. Revert all changes to remove this FIX-ME comment
//   2. Generate a semver report by running the following script:
//
//        pub global activate semver_audit --hosted-url=https://pub.workiva.org
//        pub global run semver_audit generate 2> semver_report.json
//
//   3. Re-run the migration script:
//
//        pub global run over_react_codemod:boilerplate_upgrade
''';
  }
  return '''
// FIXME: `$nodeName` could not be auto-migrated to the new over_react boilerplate because it is exported from the following librar${locations.length > 1 ? 'ies' : 'y'} in this repo:
// ${locations.join("\n// ")} 
// Upgrading it would be considered a breaking change since consumer components can no longer extend from it. 
// For instructions on how to proceed, see: ${boilerplateDocLink('Public API')}
''';
}

String getUnMigratedSuperclassReasonComment(
    String nodeName, String superclassName) {
  return '''
// FIXME: `$nodeName` could not be auto-migrated to the new over_react boilerplate because it extends from `$superclassName`, which was not able to be migrated.
// Address comments on that component and then see instructions here: ${boilerplateDocLink('Unmigrated Superclass')}
''';
}

String getNonComponent2ReasonComment(
    String publicNodeName, String componentName) {
  return '''
// FIXME: `$publicNodeName` could not be auto-migrated to the new over_react boilerplate because `$componentName` does not extend from `UiComponent2`.
// For instructions on how to proceed, see: ${boilerplateDocLink('Non-Component2')}
''';
}

String getFixMeCommentForConvertedClassDeclaration({
  @required ClassToMixinConverter converter,
  @required String parentClassName,
  @required bool convertClassesWithExternalSuperclass,
}) {
  final extendsFromCustomNonReservedClass =
      !isReservedBaseClass(parentClassName);
  if (!extendsFromCustomNonReservedClass) return '';

  final fixMeBuffer = StringBuffer()..writeln('// FIXME:');

  if (extendsFromCustomNonReservedClass) {
    fixMeBuffer
      ..writeln(
          '//   1. Ensure that all mixins used by $parentClassName are also mixed into this class.')
      ..writeln(
          '//   2. Fix any analyzer warnings on this class about missing mixins.');
  }

  // Consumer is forcing classes that extend from / mix in external APIs to be converted.
  // Add more context about what they need to do next after they force the initial migration.
  if (convertClassesWithExternalSuperclass) {
    var externalApis = [parentClassName];

    if (externalApis.isNotEmpty) {
      fixMeBuffer.write('''
//   ${extendsFromCustomNonReservedClass ? '3' : '1'}. You should notice that ${externalApis.join(', ')} ${externalApis.length == 1 ? 'is' : 'are'} deprecated.  
//      Follow the deprecation instructions to consume the replacement by either updating your usage to
//      the new class/mixin name and/or updating to a different entrypoint that exports the ${externalApis.length == 1 ? 'version' : 'versions'} of 
//      ${externalApis.join(', ')} that ${externalApis.length == 1 ? 'is' : 'are'} compatible with the new over_react boilerplate.
//
//      If ${externalApis.length == 1 ? 'it is' : 'they are'} not deprecated, something most likely went wrong during the migration of the 
//      library that contains ${externalApis.length == 1 ? 'it' : 'them'}.        
''');
    }
  }

  return fixMeBuffer.toString();
}

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
      final firstLineOfReasonComment = reason.split('\n').first.trim();
      final firstLineOfNodeComment = node
          .firstTokenAfterCommentAndMetadata.precedingComments
          .toString()
          .trim();
      fixmeCommentAlreadyAdded =
          firstLineOfReasonComment == firstLineOfNodeComment;
    }

    if (reason == null || fixmeCommentAlreadyAdded) {
      return;
    }

    yieldPatch(node.firstTokenAfterCommentAndMetadata.offset,
        node.firstTokenAfterCommentAndMetadata.offset, reason);
  }
}

String getExternalSuperclassOrMixinReasonComment(
  String nodeName,
  List<String> superclassOrMixinNames, {
  bool mixinsAreExternal = false,
}) {
  final inheritanceReasonPortion =
      mixinsAreExternal ? 'mixes in' : 'extends from';

  return '''
  // FIXME: `$nodeName` could not be auto-migrated to the new over_react boilerplate because it $inheritanceReasonPortion: ${superclassOrMixinNames.join(', ')} - which ${superclassOrMixinNames.length == 1 ? 'comes' : 'come'} from an external library.
  //
  // To complete the migration, you should:
  //   1. Check on the boilerplate migration status of the library ${superclassOrMixinNames.length == 1 ? 'it comes' : 'they come'} from.
  //   2. Once the library has released a version that includes updated boilerplate,
  //      bump the lower bound of your dependency to that version in your `pubspec.yaml`, and run `pub get`.
  //   3. Re-run the migration script with the following flag:
  //      pub global run over_react_codemod:boilerplate_upgrade --convert-classes-with-external-superclasses
  //   4. Once the migration is complete, you should notice that ${superclassOrMixinNames.join(', ')} ${superclassOrMixinNames.length == 1 ? 'has' : 'have'} been deprecated. 
  //      Follow the deprecation instructions to consume the ${superclassOrMixinNames.length == 1 ? 'replacement' : 'replacements'} by either updating your usage to
  //      the new ${mixinsAreExternal ? 'mixin' : 'class'} ${superclassOrMixinNames.length == 1 ? 'name' : 'names'} and/or updating to a different entrypoint that exports the version(s) of 
  //      ${superclassOrMixinNames.join(', ')} that ${superclassOrMixinNames.length == 1 ? 'is' : 'are'} compatible with the new over_react boilerplate.
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
  // FIXME: `$nodeName` could not be auto-migrated to the new over_react boilerplate because it is exported from the following librar${locations.length > 1 ? 'ies' : 'y'} in this repo:${locations.join("\n// ")}
  //
  // Upgrading it would be considered a breaking change since consumer components can no longer extend from it.
  //
  // To complete the migration, you should: 
  //   1. Deprecate `$nodeName`.
  //   2. Make a copy of it, renaming it something like `${nodeName}V2`.
  //   3. Replace all your current usage of the deprecated `$nodeName` with `${nodeName}V2`.
  //   4. Add a `hide ${nodeName}V2` clause to all places where it is exported, and then run:
  //        pub global run over_react_codemod:boilerplate_upgrade
  //   5a. If `$nodeName` had consumers outside this repo, and it was intentionally made public,
  //       remove the `hide` clause you added in step 4 so that the new mixin created from `${nodeName}V2` 
  //       will be a viable replacement for `$nodeName`.
  //   5b. If `$nodeName` had no consumers outside this repo, and you have no reason to make the new
  //       "V2" class / mixin public, update the `hide` clause you added in step 4 to include both the 
  //       concrete class and the newly created mixin.
  //   6. Remove this FIX-ME comment.
  ''';
}

String getUnMigratedSuperclassReasonComment(
    String nodeName, String superclassName) {
  return '''
  // FIXME: `$nodeName` could not be auto-migrated to the new over_react boilerplate because it extends from `$superclassName`, which was not able to be migrated.
  //
  // To complete the migration, you should:
  //   1. Look at the FIX-ME comment that has been added to `$superclassName` - 
  //      and follow the steps outlined there to complete the migration.
  //   2. Re-run the migration script:
  //      pub global run over_react_codemod:boilerplate_upgrade
  ''';
}

String getFixMeCommentForConvertedClassDeclaration({
  @required ClassToMixinConverter converter,
  @required String parentClassName,
  @required bool convertClassesWithExternalSuperclass,
  List<String> mixinNames = const [],
}) {
  final extendsFromCustomNonReservedClass =
      !isReservedBaseClass(parentClassName);
  final usesExternalMixins = !mixinNames
      .where((name) => !isReservedBaseClass(name))
      .every(converter.wasVisited);
  if (!extendsFromCustomNonReservedClass && !usesExternalMixins) return '';

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
    final extendsFromExternalCustomClass = extendsFromCustomNonReservedClass &&
        !converter.wasVisited(parentClassName);
    final externalMixins =
        mixinNames.where((name) => !converter.wasVisited(name));
    var externalApis = extendsFromExternalCustomClass
        ? [parentClassName, ...externalMixins]
        : [...externalMixins];

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

// Copyright 2023 Workiva Inc.
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
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:codemod/codemod.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';

import '../util.dart';
import '../util/class_suggestor.dart';
import '../util/element_type_helpers.dart';
import 'constants.dart';

final _log = Logger('NamespaceUsageVisitor');

// todo update comment

// Suggestor namespaceUsageUpdater() {
//   return (context) async* {
//     final unitResult = await context.getResolvedUnit();
//     if (unitResult == null) {
//       // Most likely a part and not a library.
//       return;
//     }
//     final unusedImportErrors = unitResult.errors
//         .where((error) => error.errorCode.name.toLowerCase() == 'unused_import')
//         .toList();
//
//     final allImports = unitResult.unit.directives.whereType<ImportDirective>().toList();
//
//     for (final error in unusedImportErrors) {
//       final matchingImport =
//           allImports.singleWhere((import) => import.containsOffset(error.offset));
//       final importUri = matchingImport.uriContent;
//       if (importUri != null && importUri.startsWith('package:$packageName/')) {
//         final prevTokenEnd = matchingImport.beginToken.previous?.end;
//         // Try to take the newline before the import, but watch out
//         // for prevToken's offset/end being -1 if it's this import has the
//         // first token in the file.
//         final startOffset =
//             prevTokenEnd != null && prevTokenEnd != -1 ? prevTokenEnd : matchingImport.offset;
//         yield Patch('', startOffset, matchingImport.end);
//       }
//     }
//   };
// }

/// Suggestor that adds a [scriptToAdd] line after the last usage of a
/// react-dart script in a Dart string literal or list of string literals.
///
/// Meant to be run on Dart files (use [HtmlScriptAdder] to run on HTML files).
class NamespaceUsageUpdater extends GeneralizingAstVisitor with ClassSuggestor {
  NamespaceUsageUpdater();

  @override
  visitMethodInvocation(MethodInvocation node) {
    super.visitMethodInvocation(node);

    final importNamespace = node.target;
    if (importNamespace != null) {
      final newImportNamespace = rmuiImportsToUpdate
          .where((import) =>
              import.possibleMuiNamespaces?.contains(importNamespace.toSource()) ?? false)
          .singleOrNull
          ?.namespace;
      if (newImportNamespace != null) {
        yieldPatch(newImportNamespace, importNamespace.offset, importNamespace.end);
      }
    }
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    super.visitPrefixedIdentifier(node);

    // Replace 'mui' namespaces usage with 'unify'.
    final uri = node.identifier.staticElement?.source?.uri;
    // if (uri != null && isUriWithinPackage(uri, 'react_material_ui')) {
    final importNamespace = node.prefix;
    final newImportNamespace = rmuiImportsToUpdate
        .where((import) => import.possibleMuiNamespaces?.contains(importNamespace.name) ?? false)
        .singleOrNull
        ?.namespace;
    if (newImportNamespace != null) {
      yieldPatch(newImportNamespace, importNamespace.offset, importNamespace.end);
    }
    // }
  }

  @override
  Future<void> generatePatches() async {
    _log.info('Resolving ${context.relativePath}...');

    final result = await context.getResolvedUnit();
    if (result == null) {
      throw Exception('Could not get resolved result for "${context.relativePath}"');
    }
    result.unit.visitChildren(this);
  }

  @override
  bool shouldSkip(FileContext context) => hasParseErrors(context.sourceText);
}

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
import 'package:codemod/codemod.dart';

import '../util/importer.dart';
import 'constants.dart';

/// Suggestor that updates imports from [oldPackageName] to [newPackageName].
// class ImportRenamer extends RecursiveAstVisitor<void> with AstVisitingSuggestor {
//   final String oldPackageName;
//   final String newPackageName;
//   final String oldPackageNamespace;
//   final String newPackageNamespace;
//
//   ImportRenamer(
//       {required this.oldPackageName,
//       required this.newPackageName,
//       required this.oldPackageNamespace,
//       required this.newPackageNamespace});
//
//   @override
//   Future<void> visitImportDirective(ImportDirective node) async {
//     super.visitImportDirective(node);
//
//     final importUri = node.uri.stringValue;
//     final namespace = node.prefix;
//     if (importUri != null && importUri.startsWith('package:$oldPackageName/')) {
//       final specialCaseRmuiImport =
//           rmuiImportsToUpdate.where((import) => importUri == import.rmuiUri);
//       if (specialCaseRmuiImport.isNotEmpty) {
//         yieldPatch('\'${specialCaseRmuiImport.single.uri}\'', node.uri.offset, node.uri.end);
//
//         final newNamespace = specialCaseRmuiImport.single.namespace;
//         if (namespace != null &&
//             newNamespace != null &&
//             (specialCaseRmuiImport.single.possibleMuiNamespaces?.contains(namespace.name) ??
//                 false)) {
//           yieldPatch(newNamespace, namespace.offset, namespace.end);
//         }
//       } else {
//         yieldPatch(
//             '\'${importUri.replaceFirst('package:$oldPackageName/', 'package:$newPackageName/')}\'',
//             node.uri.offset,
//             node.uri.end);
//       }
//
//       // Update the namespace if necessary.
//       if (namespace != null && namespace.name == oldPackageNamespace) {
//         yieldPatch(newPackageNamespace, namespace.offset, namespace.end);
//       }
//
//       // final libraryResult = await context.getResolvedLibrary();
//       // if (libraryResult == null) {
//       //   // Most likely a part and not a library.
//       //   return;
//       // }
//       // // Parts that have not been generated can show up as `exists = false` but also `isPart = false`,
//       // // so using the unitResults is a little trickier than using the libraryElement to get it.
//       // final mainLibraryUnitResult = libraryResult.units.singleWhere((unitResult) =>
//       // unitResult.unit.declaredElement == libraryResult.element.definingCompilationUnit);
//       // final insertInfo = insertionLocationForPackageImport(
//       //     importUri, mainLibraryUnitResult.unit, mainLibraryUnitResult.lineInfo);
//       // yield Patch(
//       // insertInfo.leadingNewlines +
//       //     "import '$importUri' as $importNamespace;" +
//       //     insertInfo.trailingNewlines,
//       // insertInfo.offset,
//       // insertInfo.offset);
//     }
//   }
// }

Suggestor importRenamerSuggestorBuilder({
  required String oldPackageName,
  required String newPackageName,
  required String oldPackageNamespace,
  required String newPackageNamespace,
}) {
  return (context) async* {
    final libraryResult = await context.getResolvedLibrary();
    if (libraryResult == null) {
      // Most likely a part and not a library.
      return;
    }

    // Parts that have not been generated can show up as `exists = false` but also `isPart = false`,
    // so using the unitResults is a little trickier than using the libraryElement to get it.
    final mainLibraryUnitResult = libraryResult.units.singleWhere((unitResult) =>
        unitResult.unit.declaredElement == libraryResult.element.definingCompilationUnit);

    // Look for imports with old package name.
    final importsToUpdate = mainLibraryUnitResult.unit.directives
        .whereType<ImportDirective>()
        .where((import) => import.uri.stringValue?.startsWith('package:$oldPackageName/') ?? false);

    final newImportsInfo = <UnifyImportInfo>[];
    for (final import in importsToUpdate) {
      final importUri = import.uri.stringValue;
      final namespace = import.prefix?.name;
      var newImportUri =
          importUri?.replaceFirst('package:$oldPackageName/', 'package:$newPackageName/');
      var newNamespace = namespace == oldPackageNamespace ? newPackageNamespace : namespace;
      final specialCaseRmuiImport = rmuiImportsToUpdate.where((i) => importUri == i.rmuiUri);
      if (specialCaseRmuiImport.isNotEmpty) {
        newImportUri = specialCaseRmuiImport.single.uri;

        final specialCaseNamespace = specialCaseRmuiImport.single.namespace;
        if (namespace != null &&
            specialCaseNamespace != null &&
            (specialCaseRmuiImport.single.possibleMuiNamespaces?.contains(namespace) ?? false)) {
          newNamespace = specialCaseNamespace;
        }
      }

      if (newImportUri != null) {
        newImportsInfo.add(UnifyImportInfo(newImportUri, namespace: newNamespace));
      }

      final prevTokenEnd = import.beginToken.previous?.end;
      // Try to take the newline before the import, but watch out
      // for prevToken's offset/end being -1 if it's this import has the
      // first token in the file.
      final startOffset = prevTokenEnd != null && prevTokenEnd != -1 ? prevTokenEnd : import.offset;
      yield Patch('', startOffset, import.end);
    }

    // Sort imports before adding them.
    newImportsInfo.sort((a, b) => a.uri.compareTo(b.uri));

    for (final importInfo in newImportsInfo) {
      final insertInfo = insertionLocationForPackageImport(
          importInfo.uri, mainLibraryUnitResult.unit, mainLibraryUnitResult.lineInfo);
      yield Patch(
          insertInfo.leadingNewlines +
              "import '${importInfo.uri}'${importInfo.namespace != null ? ' as ${importInfo.namespace}' : ''};" +
              insertInfo.trailingNewlines,
          insertInfo.offset,
          insertInfo.offset);
    }

    //   if (newImportUri != null) {
    //     final insertInfo = insertionLocationForPackageImport(
    //         newImportUri, mainLibraryUnitResult.unit, mainLibraryUnitResult.lineInfo);
    //     yield Patch(
    //         insertInfo.leadingNewlines +
    //             "import '$newImportUri'${newNamespace != null ? ' as $newNamespace' : ''};" +
    //             insertInfo.trailingNewlines,
    //         insertInfo.offset,
    //         insertInfo.offset);
    //   }
    //
    //   final prevTokenEnd = import.beginToken.previous?.end;
    //   // Try to take the newline before the import, but watch out
    //   // for prevToken's offset/end being -1 if it's this import has the
    //   // first token in the file.
    //   final startOffset = prevTokenEnd != null && prevTokenEnd != -1 ? prevTokenEnd : import.offset;
    //   yield Patch('', startOffset, import.end);
    // }

    // for(final import in importsToUpdate) {
    //
    // }
    // if (importUri != null && importUri.startsWith('package:$oldPackageName/')) {
    //   if (specialCaseRmuiImport.isNotEmpty) {
    //     yieldPatch('\'${specialCaseRmuiImport.single.uri}\'', node.uri.offset, node.uri.end);
    //
    //     final newNamespace = specialCaseRmuiImport.single.namespace;
    //     if (namespace != null &&
    //         newNamespace != null &&
    //         (specialCaseRmuiImport.single.possibleMuiNamespaces?.contains(namespace.name) ??
    //             false)) {
    //       yieldPatch(newNamespace, namespace.offset, namespace.end);
    //     }
    //   } else {
    //     yieldPatch(
    //         '\'${importUri.replaceFirst('package:$oldPackageName/', 'package:$newPackageName/')}\'',
    //         node.uri.offset,
    //         node.uri.end);
    //   }
    //
    //   // Update the namespace if necessary.
    //   if (namespace != null && namespace.name == oldPackageNamespace) {
    //     yieldPatch(newPackageNamespace, namespace.offset, namespace.end);
    //   }

    // Look for errors in the main compilation unit and its part files.
    // Ignore null partContexts and partContexts elements caused by
    // resolution issues and parts being excluded in the codemod file list.
    // final needsMuiImport = libraryResult.units
    //     .expand((unitResult) => unitResult.errors)
    //     .where((error) => error.errorCode.name == 'UNDEFINED_IDENTIFIER')
    //     .any((error) => error.message.contains("Undefined name '$importNamespace'"));
    //
    // if (!needsMuiImport) return;
  };
}

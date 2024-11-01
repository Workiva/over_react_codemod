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
Suggestor importRenamerSuggestorBuilder({
  required String oldPackageName,
  required String newPackageName,
}) {
  return (context) async* {
    final libraryResult = await context.getResolvedLibrary();
    if (libraryResult == null) {
      // Most likely a part and not a library.
      return;
    }

    // Parts that have not been generated can show up as `exists = false` but also `isPart = false`,
    // so using the unitResults is a little trickier than using the libraryElement to get it.
    final mainLibraryUnitResult = libraryResult.units.singleWhere(
        (unitResult) =>
            unitResult.unit.declaredElement ==
            libraryResult.element.definingCompilationUnit);

    // Look for imports with old package name.
    final importsToUpdate = mainLibraryUnitResult.unit.directives
        .whereType<ImportDirective>()
        .where((import) =>
            import.uri.stringValue?.startsWith('package:$oldPackageName/') ??
            false);

    final newImportsInfo = <UnifyImportInfo>[];
    for (final import in importsToUpdate) {
      final importUri = import.uri.stringValue;
      final namespace = import.prefix?.name;
      var newImportUri = importUri?.replaceFirst(
          'package:$oldPackageName/', 'package:$newPackageName/');

      // Check for special cases where the unify_ui import path does not match the previous RMUI path.
      final specialCaseRmuiImport =
          rmuiImportsToUpdate.where((i) => importUri == i.rmuiUri);
      if (specialCaseRmuiImport.isNotEmpty) {
        newImportUri = specialCaseRmuiImport.single.uri;
      }

      if (newImportUri != null) {
        // Collect info on new imports to add.
        newImportsInfo.add(UnifyImportInfo(newImportUri,
            namespace: namespace,
            showHideInfo: import.combinators.isEmpty
                ? null
                : import.combinators.map((c) => c.toSource()).join(' ')));
      }

      final prevTokenEnd = import.beginToken.previous?.end;
      // Try to take the newline before the import, but watch out
      // for prevToken's offset/end being -1 if it's this import has the
      // first token in the file.
      final startOffset = prevTokenEnd != null && prevTokenEnd != -1
          ? prevTokenEnd
          : import.offset;
      yield Patch('', startOffset, import.end);
    }

    // Sort imports before adding them.
    newImportsInfo.sort((a, b) => a.uri.compareTo(b.uri));

    // Add imports in their alphabetical positions.
    for (final importInfo in newImportsInfo) {
      final insertInfo = insertionLocationForPackageImport(importInfo.uri,
          mainLibraryUnitResult.unit, mainLibraryUnitResult.lineInfo);
      yield Patch(
          insertInfo.leadingNewlines +
              "import '${importInfo.uri}'${importInfo.namespace != null ? ' as ${importInfo.namespace}' : ''}${importInfo.showHideInfo != null ? ' ${importInfo.showHideInfo}' : ''};" +
              insertInfo.trailingNewlines,
          insertInfo.offset,
          insertInfo.offset);
    }
  };
}

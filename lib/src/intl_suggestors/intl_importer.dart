// Copyright 2021 Workiva Inc.
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

import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:codemod/codemod.dart';
import 'package:collection/collection.dart';
import 'package:path/path.dart' as path;

Stream<Patch> intlImporter(
    FileContext context, String projectName, String className) async* {
  final libraryResult = await context.getResolvedLibrary();
  if (libraryResult == null) {
    // Most likely a part and not a library.
    return;
  }

  // Parts that have not been generated can show up as `exists = false` but also `isPart = false`,
  // so using the unitResults is a little trickier than using the libraryElement to get it.
  final mainLibraryUnitResult = libraryResult.units.singleWhere((unitResult) =>
      unitResult.unit.declaredElement ==
      libraryResult.element.definingCompilationUnit);

  final needsIntlImport = libraryResult.units
      .expand((unitResult) => unitResult.errors)
      .where((error) => error.errorCode.name == 'UNDEFINED_IDENTIFIER')
      .any((error) => error.message.contains("Undefined name '$className'"));

  if (!needsIntlImport) return;

  final intlFilePath = '/src/intl/${projectName}_intl.dart';
  final intlUri = 'package:${projectName}' + intlFilePath;
  final intlDirectory = path.join(context.root, intlFilePath);
  final relativePathToIntlDir =
      path.relative(intlDirectory, from: Directory.current.path);
  final insertInfo = _insertionLocationForPackageImport(
      intlUri, mainLibraryUnitResult.unit, mainLibraryUnitResult.lineInfo);

  final importStatement = insertInfo.usePackageImports
      ? packageImport(intlUri, insertInfo)
      : relativeImport(relativePathToIntlDir, insertInfo);

  yield Patch(importStatement, insertInfo.offset, insertInfo.offset);
}

String packageImport(String intlUri, _InsertionLocation insertInfo) =>
    insertInfo.leadingNewlines +
    "import '$intlUri';" +
    insertInfo.trailingNewlines;

String relativeImport(
        String relativeImportPath, _InsertionLocation insertInfo) =>
    insertInfo.leadingNewlines +
    "import '$relativeImportPath';" +
    insertInfo.trailingNewlines;

class _InsertionLocation {
  final int offset;
  final int leadingNewlineCount;
  final int trailingNewlineCount;
  final bool usePackageImports;

  _InsertionLocation(
    this.offset, {
    this.leadingNewlineCount = 0,
    this.trailingNewlineCount = 0,
    this.usePackageImports = false,
  });

  String get leadingNewlines => '\n' * leadingNewlineCount;

  String get trailingNewlines => '\n' * trailingNewlineCount;
}

/// Finds an insertion location for a `package:` import, trying to
/// insert it alongside other `package:` imports in alphabetical order,
/// otherwise inserting it in a new section relative to other imports
/// or other directives.
_InsertionLocation _insertionLocationForPackageImport(
    String importUri, CompilationUnit unit, LineInfo lineInfo) {
  final imports = unit.directives.whereType<ImportDirective>();
  final firstImport = imports.firstOrNull;

  final dartImports =
      imports.where((i) => i.uri.stringValue?.startsWith('dart:') ?? false);
  final lastDartImport = dartImports.lastOrNull;

  final packageImports =
      imports.where((i) => i.uri.stringValue?.startsWith('package:') ?? false);
  final firstPackageImportSortedAfterNewImport = packageImports
      .where((i) => i.uri.stringValue!.compareTo(importUri) > 0)
      .firstOrNull;
  final lastPackageImportSortedBeforeNewImport = packageImports
      .where((i) => i.uri.stringValue!.compareTo(importUri) < 0)
      .lastOrNull;

  final firstNonImportDirective =
      unit.directives.where((d) => d is! ImportDirective).firstOrNull;

  final AstNode relativeNode;
  final bool insertAfter;
  final bool inOwnSection;
  bool hasOnlyPackageImports;
  if (firstPackageImportSortedAfterNewImport != null) {
    relativeNode = firstPackageImportSortedAfterNewImport;
    insertAfter = false;
    inOwnSection = false;
  } else if (lastPackageImportSortedBeforeNewImport != null) {
    relativeNode = lastPackageImportSortedBeforeNewImport;
    insertAfter = true;
    inOwnSection = false;
  } else if (lastDartImport != null) {
    relativeNode = lastDartImport;
    insertAfter = true;
    inOwnSection = true;
  } else if (firstImport != null) {
    relativeNode = firstImport;
    insertAfter = false;
    inOwnSection = true;
  } else if (firstNonImportDirective != null) {
    // No imports to insert relative to; try to insert relative to another directive.
    relativeNode = firstNonImportDirective;
    // Imports must come after libraries, and should come
    // before non-import directives (they also must come before parts).
    insertAfter = firstNonImportDirective is LibraryDirective;
    inOwnSection = true;
  } else {
    // No directive to insert relative to; insert before the first member or
    // at the beginning of the file.
    return _InsertionLocation(unit.declarations.firstOrNull?.offset ?? 0,
        trailingNewlineCount: 2, usePackageImports: true);
  }

  hasOnlyPackageImports = !imports.any((importDirective) {
    final uriContent = importDirective.uri.stringValue;
    if (uriContent != null) {
      final uri = Uri.parse(uriContent);
      return uri != null && uri.scheme != 'package' && uri.scheme != 'dart:';
    }
    return true;
  });

  print(hasOnlyPackageImports);

  return _InsertionLocation(
      insertAfter ? relativeNode.end : relativeNode.offset,
      leadingNewlineCount: insertAfter ? (inOwnSection ? 2 : 1) : 0,
      trailingNewlineCount: !insertAfter ? (inOwnSection ? 2 : 1) : 0,
      usePackageImports: hasOnlyPackageImports);
}

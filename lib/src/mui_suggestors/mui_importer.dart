import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:codemod/codemod.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';

import 'constants.dart';

final _log = Logger('muiImporter');

/// A suggestor that adds imports in libraries that reference
/// the [muiNs] import namespace (including in parts) but don't yet import it.
Stream<Patch> muiImporter(FileContext context) async* {
  final libraryResult = await context.getResolvedLibrary();
  if (libraryResult == null) {
    // Most likely a part and not a library.
    return;
  }

  final libraryElement = libraryResult.element;
  final unitResults = libraryResult.units;
  if (libraryElement == null || unitResults == null) {
    _log.warning('Could not resolve ${context.relativePath}');
    return;
  }

  // Parts that have not been generated can show up as `exists = false` but also `isPart = false`,
  // so using the unitResults is a little trickier than using the libraryElement to get it.
  final mainLibraryUnitResult = unitResults.singleWhere((unitResult) =>
      unitResult.unit?.declaredElement ==
      libraryElement.definingCompilationUnit);
  if (mainLibraryUnitResult.unit == null) {
    _log.warning('Could not resolve ${context.relativePath}');
    return;
  }

  // Look for errors in the main compilation unit and its part files.
  // Ignore null partContexts and partContexts elements caused by
  // resolution issues and parts being excluded in the codemod file list.
  final needsMuiImport = unitResults
      .expand((unitResult) => unitResult.errors)
      .where((error) => error.errorCode.name == 'UNDEFINED_IDENTIFIER')
      .any((error) => error.message.contains("Undefined name '$muiNs'"));

  if (!needsMuiImport) return;

  const rmuiImportUri = 'package:react_material_ui/react_material_ui.dart';

  final insertInfo = _insertionLocationForPackageImport(rmuiImportUri,
      mainLibraryUnitResult.unit!, mainLibraryUnitResult.lineInfo);
  yield Patch(
      insertInfo.leadingNewlines +
          "import '$rmuiImportUri' as $muiNs;" +
          insertInfo.trailingNewlines,
      insertInfo.offset,
      insertInfo.offset);
}

class _InsertionLocation {
  final int offset;
  final int leadingNewlineCount;
  final int trailingNewlineCount;

  _InsertionLocation(
    this.offset, {
    this.leadingNewlineCount = 0,
    this.trailingNewlineCount = 0,
  });

  String get leadingNewlines => '\n' * leadingNewlineCount;

  String get trailingNewlines => '\n' * trailingNewlineCount;
}

/// Finds an insertion location for a `packageL` import, trying to
/// insert it alongside other `package:` imports in alphabetical order,
/// otherwise inserting it in a new section relative to other imports
/// or other directives.
_InsertionLocation _insertionLocationForPackageImport(
    String importUri, CompilationUnit unit, LineInfo lineInfo) {
  final imports = unit.directives.whereType<ImportDirective>();
  final firstImport = imports.firstOrNull;

  final dartImports =
      imports.where((i) => i.uriContent?.startsWith('dart:') ?? false);
  final lastDartImport = dartImports.lastOrNull;

  final packageImports =
      imports.where((i) => i.uriContent?.startsWith('package:') ?? false);
  final firstPackageImportSortedAfterNewImport = packageImports
      .where((i) => i.uriContent!.compareTo(importUri) > 0)
      .firstOrNull;
  final lastPackageImportSortedBeforeNewImport = packageImports
      .where((i) => i.uriContent!.compareTo(importUri) < 0)
      .lastOrNull;

  final firstNonImportDirective =
      unit.directives.where((d) => d is! ImportDirective).firstOrNull;

  final AstNode relativeNode;
  final bool insertAfter;
  final bool inOwnSection;
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
        trailingNewlineCount: 2);
  }

  return _InsertionLocation(
    insertAfter ? relativeNode.end : relativeNode.offset,
    leadingNewlineCount: insertAfter ? (inOwnSection ? 2 : 1) : 0,
    trailingNewlineCount: !insertAfter ? (inOwnSection ? 2 : 1) : 0,
  );
}

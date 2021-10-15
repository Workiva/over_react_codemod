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

class _InsertionInfo {
  final int offset;
  final int leadingNewlineCount;
  final int trailingNewlineCount;

  _InsertionInfo(
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
_InsertionInfo _insertionLocationForPackageImport(
    String importUri, CompilationUnit unit, LineInfo lineInfo) {
  AstNode? relativeNode;
  bool? insertAfter;
  bool? inOwnSection;

  for (final directive in unit.directives) {
    if (directive is! ImportDirective) continue;
    final uriContent = directive.uriContent;
    if (uriContent == null) continue;

    if (uriContent.startsWith('package:')) {
      relativeNode = directive;
      insertAfter = importUri.compareTo(uriContent) > 0;
      inOwnSection = false;
    } else if (uriContent.startsWith('dart:')) {
      relativeNode = directive;
      insertAfter = true;
      inOwnSection = true;
    } else {
      // If we've already picked up a package/dart import,
      // we want to insert relative to that.
      if (relativeNode != null) continue;

      relativeNode = directive;
      insertAfter = false;
      inOwnSection = true;
    }
  }

  // No imports to insert relative to; try to insert relative to another directive.
  if (relativeNode == null) {
    final firstDirective =
        unit.directives.where((d) => d is! ImportDirective).firstOrNull;
    if (firstDirective != null) {
      relativeNode = firstDirective;
      // Imports must come after libraries, and should come
      // before non-import directives (they also must come before parts).
      insertAfter = firstDirective is LibraryDirective;
      inOwnSection = true;
    }
  }

  // No directive to insert relative to; insert before the first member or
  // at the beginning of the file.
  if (relativeNode == null) {
    return _InsertionInfo(unit.declarations.firstOrNull?.offset ?? 0,
        trailingNewlineCount: 2);
  }

  // iIf relativeNode is not null, these will be non-null as well.
  insertAfter!;
  inOwnSection!;

  return _InsertionInfo(
    insertAfter ? relativeNode.end : relativeNode.offset,
    leadingNewlineCount: insertAfter ? (inOwnSection ? 2 : 1) : 0,
    trailingNewlineCount: !insertAfter ? (inOwnSection ? 2 : 1) : 0,
  );
}

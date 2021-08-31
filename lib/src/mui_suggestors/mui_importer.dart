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

  final importOffset = _findImportInsertionLocation(rmuiImportUri,
      mainLibraryUnitResult.unit!, mainLibraryUnitResult.lineInfo);
  yield Patch(
      "import '$rmuiImportUri' as $muiNs;\n", importOffset, importOffset);
}

int _findImportInsertionLocation(
    String importUri, CompilationUnit unit, LineInfo lineInfo) {
  late int importOffset;
  if (unit.directives.isEmpty) {
    importOffset = unit.declarations.firstOrNull?.offset ?? 0;
  } else {
    // Insert the import in the right spot alphabetically.
    importOffset = 0;
    for (final directive in unit.directives) {
      if (directive is LibraryDirective) {
        importOffset = lineInfo.getOffsetOfLineAfter(directive.end);
      } else if (directive is ImportDirective) {
        final importString = directive.uri.stringValue;
        if (importString != null) {
          if (importUri.compareTo(importString) > 0) {
            importOffset = lineInfo.getOffsetOfLineAfter(directive.end);
          } else {
            break;
          }
        }
      } else if (directive is ExportDirective) {
        // Exports typically always come after imports.
        break;
      } else if (directive is PartDirective) {
        // Imports can't come after parts
        break;
      } else if (directive is PartOfDirective) {
        throw ArgumentError.value(
            unit, 'unit', 'must not be a unit representing a part file');
      } else {
        assert(false, 'Unhandled directive type: ${directive}');
        // Bail out to be safe when running without assertions.
        break;
      }
    }
  }
  return importOffset;
}

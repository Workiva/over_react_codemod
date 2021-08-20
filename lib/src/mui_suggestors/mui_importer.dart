import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:codemod/codemod.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:over_react_codemod/src/util/library_aggregate_suggestor.dart';

const muiNs = 'mui';

final _log = Logger('muiImporter');

/// A suggestor that adds imports in libraries that reference
/// the [muiNs] import namespace (including in parts) but don't yet import it.
LibraryAggregateSuggestor muiImporter = (
  FileContext context,
  List<FileContext?>? partContexts,
) async* {
  final result = await context.getResolvedUnit();
  final unit = result?.unit;

  if (result == null || unit == null) {
    _log.warning('Could not resolve ${context.relativePath}');
    return;
  }

  // Look for errors in the main compilation unit and its part files.
  // Ignore null partContexts and partContexts elements caused by
  // resolution issues and parts being excluded in the codemod file list.
  final needsMuiImport = await Stream.fromIterable([context, ...?partContexts])
      .whereNotNull()
      .asyncMap(_getResolvedErrorsForContext)
      // `errors` will be null if one of the units couldn't resolve.
      .expand((errors) => errors ?? <AnalysisError>[])
      .where((error) => error.errorCode.name == 'UNDEFINED_IDENTIFIER')
      .any((error) => error.message.contains("Undefined name '$muiNs'"));

  if (!needsMuiImport) return;

  const rmuiImportUri = 'package:react_material_ui/react_material_ui.dart';

  final importOffset =
      _findImportInsertionLocation(rmuiImportUri, unit, result.lineInfo);
  yield Patch(
      "import '$rmuiImportUri' as $muiNs;\n", importOffset, importOffset);
};

extension<T> on Stream<T?> {
  Stream<T> whereNotNull() async* {
    await for (var element in this) {
      if (element != null) yield element;
    }
  }
}

/// Returns a list of errors for a given compilation unit, or null if the unit
/// could not be resolved.
Future<List<AnalysisError>?> _getResolvedErrorsForContext(
    FileContext context) async {
  final result = await context.getResolvedUnit();
  if (result == null) {
    _log.warning('Could not resolve ${context.relativePath}');
    return null;
  }

  return result.errors;
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

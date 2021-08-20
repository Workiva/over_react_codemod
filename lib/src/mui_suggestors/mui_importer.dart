import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:codemod/codemod.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';

const muiNs = 'mui';

final _log = Logger('muiImporter');

Stream<Patch> muiImporter(
    FileContext context, List<FileContext> partsContexts) async* {
  final result = await context.getResolvedUnit();
  final unit = result?.unit;

  if (result == null || unit == null) {
    _log.warning('Could not resolve ${context.relativePath}');
    return;
  }

  // Look at errors in the main compilation unit and its part files.
  final needsMuiImport = await Stream.fromIterable([context, ...partsContexts])
      .asyncExpand(_getResolvedErrorsForContext)
      .where((error) => error.errorCode.name == 'UNDEFINED_IDENTIFIER')
      .any((error) => error.message.contains("Undefined name '$muiNs'"));

  if (!needsMuiImport) return;

  const rmuiImportUri = 'package:react_material_ui/react_material_ui.dart';

  final importOffset =
      _findImportInsertionLocation(rmuiImportUri, unit, result.lineInfo);
  yield Patch(
      "import '$rmuiImportUri' as $muiNs;\n", importOffset, importOffset);
}

// todo clean this up
Stream<AnalysisError> _getResolvedErrorsForContext(FileContext context) async* {
  final result = await context.getResolvedUnit();
  final unit = result?.unit;

  if (result == null || unit == null) {
    _log.warning('Could not resolve ${context.relativePath}');
    return;
  }

  yield* Stream.fromIterable(result.errors);
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

List<Suggestor> groupedLibrarySuggestor(
    Stream<Patch> Function(
            FileContext libraryContext, List<FileContext> partsContexts)
        suggestForGroup) {
  final contextsByPath = <String, FileContext>{};

  Stream<Patch> collectingSuggestor(FileContext context) async* {
    contextsByPath[context.path] = context;
  }

  // todo clean this up
  Stream<Patch> actualSuggestor(FileContext context) async* {
    final result = await context.getResolvedUnit();

    if (result?.isPart ?? false) return;

    final partContexts = result?.unit?.declaredElement?.library.parts
            .map((e) => contextsByPath[e.source.fullName])
            .whereNotNull()
            .toList() ??
        [];

    yield* suggestForGroup(context, partContexts);
  }

  return [collectingSuggestor, actualSuggestor];
}

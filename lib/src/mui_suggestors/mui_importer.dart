import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/line_info.dart';

// FIXME copy NodeLocator to this repo
// ignore: implementation_imports
import 'package:analyzer/src/dart/ast/utilities.dart' show NodeLocator;
import 'package:codemod/codemod.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:over_react_codemod/src/util/component_usage_migrator.dart';

const muiNs = 'mui';

final _log = Logger('muiImporter');

Stream<Patch> muiImporter(FileContext context) async* {
  final result = await context.getResolvedUnit();
  final unit = result?.unit;

  if (result == null || unit == null) {
    _log.warning('Could not resolve ${context.relativePath}');
    return;
  }

  final undefinedIdentifiers = result.errors
      .where((error) => error.errorCode.name == 'UNDEFINED_IDENTIFIER')
      .toList();

  final undefinedNames = undefinedIdentifiers
      .map((error) => NodeLocator(error.offset, error.offset + error.length)
          .searchWithin(unit))
      .whereType<SimpleIdentifier>()
      .toList();

  final needsMuiImport = undefinedNames.any((id) => id.name == muiNs);
  if (!needsMuiImport) return;

  if (result.isPart) {
    // todo is there a way to do this in libraries? This is pretty unfortunate
    // fixme check for this commment so this migrator can be idempotent
    yield Patch(
        blockComment(
                'FIXME(mui_migration) add mui import to the library of this part') +
            '\n',
        0,
        0);
    return;
  }

  const rmuiImportUri = 'package:react_material_ui/react_material_ui.dart';

  final importOffset =
      _findImportInsertionLocation(rmuiImportUri, unit, result.lineInfo);
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

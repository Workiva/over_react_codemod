import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/syntactic_entity.dart';
import 'package:codemod/codemod.dart';
import 'package:logging/logging.dart';

final _log = Logger('unusedWsdImportRemover');

/// A suggestor that removes unused imports for WSD.
Stream<Patch> unusedWsdImportRemover(FileContext context) async* {
  final unitResult = await context.getResolvedUnit();
  if (unitResult == null) {
    // Most likely a part and not a library.
    return;
  }
  final unit = unitResult.unit;
  if (unit == null) {
    _log.warning('Could not resolve ${context.relativePath}');
    return;
  }

  final unusedImportErrors = unitResult.errors
      .where((error) => error.errorCode.name.toLowerCase() == 'unused_import')
      .toList();

  final allImports = unit.directives.whereType<ImportDirective>().toList();

  for (final error in unusedImportErrors) {
    final matchingImport =
        allImports.singleWhere((import) => import.containsOffset(error.offset));
    final importUri = matchingImport.uriContent;
    if (importUri != null && importUri.startsWith('package:web_skin_dart/')) {
      yield Patch(
          '',
          // Try to take the newline before the import
          matchingImport.beginToken.previous?.end ?? matchingImport.offset,
          matchingImport.end);
    }
  }
}

extension on SyntacticEntity {
  bool containsOffset(int offset) => offset >= this.offset && offset < end;
}

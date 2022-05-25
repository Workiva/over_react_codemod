import 'package:analyzer/dart/ast/ast.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:file/file.dart';
import 'package:over_react_codemod/src/intl_suggestors/intl_migrator.dart';
import 'package:over_react_codemod/src/intl_suggestors/utils.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:over_react_codemod/src/util/component_usage_migrator.dart';

class IntlChildStringInterpolationMigrator extends ComponentUsageMigrator
    with IntlMigrator {

  @override
  bool shouldMigrateUsage(FluentComponentUsage usage) => usage.children
      .whereType<ExpressionComponentChild>()
      .where((child) => (child.node is StringInterpolation))
      .isNotEmpty;

  @override
  void migrateUsage(FluentComponentUsage usage) {
    super.migrateUsage(usage);
    migrateChildString(usage);
  }

  void migrateChildString(FluentComponentUsage usage) async {
    //Intl.message with args has to be declared in a top level function
    //So lets store that function at the end of the file
    final eofOffset =
        usage.node.thisOrAncestorOfType<CompilationUnit>()?.end ?? 0;
    usage.children.forEachIndexed((index, child) {

    if (isValidStringInterpolationNode(child.node)) {
      final functionCall = intlFunctionCall(child.node, index);
      final functionDef = intlFunctionDef(child.node, index);
      yieldPatchOverChildNode(functionCall, child);
      yieldPatch(functionDef, eofOffset);
    }
    });
  }
}

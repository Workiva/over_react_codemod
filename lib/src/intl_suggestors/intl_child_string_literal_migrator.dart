import 'package:analyzer/dart/ast/ast.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:file/file.dart';
import 'package:over_react_codemod/src/intl_suggestors/intl_migrator.dart';
import 'package:over_react_codemod/src/intl_suggestors/utils.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:over_react_codemod/src/util/component_usage_migrator.dart';

class IntlChildMigrator extends ComponentUsageMigrator with IntlMigrator {
  final String _namespace;

  IntlChildMigrator(this._namespace);

  @override
  bool shouldMigrateUsage(FluentComponentUsage usage) => usage.children
      .whereType<ExpressionComponentChild>()
      .where((child) => (child.node is SimpleStringLiteral))
      .isNotEmpty;

  @override
  void migrateUsage(FluentComponentUsage usage) {
    super.migrateUsage(usage);

    migrateChildString(usage);
    //Add child inside props usecase
  }

  void migrateChildString(FluentComponentUsage usage) async {
    usage.children
        .map((child) => child.node)
        .whereType<SimpleStringLiteral>()
        .forEachIndexed((index, node) {
      if (isNodeValidString(node)) {
        final name = toVariableName(node.value);
        yieldPatchOverNode(
          literalTemplate(_namespace, name, node.value),
          node,
        );
      }
    });
  }
}

bool isNodeValidString(SimpleStringLiteral node) {
  if (node.value.isEmpty) return false;
  if (double.tryParse(node.stringValue!) != null) return false;
  if (quotedCamelCase(node.value)) return false;
  if (node.value.length == 1) return false;
  return true;
}

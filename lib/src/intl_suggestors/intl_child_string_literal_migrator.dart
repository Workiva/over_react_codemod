import 'package:analyzer/dart/ast/ast.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:over_react_codemod/src/intl_suggestors/intl_deep_migrator.dart';
import 'package:over_react_codemod/src/intl_suggestors/intl_migrator.dart';
import 'package:over_react_codemod/src/intl_suggestors/utils.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:over_react_codemod/src/util/component_usage_migrator.dart';

class IntlChildStringLiteralMigrator extends ComponentUsageMigrator with IntlMigrator {
  @override
  bool shouldMigrateUsage(FluentComponentUsage usage) => true;

  @override
  void migrateUsage(FluentComponentUsage usage) {
    super.migrateUsage(usage);
    final name = usage.node.thisOrAncestorOfType<ClassDeclaration>()?.name ??
        usage.node.thisOrAncestorOfType<VariableDeclaration>()?.name;
    usage.children
        .forEachIndexed((index, child) {
      if (isValidStringLiteralNode(child.node)) {
        final node = child.node as SimpleStringLiteral;
        yieldPatchOverChildNode(
          intlMessageTemplate(node.stringValue!, name.toString()) + ',',
          child,
        );
      }
    });
  }
}

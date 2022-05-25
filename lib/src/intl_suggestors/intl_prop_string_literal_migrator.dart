import 'package:analyzer/dart/ast/ast.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:file/file.dart';
import 'package:over_react_codemod/src/intl_suggestors/constants.dart';
import 'package:over_react_codemod/src/intl_suggestors/intl_migrator.dart';
import 'package:over_react_codemod/src/intl_suggestors/utils.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:over_react_codemod/src/util/component_usage_migrator.dart';

class IntlPropStringLiteralMigrator extends ComponentUsageMigrator
    with IntlMigrator {
  @override
  bool shouldMigrateUsage(FluentComponentUsage usage) =>
      usage.cascadedProps.any((prop) => isValidStringLiteralProp(prop));

  @override
  void migrateUsage(FluentComponentUsage usage) {
    super.migrateUsage(usage);
    final name = usage.node.thisOrAncestorOfType<ClassDeclaration>()?.name ??
        usage.node.thisOrAncestorOfType<VariableDeclaration>()?.name;

    for (final prop in usage.cascadedProps) {
      if (isValidStringLiteralProp(prop)) {
        final rhs = prop.rightHandSide as SimpleStringLiteral;
        // final name = toVariableName(rhs.stringValue!);
        yieldPropPatch(prop,
            newRhs: intlMessageTemplate(rhs.stringValue!, name.toString()));
      }
    }
  }
}

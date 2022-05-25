import 'package:analyzer/dart/ast/ast.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:file/file.dart';
import 'package:over_react_codemod/src/intl_suggestors/constants.dart';
import 'package:over_react_codemod/src/intl_suggestors/intl_migrator.dart';
import 'package:over_react_codemod/src/intl_suggestors/utils.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:over_react_codemod/src/util/component_usage_migrator.dart';

class IntlPropStringInterpolationMigrator extends ComponentUsageMigrator
    with IntlMigrator {

  @override
  bool shouldMigrateUsage(FluentComponentUsage usage) => usage.cascadedProps
      .any((prop) => isValidStringInterpolationProp(prop));

  @override
  void migrateUsage(FluentComponentUsage usage) {
    super.migrateUsage(usage);
    final eofOffset =
        usage.node.thisOrAncestorOfType<CompilationUnit>()?.end ?? 0;
    usage.cascadedProps.mapIndexed((index, prop) {
      if (isValidStringInterpolationProp(prop)) {
        final functionCall = intlFunctionCall(prop.rightHandSide, index, trailingComma: false);
        final functionDef =
            intlFunctionDef(prop.rightHandSide, index);
        yieldPropPatch(prop, newRhs: functionCall);
        yieldPatch(functionDef, eofOffset);
      }
    }).toList();
  }
}

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:over_react_codemod/src/util/component_usage_migrator.dart';
import 'package:intl/intl.dart';

class IntlMessageMigrator extends ComponentUsageMigrator {
  @override
  String get fixmePrefix => 'FIXME';

  @override
  bool shouldMigrateUsage(FluentComponentUsage usage) {
    bool hasStringProp = usage.cascadedProps.where((element) {
      return ['displayText', 'text', 'label', 'tooltip']
          .contains(element.name.name);
    }).isNotEmpty;
    bool hasStringChild = usage.children
        .whereType<ExpressionComponentChild>()
        .where((child) => (child.node is SimpleStringLiteral))
        .isNotEmpty;
    return hasStringProp || hasStringChild;
  }

  @override
  void migrateUsage(FluentComponentUsage usage) {
    super.migrateUsage(usage);
    usage.cascadedProps.map((element) {
      if (['displayText', 'text', 'label', 'tooltip']
          .contains(element.name.name)) {
        migratePropString(usage, element);
      }
    }).toList();
    migrateChildString(usage);
  }

  void migrateChildString(FluentComponentUsage usage) {
    usage.children
        .map((child) => child.node)
        .whereType<SimpleStringLiteral>()
        .forEach((node) {
          yieldPatchOverNode('Intl.message(${(node)})', node);
    });
  }

  void migratePropString(FluentComponentUsage usage, PropAssignment prop) {
    final rhs = prop.rightHandSide;
    if (rhs is StringLiteral && rhs.stringValue != null) {
      yieldPropPatch(prop, newRhs: 'Intl.message(\'${rhs.stringValue!}\')');
    } else if (rhs is StringInterpolation) {
      var args =
          rhs.elements.where((e) => e is InterpolationExpression).toList();

      var stringArgs = args
          .map((e) => removeInterpolationSyntax(e.toString()).split('.').last)
          .toList();

      var messageWithArgs = rhs.elements
          .map((e) {
            if (e is InterpolationExpression) {
              var stripped = removeInterpolationSyntax(e.toString());
              return '\$${stripped.split('.').last}';
            } else {
              return e.toString();
            }
          })
          .toList()
          .join('');

      String functionDef = '''
      String tempFunctionName(${stringArgs.map((arg) => 'String ${arg}').toList().join(', ')}) =>
          Intl.message(${messageWithArgs},
          args: ${stringArgs},
      );\n
      ''';

      // Check if we are in a class component's render method.
      final offset = usage.node
              .thisOrAncestorMatching((node) =>
                  (node is MethodDeclaration) && node.name.name == 'render')
              ?.offset ??
          // Otherwise attempt to insert it as a local function before the statement containing this usage
          usage.node.thisOrAncestorOfType<Statement>()?.offset ??

          // Otherwise, insert it as a top-level function before the top-level-declaration containing this usage
          usage.node.thisOrAncestorOfType<CompilationUnitMember>()?.offset;

      yieldInsertionPatch(functionDef, offset ?? 0);
      yieldPropPatch(prop,
          newRhs:
              'tempFunctionName(${args.map((a) => removeInterpolationSyntax(a.toString())).toList().join(',')})');
    } else {
      yieldPropFixmePatch(
          prop, 'manually verify this should not be internationalized');
    }
  }

  String removeInterpolationSyntax(String s) => s
      .replaceFirst('\$', '')
      .replaceFirst('\{', '')
      .replaceFirst('\}', '')
      .trim();
}

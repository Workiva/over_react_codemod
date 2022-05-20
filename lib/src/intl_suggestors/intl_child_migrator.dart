import 'package:analyzer/dart/ast/ast.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:file/file.dart';
import 'package:over_react_codemod/src/intl_suggestors/intl_migrator.dart';
import 'package:over_react_codemod/src/intl_suggestors/utils.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:over_react_codemod/src/util/component_usage_migrator.dart';

class IntlChildMigrator extends ComponentUsageMigrator with IntlMigrator {
  final File _outputFile;
  final String _namespace;

  IntlChildMigrator(this._namespace, this._outputFile);

  @override
  bool shouldMigrateUsage(FluentComponentUsage usage) => usage.children
      .whereType<ExpressionComponentChild>()
      .where((child) => (child.node is StringLiteral))
      .isNotEmpty;

  @override
  void migrateUsage(FluentComponentUsage usage) {
    super.migrateUsage(usage);

    migrateChildString(usage);
    //Add child inside props usecase
  }

  void migrateChildString(FluentComponentUsage usage) async {
    final eofOffset = usage.node.thisOrAncestorOfType<CompilationUnit>()?.end ?? 0;
    usage.children
        .map((child) => child.node)
        .whereType<StringLiteral>()
        .forEachIndexed((index, node) {
      if (node is SimpleStringLiteral) {
        if (double.tryParse(node.stringValue!) != null) return;
        if (quotedCamelCase(node.value)) return;
        if (node.value.isEmpty) return;
        if (['/', ' / ', '|', ' | ', '.', ' . ', '', ' ', ' ? ', '?']
            .contains(node.value)) return;
        final name = toVariableName(node.value);
        // final invocation = '${_namespace}.$name';
        yieldPatchOverNode(name, node,);
        yieldPatch(literalTemplate(_namespace, name, node.value), eofOffset);
        // addMethodToClass(_outputFile, literalTemplate(_namespace, name, node.value));
      } else if (node is StringInterpolation) {
        //We do not need to localize single values.  This should be handled by the
        // variable being passed in.
        if (node.elements.first.toString() == node.elements.last.toString())
          return;

        //Lets go up the AST looking for a test id before defaulting to generic component name
        var testId;
        AstNode? n = usage.node;
        while (testId == null && n?.parent != null) {
          if (n is InvocationExpression) {
            var component = getComponentUsage(n);
            if (component != null) {
              for (final method in component.cascadedMethodInvocations) {
                if (method.methodName.name == 'addTestId') {
                  final expression =
                      method.node.argumentList.arguments.firstOrNull;
                  if (expression != null) {
                    testId = toVariableName(expression
                        .toString()
                        .replaceAll("'", '')
                        .split('.')
                        .last
                        .replaceAll('TestId', ''));
                  }
                }
              }
            }
          }
          n = n?.parent;
        }

        final functionName = testId ??
            toCamelCase(
                '${usage.componentName?.split('.').join(' ')} Child $index');

        var args = node.elements.whereType<InterpolationExpression>();

        var stringArgs = args
            .map((e) => removeInterpolationSyntax(e.toString()))
            .toSet()
            .toList();

        var messageWithArgs = node.elements
            .map((e) {
              if (e is InterpolationExpression) {
                var stripped = removeInterpolationSyntax(e.toString());
                return '\$${stripped}';
              } else {
                return e.toString();
              }
            })
            .toList()
            .join('');

        String functionDef = interpolationTemplate(
            _namespace, functionName, messageWithArgs, stringArgs);

        yieldPatchOverNode(
            '$functionName(${args.map((a) => "'$a'").toSet().join(', ')})',
            node);
        yieldPatch(functionDef, eofOffset);
        // addMethodToClass(_outputFile, functionDef);
      }
    });
  }
}

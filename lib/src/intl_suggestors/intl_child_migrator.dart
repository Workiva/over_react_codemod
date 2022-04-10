import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:over_react_codemod/src/intl_suggestors/intl_migrator.dart';
import 'package:over_react_codemod/src/intl_suggestors/utils.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:over_react_codemod/src/util/component_usage_migrator.dart';

class IntlChildMigrator extends ComponentUsageMigrator with IntlMigrator {
  final File _outputFile;
  final String _className;

  IntlChildMigrator(this._className, this._outputFile);

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
    usage.children
        .map((child) => child.node)
        .whereType<StringLiteral>()
        .forEachIndexed((index, node) {
      if (node is SimpleStringLiteral) {
        if (double.tryParse(node.stringValue!) != null) return;
        if (quotedCamelCase(node.value)) return;
        final name = convertNameCase(node.value);
        yieldPatchOverNode(
          '${_className}.${name}',
          node,
        );
        if (!_outputFile
            .readAsStringSync()
            .contains(literalTemplate(name, '\"${node.value}\"'))) {
          _outputFile.writeAsStringSync(literalTemplate(name, '\"${node.value}\"'),
              mode: FileMode.append);
        }
      } else if (node is StringInterpolation) {
        //We do not need to localize single values.  This should be handled by the
        // variable being passed in.
        if (node.elements.first.toString() == node.elements.last.toString())
          return;

        var testId;
        for (final method in usage.cascadedMethodInvocations) {
          if (method.methodName.name == 'addTestId') {
            final expression = method.node.argumentList.arguments.firstOrNull;
            if (expression != null) {
              testId = expression
                  .toString()
                  .split('.')
                  .last
                  .replaceAll('TestId', '');
            }
          }
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
            _className, functionName, messageWithArgs, stringArgs);

        yieldPatchOverNode(
            '$_className.$functionName(${args.map((a) => '\'$a\'').toSet().join(', ')})',
            node);
        if (!_outputFile.readAsStringSync().contains(functionDef)) {
          _outputFile.writeAsStringSync(functionDef, mode: FileMode.append);
        }
      }
    });
  }
}

import 'package:analyzer/dart/ast/ast.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:file/file.dart';
import 'package:over_react_codemod/src/intl_suggestors/constants.dart';
import 'package:over_react_codemod/src/intl_suggestors/intl_migrator.dart';
import 'package:over_react_codemod/src/intl_suggestors/utils.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:over_react_codemod/src/util/component_usage_migrator.dart';

class IntlPropMigrator extends ComponentUsageMigrator with IntlMigrator {
  final File _outputFile;
  final String _className;

  IntlPropMigrator(this._className, this._outputFile);

  @override
  bool shouldMigrateUsage(FluentComponentUsage usage) {
    bool hasStringProp = usage.cascadedProps
        .where((element) => propsToCheck.contains(element.name.name))
        .isNotEmpty;

    return hasStringProp;
  }

  @override
  void migrateUsage(FluentComponentUsage usage) {
    super.migrateUsage(usage);

    usage.cascadedProps.map((element) {
      if (propsToCheck.contains(element.name.name)) {
        final shouldExclude = excludeExpressionsNotLikelyToNeedI18nTranslations(
            element, element.name.name);
        if (!shouldExclude) {
          migratePropString(usage, element);
        }
      }
    }).toList();
  }

  void migratePropString(
      FluentComponentUsage usage, PropAssignment prop) async {
    final rhs = prop.rightHandSide;

    if (rhs is StringLiteral && rhs.stringValue != null) {
      if (double.tryParse(rhs.stringValue!) != null) return;
      final name = toVariableName(rhs.stringValue!);
      yieldPropPatch(prop, newRhs: '${_className}.${name}');
      addMethodToClass(_outputFile, literalTemplate(_className, name, rhs.stringValue!));
    } else if (rhs is StringInterpolation) {
      //We do not need to localize single values.  This should be handled by the
      // variable being passed in.
      /// [', ${props.name}, ']
      /// Note that we don't need to check for quotes because even
      /// symmetrical text would give us
      /// ['asdf, ${props.name}, asdf'] so [0] != [2] because of ' placement
      /// this is helpful to also prevent grabbing things like
      /// [', ${name}, ${type}, ']
      if (rhs.elements.first.toString() == rhs.elements.last.toString()) return;

      ///Take a shot at getting a better name by using a test id.
      var testId;
      for (final method in usage.cascadedMethodInvocations) {
        if (method.methodName.name == 'addTestId') {
          final expression = method.node.argumentList.arguments.firstOrNull;
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

      final functionName = testId ??
          toCamelCase(
              '${usage.componentName?.split('.').join(' ')} ${prop.name}');

      var args = rhs.elements.whereType<InterpolationExpression>();

      /// $a => [a]
      /// ${a} => [a]
      /// ${a.b.c} => [c]
      /// ${a.b.c ?? d} => [c]
      /// '$a is $a but not $b' => [a, b]
      var stringArgs = args
          .map((e) => removeInterpolationSyntax(e.toString()))
          .toSet()
          .toList();

      var messageWithArgs = rhs.elements
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

      String propValue = generatePropValue(_className, functionName, args);
      String functionDef = interpolationTemplate(
          _className, functionName, messageWithArgs, stringArgs);

      /// In the prop we want
      /// ..prop = ClassName.functionName(...[InterpolationExpression])
      yieldPropPatch(prop, newRhs: propValue);
      addMethodToClass(_outputFile, functionDef);
    }
  }
}

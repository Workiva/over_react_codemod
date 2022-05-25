import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:file/file.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';

import 'constants.dart';


// -- Node Validation --
bool isValidStringInterpolationNode(AstNode node) {
  if (!(node is StringInterpolation)) return false;
  //We do not need to localize single values.  This should be handled by the
  // variable being passed in.  IE: ..foo = '$bar' becomes [', '$bar', ']
  if (node.elements.length == 3 &&
      node.elements.first.toString() == node.elements.last.toString())
    return false;
  return true;
}

bool isValidStringLiteralNode(AstNode node) {
  if (!(node is SimpleStringLiteral)) return false;
  if (node.value.isEmpty) return false;
  if (double.tryParse(node.stringValue!) != null) return false;
  if (quotedCamelCase(node.value)) return false;
  if (node.value.length == 1) return false;
  return true;
}

bool isValidStringInterpolationProp(PropAssignment prop) {
  if (!propsToCheck.contains(prop.name.name)) return false;
  if (excludeUnlikelyExpressions(prop, prop.name.name)) return false;
  if (!isValidStringInterpolationNode(prop.rightHandSide)) return false;
  return true;
}

bool isValidStringLiteralProp(PropAssignment prop) {
  if (!propsToCheck.contains(prop.name.name)) return false;
  if (excludeUnlikelyExpressions(prop, prop.name.name)) return false;
  if (!isValidStringLiteralNode(prop.rightHandSide)) return false;
  return true;
}
// -- End Node Validation --

// -- Intl helpers --
String intlMessageTemplate(String message,
    String name, {
      List<String> args = const [],
    }) {
  var escapedStr = message.replaceAll("\'", "\\\'");
  return "Intl.message('${escapedStr}', ${args.isNotEmpty
      ? 'args: ${args}, '
      : ''}name: '$name',)";
}

String intlFunctionCall(AstNode node, int index, {bool trailingComma = true}) {
  node as StringInterpolation;
  final name = intlFunctionName(node, index);
  var args = node.elements
      .whereType<InterpolationExpression>()
      .map((e) => removeInterpolationSyntax(e.toString()))
      .toSet()
      .toList();
  return '$name(${args.toSet().join(',')})${trailingComma ? ',' : ''}';
}

String intlFunctionDef(AstNode node,
    int index,) {
  node as StringInterpolation;
  final functionName = intlFunctionName(node, index);

  final args = node.elements.whereType<InterpolationExpression>()
      .map((e) => toVariableName(toNestedName(e.toString())))
      .toSet()
      .toList();

  final messageWithArgs = node.elements
      .map((e) {
    if (e is InterpolationExpression) {
      var stripped = toVariableName(toNestedName(e.toString()));
      return '\$${stripped}';
    } else {
      return e.toString();
    }
  })
      .toList()
      .join('');
  final formattedMessage = messageWithArgs.substring(
      1, messageWithArgs.length - 1);
  final signature = functionSignature(functionName, args);
  final message = intlMessageTemplate(
      formattedMessage, '$functionName', args: args);
  return '\n$signature => $message;';
}

String literalTemplate(String namespace, String variableName, String value) {
  return intlMessageTemplate(value, '${namespace}_$variableName');
  return "Intl.message('${value}', name: '${namespace}_${variableName}',),";
}

String intlInterpolationTemplate(String namespace, String message,
    List<String> args, String name) {
  return "Intl.message(${message}, args: ${args}, name: '$name',)";
}

String functionSignature(String functionName, List<String> args) {
  return 'String $functionName(${args.map((arg) => 'String $arg').toList().join(
      ',')})';
}

String intlFunctionName(AstNode node, int index) {
  return getTestId(null, node) ?? 'tempFunction$index';
}

// -- End Intl helpers --

String generatePropValue(String className,
    String functionName,
    Iterable<InterpolationExpression> args,) =>
    '$className.$functionName(${args.map((a) => '\'$a\'').toSet().join(', ')})';

String toClassName(String str) =>
    '${toPascalCase(str.replaceAll('_', ' ')).replaceAll(' ', '')}Intl';

String convertNameCase(String name) {
  String newName = toAlphaNumeric(name);
  if (name.startsWith(RegExp(r'[a-z]'))) {
    return toCamelCase(newName);
  } else {
    return toPascalCase(newName);
  }
}

String removeInterpolationSyntax(String s) =>
    s.replaceAll(RegExp(r'(\$[^a-zA-Z0-9.]|\s|}|\?.*|\$)'), '');

String toNestedName(String s) =>
    removeInterpolationSyntax(s)
        .split('.')
        .last;

String toVariableName(String str) {
  String name = convertNameCase(toAlphaNumeric(
      str.startsWith(RegExp(r'^[0-9]*'))
          ? str.replaceFirst(RegExp(r'^[0-9]*'), '')
          : str));

  bool isKeyWord = Keyword.keywords.values
      .where((keywordValue) => keywordValue.lexeme == name)
      .isNotEmpty;
  return isKeyWord ? '${name}String' : name;
}

String toAlphaNumeric(String str) =>
    str.replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '');

String toPascalCase(String str) {
  final res = toAlphaNumeric(str);

  // Build Pascal Chess
  return res
      .replaceAllMapped(
      RegExp(r'(?:^\w|[A-Z]|\b\w|\s+)'), (m) => m[0]?.toUpperCase() ?? '')
      .replaceAll(' ', '');
}

String toCamelCase(String str) {
  /// Remove any non-alphanumeric characters, but leave spaces so we can match by word
  var res = toAlphaNumeric(str);

  /// BuildCamelCase
  var capitalizationResult = res.replaceAllMapped(
      RegExp(r'(?:^\w|[A-Z]|\b\w|\s+)'),
          (m) =>
      m.start == 0 ? m[0]?.toLowerCase() ?? '' : m[0]?.toUpperCase() ?? '');

  /// Finally remove the spaces
  return capitalizationResult.replaceAll(' ', '');
}

bool excludeUnlikelyExpressions<E extends Expression>(PropAssignment prop,
    String propKey) {
  if (prop.rightHandSide.staticType == null) return true;
  if (prop.rightHandSide.staticType?.isDartCoreBool ?? false) return true;
  if (prop.rightHandSide.staticType?.isDartCoreNull ?? false) return true;
  if (RegExp('((List|Iterable)\<ReactElement\>|ReactElement)(\sFunction)?')
      .hasMatch(prop.rightHandSide.staticType
      ?.getDisplayString(withNullability: false) ??
      '')) return true;
  if (prop.rightHandSide.staticType?.getDisplayString(withNullability: false) ==
      'Iterable<ReactElement>') return true;
  final source = prop.rightHandSide.toSource();
  if (source == propKey ||
      source == 'props.$propKey' ||
      source == "props['$propKey']") return true;
  if (source == "''") return true;
  if (source == "'.'") return true;
  if (source == "'('") return true;
  if (source == "')'") return true;
  // If a string value is wrapped in quotes, and is in lowerCamelCase or UpperCamelCase, it is most likely a key of some kind, not a human-readable, translatable string.
  if (RegExp(
      r"^'([a-z]+[A-Z0-9][a-z0-9]+[A-Za-z0-9]*)|([A-Z][a-z0-9]*[A-Z0-9][a-z0-9]+[A-Za-z0-9]*)'$")
      .hasMatch(source)) return true;

  return false;
}

// If a string value is wrapped in quotes, and is in lowerCamelCase or UpperCamelCase, it is most likely a key of some kind, not a human-readable, translatable string.
bool quotedCamelCase(String str) =>
    RegExp(
        r"^'([a-z]+[A-Z0-9][a-z0-9]+[A-Za-z0-9]*)|([A-Z][a-z0-9]*[A-Z0-9][a-z0-9]+[A-Za-z0-9]*)'$")
        .hasMatch(str);

extension ReactTypes$DartType on DartType {
  bool get isComponentClass => element?.isComponentClass ?? false;

  bool get isReactElement => element?.isReactElement ?? false;

  bool get isPropsClass => element?.isPropsClass ?? false;
}

extension DartHtmlTypes$DartType on DartType {
  bool get isDartHtmlEvent => element?.isDartHtmlEvent ?? false;
}

extension ReactTypes$Element on Element /*?*/ {
  bool get isComponentClass =>
      isOrIsSubtypeOfTypeFromPackage('Component', 'react');

  bool get isReactElement =>
      isOrIsSubtypeOfTypeFromPackage('ReactElement', 'react');

  bool get isPropsClass =>
      isOrIsSubtypeOfTypeFromPackage('UiProps', 'over_react');
}

extension DartHtmlTypes$Element on Element /*?*/ {
  bool get isDartHtmlEvent =>
      isOrIsSubtypeOfTypeFromPackage('Event', 'html', PackageType.dartCore);
}

extension ElementSubtypeUtils on Element /*?*/ {
  bool isOrIsSubtypeOfTypeFromPackage(String typeName, String packageName,
      [PackageType packageType = PackageType.package]) {
    final that = this;
    return that is ClassElement &&
        (that.isTypeFromPackage(typeName, packageName, packageType) ||
            that.allSupertypes.any((type) =>
                type.element
                    .isTypeFromPackage(typeName, packageName, packageType)));
  }

  bool isTypeFromPackage(String typeName, String packageName,
      [PackageType packageType = PackageType.package]) =>
      name == typeName && isDeclaredInPackage(packageName, packageType);
}

extension on Element {
  bool isDeclaredInPackage(String packageName,
      [PackageType packageType = PackageType.package]) =>
      isUriWithinPackage(source?.uri ?? Uri(), packageName, packageType);
}

bool isUriWithinPackage(Uri uri, String packageName,
    [PackageType packageType = PackageType.package]) {
  switch (packageType) {
    case PackageType.dartCore:
      return uri.isScheme('dart') &&
          uri.pathSegments.isNotEmpty &&
          uri.pathSegments[0] == packageName;
    case PackageType.package:
      return uri.isScheme('package') &&
          uri.pathSegments.isNotEmpty &&
          uri.pathSegments[0] == packageName;
  }
}

enum PackageType {
  dartCore,
  package,
}

String? getTestId(String? testId, AstNode node) {
  if (testId != null) return testId;
  if (node is InvocationExpression) {
    var component = getComponentUsage(node);
    if (component != null) {
      for (final method in component.cascadedMethodInvocations) {
        if (method.methodName.name == 'addTestId') {
          final expression = method.node.argumentList.arguments.first;
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

  if (node.parent != null) {
    return getTestId(testId, node.parent!);
  } else {
    return null;
  }
}

/// Return the constant value of the static constant represented by the given
/// [element].
Object? getConstantValue(Element? element) {
  if (element == null) return Object();
  final constantValue = _tryComputeConstantValue(element);
  if (constantValue == null) return Object();
  return _tryConvertDartObject(constantValue);
}

DartObject? _tryComputeConstantValue(Element element) {
  if (element is VariableElement) {
    return element.computeConstantValue();
  }
  if (element is PropertyAccessorElement) {
    return element.variable.computeConstantValue();
  }

  return null;
}

Object? _tryConvertDartObject(DartObject? object) {
  if (object!.isNull) return null;

  {
    final primitiveValue = object.toBoolValue() ??
        object.toDoubleValue() ??
        object.toIntValue() ??
        object.toStringValue();
    if (primitiveValue != null) return primitiveValue;
  }
// FIXME these shallow checks should be sufficient, and rule out any nested cases, right?
      {
    final listValue = object.toListValue();
    if (listValue != null) {
      final list = listValue.map(_tryConvertDartObject).toList();
      return list.contains(Object()) ? Object() : list;
    }
  }
  {
    final setValue = object.toSetValue();
    if (setValue != null) {
      final set = setValue.map(_tryConvertDartObject).toSet();
      return set.contains(Object()) ? Object() : set;
    }
  }
  {
    final mapValue = object.toMapValue();
    if (mapValue != null) {
      final map = mapValue.map(
              (key, value) => MapEntry(
              _tryConvertDartObject(key), _tryConvertDartObject(value)));
      return (map.containsKey(Object()) ||
          map.containsValue(Object()))
          ? Object()
          : map;
    }
  }

  return Object();
}

extension on DartObject {
  DartObject? getFieldOnThisOrSuper(String fieldName) {
    return getField(fieldName) ??
        getField('(super)')?.getFieldOnThisOrSuper(fieldName);
  }
}
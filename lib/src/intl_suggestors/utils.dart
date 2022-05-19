import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:file/file.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';

void addMethodToClass(File outputFile, String content) {
  if (!outputFile.readAsStringSync().contains(content)) {
    outputFile.writeAsStringSync(content, mode: FileMode.append);
  }
}

String literalTemplate(String className, String variableName, String value) {
  return "\nstatic String get ${variableName} => Intl.message('${value}', name: '${className}_${variableName}',);\n";
}

String interpolationTemplate(
    String className, String functionName, String message, List<String> args) {
  return "static String ${functionName}(${args.map((arg) => 'String ${arg}').toList().join(', ')}) => Intl.message(${message}, args: ${args}, name: '${className}_${functionName}',);\n";
}

String generatePropValue(
  String className,
  String functionName,
  Iterable<InterpolationExpression> args,
) =>
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

String removeInterpolationSyntax(String s) => s
    .replaceAll(RegExp(r'(\$[^a-zA-Z0-9.]|\s|}|\?.*|\$|\(\))'), '')
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

bool excludeExpressionsNotLikelyToNeedI18nTranslations<E extends Expression>(
    PropAssignment prop, String propKey) {
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
bool quotedCamelCase(String str) => RegExp(
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
            that.allSupertypes.any((type) => type.element
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

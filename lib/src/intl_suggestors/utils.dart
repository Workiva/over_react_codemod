import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:over_react_codemod/src/intl_suggestors/intl_messages.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:over_react_codemod/src/util/element_type_helpers.dart';

import 'constants.dart';

// -- Node Validation --
// Checks the text under [node] has any alphabetic value, ignore if it's not.
RegExp alphabetMatcher = RegExp('[a-zA-Z]');

/// For a string interpolation, get all the non-interpolated parts in a string,
/// separated by spaces.
String textFromInterpolation(StringInterpolation body) => body.elements
    .whereType<InterpolationString>()
    .map((each) => each.value)
    .join(' ')
    .trim();

bool isValidStringInterpolationNode(AstNode node) {
  if (node is! StringInterpolation) return false;
  //We do not need to localize single values.  This should be handled by the
  // variable being passed in.  IE: ..foo = '$bar' becomes [', '$bar', ']
  if (node.elements.length == 3 &&
      node.elements.first.toString() == node.elements.last.toString())
    return false;
  var result = textFromInterpolation(node);
  return result.isNotEmpty && result.contains(alphabetMatcher);
}

bool hasNoAlphabeticCharacters(String s) => !_alphabeticPattern.hasMatch(s);

final RegExp _alphabeticPattern = RegExp('[a-zA-Z]');

/// The text under [node] if it's some kind of string literal, null if it's not.
String? stringContent(AstNode node) {
  if (node is SimpleStringLiteral) return node.value;
  if (node is AdjacentStrings) {
    if (!node.strings.toList().every((x) => x is SimpleStringLiteral))
      return null;
    return [for (var s in node.strings) (s as SimpleStringLiteral).value]
        .join('');
  }
  return null;
}

/// Is this a multiline string literal?
bool isMultiline(AstNode node) {
  // TODO: Can we have multiline adjacent strings? And if we can, would someone actually do that?
  if (node is SimpleStringLiteral) return node.isMultiline;
  return false;
}

bool isValidStringLiteralNode(AstNode node) {
  String? text = stringContent(node);
  if (text == null) return false;
  if (text.isEmpty) return false;
  if (double.tryParse(text) != null) return false;
  if (quotedCamelCase(text)) return false;
  if (text.trim().length == 1) return false;
  // If there are no alphabetic characters, we can't do anything useful.
  if (hasNoAlphabeticCharacters(text)) return false;
  // Uri.parse is too accepting. Also check common schemes that might make sense.
  var mightBeAUrl = Uri.tryParse(text);
  if (mightBeAUrl != null &&
      ['http', 'https', 'wurl', 'mailTo'].contains(mightBeAUrl.scheme)) {
    return false;
  }
  return true;
}

bool isValidStringInterpolationProp(PropAssignment prop) {
  if (!propsToCheck.contains(prop.name.name)) return false;
  if (excludeKnownBadCases(prop, prop.name.name)) return false;
  if (excludeUnlikelyExpressions(prop, prop.name.name)) return false;
  if (!isValidStringInterpolationNode(prop.rightHandSide)) return false;
  return true;
}

bool isValidStringLiteralProp(PropAssignment prop) {
  if (!propsToCheck.contains(prop.name.name)) return false;
  if (excludeKnownBadCases(prop, prop.name.name)) return false;
  if (excludeUnlikelyExpressions(prop, prop.name.name)) return false;
  if (!isValidStringLiteralNode(prop.rightHandSide)) return false;
  return true;
}
// -- End Node Validation --

String escapeApos(String s) {
  var apos = "'";
  var backslash = r'\';
  return s.replaceAll(apos, backslash + apos);
}

String removeInterpolationSyntax(String s) =>
    s.replaceAll(RegExp(r'(\$[^a-zA-Z0-9.]|\s|}|\?.*|\$)'), '');

/// This is a helper function to create a name out of
/// an interpolation element that is a nested accessor
///   -ex:
///     final string = 'The string is ${props.theString.length} characters long';
///     toNestedName(string) = 'length'
/// Looking at this example in combination with the intl migration
///   -ex
///     Input:
///       Dom.div()('The string is ${props.theString.length} characters long';)
///     Output:
///       Dom.div()(FooIntl.theStringIs('${props.theString.length'}))
///       class FooIntl {
///         String theStringIs(String length) => Intl.message(
///                                                 'The string is $length characters long',
///                                                 args: [length],
///                                                 name: 'FooIntl_theStringIs',
///                                               );
///       }
///
String toNestedName(String s) => removeInterpolationSyntax(s).split('.').last;

void addMethodToClass(IntlMessages outputFile, String content) {
  outputFile.addMethod(content);
}

/// Input: foo_bar_package
/// Output: FooBarPackageIntl
String toClassName(String str) {
  final res = toAlphaNumeric(str.replaceAll('_', ' '));
  final pascalString = res
      .splitMapJoin(RegExp(r'(?:^\w|[A-Z]|\b\w|\s+)'),
          onMatch: (m) => m[0]!.toUpperCase())
      .replaceAll(' ', '');
  return '${pascalString}Intl';
}

/// Converts a string to a variable name
/// First we remove any leading numbers.
///   - This solves "10 documents deleted" -> deletedDocuments
/// Next only take the first 5 tokens in the string
/// to keep the names shortish
///   - "This string was a very long paragraph that
///   needs translation but if we just join on spaces
///   and convert to camel case it makes a variable
///   name no one wants to type" -> thisStringWasAVery
/// Next we remove any non alphanumeric characters
///   - "This (optional) case" -> thisOptionalCase
/// Next we convert it to camel case
///   - "IM NOT YELLING" -> imNotYelling
/// finally we check if it is a keyword and if so append "String" to it.
///   - "New" -> newString
String toVariableName(String str) {
  // The name might have surrounding quotes, remove them.
  if (str.startsWith("'") && str.endsWith("'")) {
    str = str.substring(1, str.length - 1);
  }
  String strippedName =
      str.replaceFirst(RegExp(r'^[0-9]*'), '').replaceAll("'", '').trim();
  var fiveAtMost =
      strippedName.split(' ').where((each) => each.isNotEmpty).toList();
  fiveAtMost =
      fiveAtMost.sublist(0, fiveAtMost.length < 5 ? fiveAtMost.length : 5);
  final alphaNumericName = toAlphaNumeric(fiveAtMost.join(' '));
  final name = toCamelCase(alphaNumericName);

  bool isKeyWord = Keyword.keywords.values
      .where((keywordValue) => keywordValue.lexeme == name)
      .isNotEmpty;
  return isKeyWord ? '${name}String' : name;
}

String toAlphaNumeric(String str) =>
    str.replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '');

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

/// Exclude cases we know shouldn't be localized, even though that attribute
/// should be localized for some classes.
bool excludeKnownBadCases(PropAssignment prop, String propKey) {
  // TODO: If we get more of these we will want to have this check a list or similar.
  var targetType = prop.target.staticType;
  if (targetType == null) return false; // We don't know.
  if (targetType.isOrIsSubtypeOfClassFromPackage(
          'AbstractSelectOptionPropsMixin', 'web_skin_dart') &&
      propKey == 'value') {
    return true;
  }
  return false;
}

bool excludeUnlikelyExpressions<E extends Expression>(
    PropAssignment prop, String propKey) {
  final staticType = prop.rightHandSide.staticType;
  if (staticType == null) return true;
  if (staticType.isDartCoreBool) return true;
  if (staticType.isDartCoreNull) return true;
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
  if (quotedCamelCase(source)) return true;

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
      name == typeName && isDeclaredInPackageOfType(packageName, packageType);
}

extension ElementChecks on Element {
  bool isDeclaredInPackageOfType(String packageName,
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

import 'package:analyzer/dart/ast/ast.dart';
import 'package:over_react_codemod/src/intl_suggestors/intl_messages.dart';
import 'package:over_react_codemod/src/intl_suggestors/utils.dart';

/// Generates calls and definitions for Intl getters and functions in the Intl class.
///
/// It's connected to a particular IntlMessages instance, because it needs to be able to check
/// for existing names and their contents.
class MessageSyntax {
  IntlMessages owner;

  MessageSyntax(this.owner);

  static const intlFunctionPrefix = 'static String';

  /// A template to build property access for intl string
  /// ex: ExampleIntl.exampleString
  String getterCall(StringLiteral node, String namespace, {String? name}) =>
      '${namespace}.${nameForNode(node, initialName: name)}';

  /// Returns Intl.message for string literal.
  ///
  /// The optional [name] parameter lets us provide a name rather than generating
  /// one from the string.
  ///
  /// ex: static String get fooBar => Intl.message('Foo Bar','name: FooBarIntl_fooBar',);
  String getterDefinition(StringLiteral node, String namespace,
      {String? name}) {
    String text = stringContent(node)!;
    final varName = nameForNode(node, initialName: name);
    final message = intlFunctionBody(text, '${namespace}_$varName',
        isMultiline: isMultiline(node));
    return '  $intlFunctionPrefix get $varName => $message;';
  }

  /// A template to build function call intl interpolated string
  /// ex: ExampleIntl.exampleString(sting1, string2)
  String functionCall(
    StringInterpolation node,
    String namespace,
    String namePrefix,
  ) {
    final functionName = nameForNode(node);
    final functionArgs = intlFunctionArguments(node);
    return '$namespace.$functionName$functionArgs';
  }

  /// Returns Intl.message with interpolation
  /// ex: static String Foo_bar(String baz) => Intl.message(
  ///                                           'Foo bar $baz',
  ///                                           args: [baz],
  ///                                           'name: FooBarIntl_Foo_bar',
  ///                                           );
  String functionDefinition(
      StringInterpolation node, String namespace, String namePrefix) {
    final functionName = nameForNode(node);
    final functionParams = intlFunctionParameters(node);
    final parameterizedMessage = intlParameterizedMessage(node);
    final messageArgs = intlMessageArgs(node);
    final message = intlFunctionBody(
        parameterizedMessage, '${namespace}_$functionName',
        args: messageArgs, isMultiline: node.isMultiline);
    return '  ${intlFunctionPrefix} $functionName$functionParams => $message;';
  }

  String intlFunctionParameters(StringInterpolation node) {
    final args = node.elements
        .whereType<InterpolationExpression>()
        .map((e) => toVariableName(toNestedName(e.toString())))
        .toSet()
        .toList();
    return '(${args.map((arg) => 'String $arg').toList().join(', ')})';
  }

  /// A template to build Intl.message('[message]', args: [args], name: [name]);
  String intlFunctionBody(
    String message,
    String name, {
    List<String> args = const [],
    bool isMultiline = false,
  }) {
    var escapedStr = escapeNewlines(escapeApos(message), isMultiline);
    String delimiter = (isMultiline) ? "'''" : "'";
    return "Intl.message(${delimiter}${escapedStr}${delimiter}, ${args.isNotEmpty ? 'args: ${args}, ' : ''}name: '$name')";
  }

  /// Converts 'Interpolated ${foo.bar} and $baz' into
  /// 'Interpolated $bar and $baz'
  String intlParameterizedMessage(StringInterpolation node) => node.elements
      .map((e) => e is InterpolationExpression
          ? intlInterpolation(e)
          : escapeNewlines((e as InterpolationString).value, node.isMultiline))
      .toList()
      .join('');

  String escapeNewlines(String input, bool isMultiline) {
    return isMultiline ? input : input.replaceAll('\n', r'\n');
  }

  String intlInterpolation(InterpolationExpression e) {
    var name = toVariableName(toNestedName('$e'));
    return r'${' + name + '}';
  }

  /// Creates the arg array for Intl.message
  /// ex: For the parameterized string 'Interpolated $bar and $baz'
  ///     it will return [bar, baz]
  List<String> intlMessageArgs(StringInterpolation node) => node.elements
      .whereType<InterpolationExpression>()
      .map((e) => toVariableName(toNestedName(e.expression.toString())))
      .toSet()
      .toList();

  /// Creates the parameters for the intl function call
  /// ex: For the parameterized string 'Interpolated ${foo.bar} and $baz'
  ///     it will return (foo.bar, baz)
  String intlFunctionArguments(StringInterpolation node) {
    var args = node.elements
        .whereType<InterpolationExpression>()
        .map((e) => e.expression.toString())
        .toSet()
        .toList();
    return '(${args.join(', ')})';
  }

  String nameForNode(StringLiteral body,
      {String? initialName, bool startAtZero = false}) {
    var messageText = literalText(body);
    // The case where there is no text after this should be checked in
    // isValidStringInterpolationNode and so it should never happen here.
    return owner.nameForString(
        initialName ?? toVariableName(messageText), messageText,
        startAtZero: startAtZero);
  }
}

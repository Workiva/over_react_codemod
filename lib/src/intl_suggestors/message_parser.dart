import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:collection/collection.dart';
import 'package:over_react_codemod/src/intl_suggestors/utils.dart';

/// Holds the important parts of a method that we've parsed.
class Method {
  String name;
  String messageText;
  String source;

  Method(this.name, this.messageText, this.source);
}

/// Parse the messages from the _intl.dart file, and has methods for getting
/// information from them.
///
/// Note that this assumes things about the format, and will fail if the file is
/// changed outside those assumptions.
class MessageParser {
  String source;

  String path;

  List<Method> methods = [];

  MessageParser.forFile(this.source, this.path) {
    _parse();
  }

  // If we're parsing a method in isolation, it can't be parsed (at least not if it's static),
  // so wrap it in a trivial class and parse that.
  MessageParser.forMethod(String methodSource, {String className = 'Foo'})
      : this.source = 'class $className { $methodSource }',
        path = 'generated class for method' {
    _parse();
  }

  void _parse() {
    ParseStringResult parsed;
    try {
      parsed = parseString(content: source, path: path);
    } on ArgumentError {
      print('Error in generated code!!');
      print('--------------------------------------------------------');
      print(source);
      print('--------------------------------------------------------');
      rethrow;
    }
    var intlClass = parsed.unit.declarations.first as ClassDeclaration;
    var allDeclarations = intlClass.members.toList();
    for (var decl in allDeclarations) {
      if (decl is! MethodDeclaration) {
        throw FormatException(
            'Invalid member, not a method declaration: "$decl"');
      }
    }
    var methodDeclarations = allDeclarations.cast<MethodDeclaration>();
    methods = [
      for (var declaration in methodDeclarations)
        Method(declaration.name.name, messageText(declaration),
            '  ${corrected(declaration)}')
    ];
  }

  /// Correct messages as we're rewriting them.
  ///
  /// The main fix is that formatted messages don't like arguments of type
  /// Function, because it makes Dart tear off the function from objects that
  /// implement [call], which loses information so we can't figure out what to
  /// do properly. So replace all such occurrences of 'Function' with 'Object'.
  ///
  /// We also fix the name parameters to all methods to match the class/method
  /// name.
  String corrected(MethodDeclaration declaration) {
    var currentSource = withCorrectedNameParameter(declaration);
    if (intlMethodInvocation(declaration).methodName.name !=
        'formattedMessage') {
      return currentSource;
    } else {
      return withCorrectFunctionTypes(declaration, currentSource);
    }
  }

  /// The method source with Function rewritten to Object in formattedMessages.
  /// This also takes the state of the current source if it's already been
  /// partially rewritten.
  String withCorrectFunctionTypes(
      MethodDeclaration declaration, String currentSource) {
    // Split out the body and just do a simple string replace on the header. The
    // conditions for a false positive on this seem unlikely, so just do it and
    // cross our fingers. If it's in a function name it will be followed by a
    // parenthesis. This is only used for formattedMessage, so it won't be a
    // getter. And if you name a parameter that ends in Function it'll
    // presumably be followed by either a comma or a close-paren.
    var splitString = (declaration.body is BlockFunctionBody) ? '{' : '=>';
    var declarationParts = currentSource.split(splitString);
    var newBeginning =
        declarationParts.first.replaceAll('Function ', 'Object ');
    return '$newBeginning$splitString${declarationParts.last}';
  }

  /// Find the parameter `name:` from the invocation, or return null if there
  /// isn't one.
  NamedExpression? nameParameterFrom(MethodInvocation invocation) =>
      invocation.argumentList.childEntities.firstWhereOrNull((element) =>
              element is NamedExpression && element.name.label.name == 'name')
          as NamedExpression?;

  /// Return the method body with the correct name.
  String withCorrectedNameParameter(MethodDeclaration declaration) {
    var invocation = intlMethodInvocation(declaration);
    var nameParameter = nameParameterFrom(invocation);
    var className = (declaration.parent as ClassDeclaration).name.name;
    var expected = "'${className}_${declaration.name.name}'";
    var actual = nameParameter?.expression.toSource();
    var basicString = '$declaration';
    if (actual == null) {
      return basicString.replaceRange(
          basicString.length - 2, basicString.length, ', name: $expected);');
    } else
      return expected == actual
          ? basicString
          : basicString.replaceFirst("name: $actual", "name: $expected");
  }

  /// The invocation of the internal Intl method. That is, the part after the
  /// '=>' or the first statement inside the {}.  We expect only one. Used for
  /// determining what sort of method this is
  /// message/plural/select/formattedMessage.
  MethodInvocation intlMethodInvocation(MethodDeclaration method) {
    var node = method.body;
    if (node is ExpressionFunctionBody) {
      return node.expression as MethodInvocation;
    } else if (node is BlockFunctionBody) {
      var children = node.block.statements.first.childEntities.toList();
      var methods = children.whereType<MethodInvocation>().toList();
      if (methods.length > 1)
        throw ArgumentError(
            'A message can only contain a single call, which must be to an Intl function');
      return methods.first;
    } else {
      throw ArgumentError(
          'Cannot parse $node. It needs to be a function with a single expression which is an Intl method invocation');
    }
  }

  /// The message text for an Intl method, that is to say the first argument
  /// of the method. We expect [method] to be a declaration of the form
  ///
  ///   `static String foo() => Intl.message(messageText, <...other arguments>`
  ///
  /// or a getter of the same form.
  String messageText(MethodDeclaration method) {
    // TODO: Doesn't work for Intl.plural/select where there is no
    // single text argument. We return an empty string so they will always
    // match as being the same and it will use the existing one.
    // TODO: Rather than throw, could this e.g. return a different suggested name?
    var invocation = intlMethodInvocation(method);
    if (invocation.methodName.name != 'message') {
      // This isn't an Intl.message call, we don't know what to do, bail.
      return '';
    }

    return literalText(invocation.argumentList.arguments.first);
  }
}

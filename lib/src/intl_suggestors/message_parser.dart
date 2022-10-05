import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

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
  MessageParser.forMethod(String methodSource)
      : this.source = 'class Foo { $methodSource }',
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
    var methodDeclarations =
        intlClass.members.toList().cast<MethodDeclaration>();
    methods = [
      for (var declaration in methodDeclarations)
        Method(
            declaration.name.name, messageText(declaration), '  $declaration')
    ];
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
    MethodInvocation invocation =
        method.body.childEntities.toList()[1] as MethodInvocation;
    if (invocation.methodName.name != 'message') {
      // This isn't an Intl.message call, we don't know what to do, bail.
      return '';
    }
    var text = invocation.argumentList.arguments.first.toSource();
    return text;
  }
}

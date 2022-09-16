import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:over_react_codemod/src/intl_suggestors/intl_message_syntax.dart';
import 'package:over_react_codemod/src/intl_suggestors/utils.dart';
import 'package:path/path.dart' as p;

/// The generated messages for the Intl class, with the ability to read and
/// write the source file for that class.
class IntlMessages {
  /// The name of the package we're generating in, used in the output file name.
  final String packageName;

  /// The file we will read/write.
  File outputFile;

  /// The methods for this class, indexed by method name.
  Map<String, Method> methods = {};

  late MessageSyntax syntax;

  /// Flag to check if we've actually added anything, and need to rewrite the file.
  bool addedNewMethods = false;

  // TODO: I think packagePath only applies if there's a sub-package.
  IntlMessages(this.packageName,
      {Directory? directory, String packagePath = '', File? output})
      : outputFile = output ??
            (directory ?? LocalFileSystem().currentDirectory).childFile(p.join(
                packagePath,
                'lib',
                'src',
                'intl',
                '${packageName}_intl.dart')) {
    syntax = MessageSyntax(this);
    _readExisting();
  }

  /// Read the existing file and incorporate its methods.
  void _readExisting() {
    String existing =
        outputFile.existsSync() ? outputFile.readAsStringSync() : '';
    var parsed = parseMethods(existing);
    if (parsed != null) {
      for (var method in parsed) {
        methods[method.name] = method;
      }
    }
  }

  /// Read all the methods from an existing file.
  List<Method>? parseMethods(String content) => content.isEmpty
      ? null
      : MessageParser.forFile(content, outputFile.path).methods;

  String get className => toClassName(packageName);

  String messageContents() => _messageContents;

  /// Add a method with the given [source].
  void addMethod(String source) {
    // If we call this rather than addMethodNamed, then we're adding a new
    // method, record that.
    addedNewMethods |= true;
    var parsed = MessageParser.forMethod(source).methods.first;
    var expectedName = nameForString(parsed.name, parsed.messageText);
    if (expectedName != parsed.name) {
      throw AssertionError('''
Attempting to add a different message with the same name:
  new: $source
  old: ${methods[parsed.name]?.source}''');
    }
    // If it's already there, leave the existing one, which may have manual modifications.
    methods.putIfAbsent(parsed.name, () => parsed);
  }

  /// Find the existing name for [name]+number that has the same [messageText], or
  /// if there isn't one, return the first available.
  String nameForString(String name, String messageText,
      {bool startAtZero = false}) {
    var index = 1;
    var newName = '$name${startAtZero ? 0 : ''}';
    while (isNameTaken(newName, messageText)) {
      newName = '$name$index';
    }
    return newName;
  }

  /// Is there already something with this name, but a different messageText?
  bool isNameTaken(String name, String messageText) {
    var method = methods[name];
    return method != null && methods[name]!.messageText != messageText;
  }

  /// Delete our generated file. Used for tests.
  void delete() => outputFile.deleteSync();

  /// The contents of the generated file.
  String get contents =>
      (StringBuffer()..write(prologue)..write(_messageContents)..write('\n}'))
          .toString();

  // Just the messages, without the prologue or closing brace.
  String get _messageContents {
    var buffer = StringBuffer();
    (methods.keys.toList()..sort())
        .forEach((name) => buffer.write('\n${methods[name]?.source}'));
    return '$buffer';
  }

  /// Write the messages to a file. If the file exists and there are no changes, it will just
  /// stop unless [force] is true.
  void write({bool force = false}) {
    // Create the file if it didn't exist, but if there are no changes, don't rewrite the existing.
    var exists = outputFile.existsSync();
    if (force || !exists || outputFile.readAsStringSync().isEmpty) {
      outputFile.createSync(recursive: true);
      outputFile.writeAsStringSync(contents);
    } else if (addedNewMethods) {
      outputFile.writeAsStringSync(contents);
    }
  }

  /// The beginning of any Intl class.
  static String prologueFor(String className) =>
      '''import 'package:intl/intl.dart';

//ignore: avoid_classes_with_only_static_members
//ignore_for_file: unnecessary_brace_in_string_interps

class $className {''';

  /// The beginning of our Intl class.
  String get prologue => prologueFor(className);
}

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
    ParseStringResult parsed = parseString(content: source, path: path);
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

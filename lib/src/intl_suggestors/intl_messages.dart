import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:file/file.dart';
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
  Map<String, String> methods = {};

  /// Flag to check if we've actually added anything, and need to rewrite the file.
  bool addedNewMethods = false;

  MessageParser parser = MessageParser();

  IntlMessages(this.packageName, Directory currentDir, String packagePath,
      {File? output})
      : outputFile = output ??
            currentDir.childFile(p.join(
                packagePath, 'lib', 'src', 'intl', '${packageName}_intl.dart'))
  // TODO: I think packagePath only applies if there's a sub-package.
  {
    _readExisting();
  }

  /// Read the existing file and incorporate its methods.
  void _readExisting() {
    String existing =
        outputFile.existsSync() ? outputFile.readAsStringSync() : '';
    parseMethods(existing).forEach((name, text) => addMethodNamed(name, text));
  }

  /// Read all the methods from an existing file.
  Map<String, String> parseMethods(String content) {
    if (content.isEmpty) {
      return {};
    }
    return parser.parseFile(content, outputFile.path);
  }

  String get className => toClassName(packageName);

  // TODO: Get rid of the pseudo-file operations if possible.
  String messageContents() => _messageContents;

  void addMethod(String method) {
    // If we call this then we're adding a new method, so note that we have changes.
    addedNewMethods |= true;
    addMethodNamed(parser.methodName(method), method);
  }

  void addMethodNamed(String name, String source) {
    if (methods.containsKey(name)) {
      var existingMethod = methods[name]!;
      if (existingMethod != source) {
        if (parser.messageText(existingMethod) != parser.messageText(source)) {
          throw AssertionError('''
Attempting to add a different message with the same name:
  new: $source
  old: ${methods[name]}''');
        } else {
          // Seems to match, keep the existing one, which may have modifications (e.g. add description).
          return;
        }
      }
    }
    methods[name] = source;
  }

  void delete() => outputFile.deleteSync();

  String get contents =>
      (StringBuffer()..write(prologue)..write(_messageContents)..write('\n}'))
          .toString();

  // Just the messages, without the prologue or closing brace.
  String get _messageContents {
    var buffer = StringBuffer();
    (methods.keys.toList()..sort())
        .forEach((name) => buffer.write('\n${methods[name]}'));
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

/// Parse the messages from the _intl.dart file, and has methods for getting
/// information from them.
///
/// Note that this assumes things about the format, and will fail if the file is
/// changed outside those assumptions.
class MessageParser {
  /// For [contents] representing an existing Intl class, read the messages
  /// and return them indexed by name.
  Map<String, String> parseFile(String contents, String path) {
    ParseStringResult parsed = parseString(content: contents, path: path);
    ClassDeclaration intlClass =
        parsed.unit.declarations.first as ClassDeclaration;
    List<MethodDeclaration> methods =
        intlClass.members.toList().cast<MethodDeclaration>();
    return {for (var method in methods) method.name.name: '  $method'};
  }

  /// Given a full Intl method's source code, return the name.
  String methodName(String source) => parseMethod(source).name.name;

  /// Return a method in the context of a class, so it can be parsed where it
  /// might not in isolation. (e.g. if it's static).
  String inClassContext(String methodSource) => 'class Foo { $methodSource }';

  /// The message text for an Intl method, that is to say the first argument
  /// of the method. We expect [method] to be a declaration of the form
  ///
  ///   `static String foo() => Intl.message(messageText, <...other arguments>`
  ///
  /// or a getter of the same form.
  String messageText(String source) {
    // TODO: Doesn't work for Intl.plural/select where there is no
    // single text argument. We return an empty string so they will always
    // match as being the same and it will use the existing one.
    // TODO: Rather than throw, could this e.g. return a different suggested name?
    var method = parseMethod(source);
    MethodInvocation invocation =
        method.body.childEntities.toList()[1] as MethodInvocation;
    if (invocation.methodName.name != 'message') {
      // This isn't an Intl.message call, we don't know what to do, bail.
      return '';
    }
    var text = invocation.argumentList.arguments.first.toSource();
    return text;
  }

  MethodDeclaration parseMethod(String source) {
    var parsed = parseString(content: inClassContext(source));
    var classDeclaration = parsed.unit.declarations.first as ClassDeclaration;
    var method = classDeclaration.members.first;
    return method as MethodDeclaration;
  }
}

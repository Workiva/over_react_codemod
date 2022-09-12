import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:file/file.dart';
import 'package:over_react_codemod/src/intl_suggestors/utils.dart';
import 'package:path/path.dart' as p;

class MessageParser {
  late ParseStringResult parsed;

  Map<String, String> parseFile(String contents, String origin) {
    if (contents.contains("Intl.")) {
      parsed = parseString(content: contents, path: origin);
    } else {
      return {};
    }
    // var visitor = MessageFindingVisitor(this);
    // parsed.accept(visitor);
    ClassDeclaration foo = parsed.unit.declarations.first as ClassDeclaration;
    List<MethodDeclaration> methods =
        foo.members.toList().cast<MethodDeclaration>();
    return {for (var method in methods) method.name.name: '  $method'};
  }
}

/// Represents the generated file with the Intl class.
///
/// Right now this just wraps the file, but in the future it can be more
/// abstract to make it easier to add new messages to existing files and
/// otherwise programmatically modify it.
class IntlMessages {
  final String packageName;
  File outputFile;
  late String existingContents;
  final String className;
  Map<String, String> methods = {};
  bool addedNewMethods = false;

  IntlMessages(this.packageName, Directory currentDir, String packagePath,
      {File? output})
      : outputFile = output ??
            currentDir.childFile(p.join(
                packagePath, 'lib', 'src', 'intl', '${packageName}_intl.dart')),
        // TODO: I think packagePath only applies if there's a sub-package.
        className = toClassName('${packageName}') {
    _readExisting();
  }

  /// Read the existing file and incorporate its methods.
  void _readExisting() {
    if (outputFile.existsSync()) {
      existingContents = outputFile.readAsStringSync();
    } else {
      existingContents = '';
    }
    parseMethods(existingContents)
        .forEach((name, text) => addMethodNamed(text, name));
  }

  /// Read all the methods from an existing file.
  Map<String, String> parseMethods(String content) {
    if (content.isEmpty) {
      return {};
    }
    return MessageParser().parseFile(content, outputFile.path);
  }

  /// Given a full method, extract the name.
  static String methodName(String method) {
    var match = methodMatcher.matchAsPrefix(method);
    if (match == null) {
      print("Can't find method name for $method");
      return 'invalid method name';
    } else {
      return match.group(match.groupCount)!;
    }
  }

  // TODO: Get rid of the pseudo-file operations if possible.
  String messageContents() => _messageContents;

  void addMethod(String method) {
    // We assume this means we're adding a new one.
    addedNewMethods |= true;
    addMethodNamed(method, methodName(method));
  }

  void addMethodNamed(String method, String name) {
    if (methods.containsKey(name)) {
      var existingMethod = methods[name]!;
      if (existingMethod != method) {
        if (messageText(existingMethod) != messageText(method)) {
          throw AssertionError('''
Attempting to add a different message with the same name:
  new: $method
  old: ${methods[name]}''');
        } else {
          // Seems to match, keep the existing one, which may have modifications (e.g. add description).
          return;
        }
      }
    }
    methods[name] = method;
  }

  // We expect [method] to be a declaration of the form
  //
  //   `static String foo() => Intl.message(messageText, <...other arguments>`
  //
  // or a getter of the same form.
  // TODO: THIS WILL NOT WORK FOR PLURAL/SELECT. We just return an empty string so
  // they will always match.
  String messageText(String method) {
    var parsed = parseString(content: method.replaceFirst('static', ''));
    var m = parsed.unit.declarations.first as FunctionDeclaration;
    MethodInvocation invocation =
        m.functionExpression.body.childEntities.toList()[1] as MethodInvocation;
    if (invocation.methodName.name != 'message') {
      // This isn't an Intl.message call, we don't know what to do, bail.
      return '';
    }
    var text = invocation.argumentList.arguments.first.toSource();
    return text;
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

  /// A probably unique string for mechanism for finding the message names.
  static const _methodDelimiter = '  static String ';

  /// The beginning of any Intl class.
  static String prologueFor(String className) =>
      '''import 'package:intl/intl.dart';

//ignore: avoid_classes_with_only_static_members
//ignore_for_file: unnecessary_brace_in_string_interps

class $className {''';

  /// The beginning of our Intl class.
  String get prologue => prologueFor(className);

  /// Used to extract the method names.
  // TODO: Don't use RegExp.
  static RegExp methodMatcher = RegExp(r'^\s+static String (get )*(\w+)');

  /// Used to split the string into separate methods. Doesn't include the name, which
  /// would get removed if we split on this.
  // TODO: Don't use RegExp.
  static RegExp methodSplitter = RegExp(r'^\s+static String ', multiLine: true);
}

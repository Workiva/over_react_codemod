import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:over_react_codemod/src/intl_suggestors/intl_message_syntax.dart';
import 'package:over_react_codemod/src/intl_suggestors/message_parser.dart';
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

  /// The methods after removing any that appear to be unused.
  ///
  /// If this is empty, it probably means we haven't used the prune option.
  Map<String, Method> prunedMethods = {};

  /// If we are pruning, the list of methods that we found used. If empty, we were
  /// likely not pruning.
  // TODO: Clean up this, prunedMethods, and how we check if we were pruning or not.
  Set<String> methodsUsed = {};

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

  void noteUsage(String methodName) {
    methodsUsed.add(methodName);
  }

  /// Find the existing name for [name]+number that has the same [messageText], or
  /// if there isn't one, return the first available.
  String nameForString(String name, String messageText,
      {bool startAtZero = false}) {
    var index = 1;
    var newName = '$name${startAtZero ? 0 : ''}';
    while (isNameTaken(newName, messageText)) {
      newName = '$name${index++}';
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
    var methodsToWrite = prunedMethods.isEmpty ? methods : prunedMethods;
    (methodsToWrite.keys.toList()..sort())
        .forEach((name) => buffer.write('\n${methodsToWrite[name]?.source}'));
    return '$buffer';
  }

  /// Remove any methods that we haven't seen a usage for.
  void prune() {
    // Don't prune if we don't seem to have looked for usages.
    if (methodsUsed.isEmpty) return;

    prunedMethods = {
      for (var name in methods.keys)
        if (methodsUsed.contains(name)) name: methods[name]!
    };
  }

  /// Write the messages to a file. If the file exists and there are no changes, it will just
  /// stop unless [force] is true.
  void write({bool force = false}) {
    prune();
    // Create the file if it didn't exist, but if there are no changes, don't rewrite the existing.
    var exists = outputFile.existsSync();
    var fileContents = exists ? outputFile.readAsStringSync() : '';
    var hasTheSamePrologue = fileContents.startsWith(prologue);
    if (force || !exists || fileContents.isEmpty) {
      outputFile.createSync(recursive: true);
      outputFile.writeAsStringSync(contents);
    } else if (addedNewMethods ||
        !hasTheSamePrologue ||
        prunedMethods.isNotEmpty) {
      outputFile.writeAsStringSync(contents);
    }
  }

  /// The dependency analyzer thinks we depend on this if we have the literal string, so
  /// use it in an interpolation to placate it.
  static const w_intl = 'w_intl';

  /// The beginning of any Intl class.
  static String prologueFor(String className) =>
      '''import 'package:${w_intl}/intl_wrapper.dart';

//ignore: avoid_classes_with_only_static_members
//ignore_for_file: unnecessary_brace_in_string_interps

class $className {''';

  /// The beginning of our Intl class.
  String get prologue => prologueFor(className);
}

import 'package:file/file.dart';
import 'package:over_react_codemod/src/intl_suggestors/utils.dart';
import 'package:path/path.dart' as p;

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
    parseMethods(existingContents).forEach(addMethod);
  }

  /// Read all the methods from an existing file.
  List<String> parseMethods(String content) {
    if (content.isEmpty) {
      return [];
    }
    // TODO: Actually parse these.
    var classBody =
        content.substring(prologue.length, content.lastIndexOf('}'));
    // Include a newline in the split, so we only catch the start of lines,
    // but we don't need a starting newline in the actual method text, so omit it.
    var individualMethods = classBody.split('\n$_methodDelimiter');
    return [
      for (var method in individualMethods)
        if (method.trim().isNotEmpty) '$_methodDelimiter${method.trim()}'
    ];
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
    var name = methodName(method);
    // TODO: Can this happen in practice? Should we do something better than stop the whole migration?
    if (methods.containsKey(name) && methods[name] != method) {
      throw AssertionError('''
Attempting to add a different message with the same name:
  new: $method
  old: ${methods[name]}''');
    }
    methods[methodName(method)] = method;
  }

  void delete() => outputFile.deleteSync();

  String get contents =>
      (StringBuffer()..write(prologue)..write(_messageContents)..write('\n}'))
          .toString();

  // Just the messages, without the prologue or closing brace. Mostly used for testing.
  String get _messageContents {
    var buffer = StringBuffer();
    (methods.keys.toList()..sort())
        .forEach((name) => buffer.write('\n${methods[name]}'));
    return '$buffer';
  }

  write() {
    outputFile.createSync(recursive: true);
    outputFile.writeAsStringSync(contents);
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
  static RegExp methodMatcher = RegExp(r'^ +static String (get )*(\w+)');
}

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
  final File outputFile;
  late String existingContents;
  final String className;
  Set<String> methods = {};

  String get prologue => '''import 'package:intl/intl.dart';

//ignore: avoid_classes_with_only_static_members
//ignore_for_file: unnecessary_brace_in_string_interps

class $className {''';

  IntlMessages(this.packageName, Directory currentDir, String packagePath)
      :
        // TODO: I think packagePath only applies if there's a sub-package.
        outputFile = currentDir.childFile(p.join(
            packagePath, 'lib', 'src', 'intl', '${packageName}_intl.dart')),
        className = toClassName('${packageName}') {
    _readExisting();
  }

  void _readExisting() {
    if (outputFile.existsSync()) {
      existingContents = outputFile.readAsStringSync();
    } else {
      existingContents = '';
    }
  }

  // TODO: Get rid of the pseudo-file operations if possible.
  String messageContents() => _messageContents;

  void addMethod(String method) {
    methods.add(method);
    // outputFile.writeAsStringSync(method, mode: FileMode.append);
  }

  void delete() => outputFile.deleteSync();

  String get contents =>
      (StringBuffer()..write(prologue)..write(_messageContents)..write('\n}'))
          .toString();

  // Just the messages, without the prologue or closing brace. Mostly used for testing.
  String get _messageContents {
    var buffer = StringBuffer();
    (methods.toList()..sort()).forEach(buffer.write);
    return '$buffer';
  }

  write() {
    if (methods.isEmpty) return;
    outputFile.createSync(recursive: true);
    outputFile.writeAsStringSync(contents);
  }
}

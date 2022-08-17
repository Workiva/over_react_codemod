import 'dart:io';

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
  final String className;

  String get classPredicate => '''import 'package:intl/intl.dart';

//ignore: avoid_classes_with_only_static_members
//ignore_for_file: unnecessary_brace_in_string_interps

class $className {
''';

  IntlMessages(this.packageName, Directory currentDir, String packagePath)
      :
        // TODO: I think packagePath only applies if there's a sub-package.
        outputFile = currentDir.childFile(p.join(
            packagePath, 'lib', 'src', 'intl', '${packageName}_intl.dart')),
        className = toClassName('${packageName}');

  bool contains(String x) => outputFile.readAsStringSync().contains(x);

  // TODO: Get rid of the pseudo-file operations if possible.
  String readAsStringSync() => outputFile.readAsStringSync();

  void append(String x) =>
      outputFile.writeAsStringSync(x, mode: FileMode.append);

  void deleteSync() => outputFile.deleteSync();

  initialize() {
    bool existingOutputFile = outputFile.existsSync();

    if (!existingOutputFile) {
      outputFile.createSync(recursive: true);
      outputFile.writeAsStringSync(classPredicate);
    } else {
      final List<String> lines = outputFile.readAsLinesSync();
      lines.removeLast();
      String outputContent = lines.join('\n');
      outputFile.writeAsStringSync(outputContent);
    }
  }

  write() {
    if (exitCode != 0 || outputFile.readAsStringSync() == classPredicate) {
      outputFile.deleteSync();
    } else {
      var prologueLength = 6;
      List<String> lines = outputFile.readAsLinesSync();
      final functions = lines.sublist(prologueLength);
      functions.removeWhere((string) => string == '');
      // TODO: Sort by function, not by line.
      // functions.sort();
      lines.replaceRange(prologueLength, lines.length, functions);
      lines.add('}');
      outputFile.writeAsStringSync(lines.join('\n'), mode: FileMode.write);
    }
  }
}

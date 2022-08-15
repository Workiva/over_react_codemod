import 'dart:io';

import 'package:file/file.dart';
import 'package:over_react_codemod/src/intl_suggestors/utils.dart';
import 'package:path/path.dart' as p;

class IntlMessages {
  final String packageName;
  final File outputFile;
  final String className;

  String get classPredicate =>
      "import 'package:intl/intl.dart';\n\n//ignore: avoid_classes_with_only_static_members\nclass $className {\n";

  IntlMessages(this.packageName, Directory currentDir, String packagePath)
      :
        // What's going on with this? Wouldn't currentDir and packagePath have to agree anyway?
        outputFile = currentDir.childFile(p.join(
            packagePath, 'lib', 'src', 'intl', '${packageName}_intl.dart')),
        className = toClassName('${packageName}');

  contains(String x) => outputFile.contents.contains(x);

  append(String x) => outputFile.writeAsStringSync(x, mode: FileMode.append);

  flirp() {
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
      List<String> lines = outputFile.readAsLinesSync();
      final functions = lines.sublist(4);
      functions.removeWhere((string) => string == '');
      functions.sort();
      lines.replaceRange(4, lines.length, functions);
      lines.add('}');
      outputFile.writeAsStringSync(lines.join('\n'), mode: FileMode.write);
    }
  }
}

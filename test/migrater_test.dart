import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

final pathToMigrater = p.absolute('migrater.py');
final pathToBeforeCodeModTestFixtures = p.absolute('test/test_fixtures/before_codemod/');
final pathToAfterCodeModTestFixtures = p.absolute('test/test_fixtures/after_codemod/');

void main() {
  group('Migrater', () {
    Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('over_react_codemod_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('correctly converts components in parts', () async {
      await codeModAndCompare(tempDir, 'component_in_part.dart');
    });

    test('correctly converts components in a library', () async {
      await codeModAndCompare(tempDir, 'component_in_library.dart');
    });

    test('correctly adds part directive to the generated file in the library file', () async {
      await codeModAndCompare(tempDir, 'test_component_library.dart');
    });

    test('correctly coverts \$PropKeys references', () async {
      await codeModAndCompare(tempDir, 'dollar_prop_keys_usages.dart');
    });

    test('correctly coverts \$Prop references', () async {
      await codeModAndCompare(tempDir, 'component_with_multiple_consumed_props.dart');
    });
  });
}

Future<Null> codeModAndCompare(Directory tempDir, String fileToCodemod) async {
  /// Copy the file to codemod to the temporary directory.
  await Process.run('/bin/bash',
      ['-c', 'cp -r $fileToCodemod /${tempDir.absolute.path}'], workingDirectory: pathToBeforeCodeModTestFixtures);

  /// Codemod the file within the temporary directory
  await Process.start('python', [pathToMigrater], workingDirectory: tempDir.absolute.path).then((Process process) async {
    await process.stdin.write('A\nA\n');
    await process.stdin.close();
    await process.exitCode;
  });

  /// Compare expected results against codemod file in temp directory.
  String expectedResults = new File(pathToAfterCodeModTestFixtures + fileToCodemod).readAsStringSync();
  String testFile = new File('${tempDir.absolute.path}/$fileToCodemod').readAsStringSync();

  expect(testFile, equals(expectedResults));
}

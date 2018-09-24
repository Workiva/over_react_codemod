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
      await codemodAndCompare(tempDir, 'component_in_part.dart');
    });

    test('correctly converts components in a library', () async {
      await codemodAndCompare(tempDir, 'component_in_library.dart');
    });

    test('correctly adds part directive to the generated file in the library file', () async {
      await codemodAndCompare(tempDir, 'test_component_library.dart');
    });

    test('correctly coverts \$PropKeys references', () async {
      await codemodAndCompare(tempDir, 'dollar_prop_keys_usages.dart');
    });

    test('correctly coverts \$Prop references', () async {
      await codemodAndCompare(tempDir, 'component_with_multiple_consumed_props.dart');
    });

    test('script is idempotent when modifiying a component', () async {
      await codemodAndCompare(tempDir, 'component_with_multiple_consumed_props.dart', assertIdempotence: true);
    });

    test('script is idempotent when modifiying a test', () async {
      await codemodAndCompare(tempDir, 'dollar_prop_keys_usages.dart', assertIdempotence: true);
    });
  });
}

Future<Null> copyFileToTempDir(String tempDirPath, String fileToCodemod) async {
  await Process.run('/bin/bash',
      ['-c', 'cp -r $fileToCodemod /$tempDirPath'], workingDirectory: pathToBeforeCodeModTestFixtures);
}

Future<Null> codemodFileInTempDir(String tempDirPath) async {
  await Process.start('python', [pathToMigrater], workingDirectory: tempDirPath).then((Process process) async {
    await process.stdin.write('A\nA\n');
    await process.stdin.close();
    await process.exitCode;
  });
}

Future<Null> codemodAndCompare(Directory tempDir, String fileToCodemod, {bool assertIdempotence: false}) async {
  final tempDirPath = tempDir.absolute.path;

  await copyFileToTempDir(tempDirPath, fileToCodemod);
  await codemodFileInTempDir(tempDirPath);

  if (assertIdempotence) {
    String firstCodemod = new File('$tempDirPath/$fileToCodemod').readAsStringSync();

    /// Codemod the same file a second time.
    await codemodFileInTempDir(tempDirPath);

    String secondCodemod = new File('$tempDirPath/$fileToCodemod').readAsStringSync();

    expect(firstCodemod, equals(secondCodemod));
  } else {
    /// Compare expected results against codemod file in temp directory.
    String expectedResults = new File(pathToAfterCodeModTestFixtures + fileToCodemod).readAsStringSync();
    String testFile = new File('$tempDirPath/$fileToCodemod').readAsStringSync();

    expect(testFile, equals(expectedResults));
  }
}

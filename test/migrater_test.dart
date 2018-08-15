import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Migrater', () {
    test('correctly converts components with part directive', () async {
      final testFixtureDirectory = p.absolute('test/test_fixtures/before_codemod/components_in_parts');
      final expectedResultsPath = p.absolute('test/test_fixtures/after_codemod/components_in_parts/component_in_part.dart');
      final testFilePath = p.absolute('test/test_fixtures/before_codemod/components_in_parts/temp/component_in_part.dart');

      await setupAndCodemod(testFixtureDirectory);

      /// Compare expected results against codemod file in temp directory
      String expectedResults = new File(expectedResultsPath).readAsStringSync();
      String testFile = new File(testFilePath).readAsStringSync();

      expect(testFile, equals(expectedResults));

      await removeTempDir(testFixtureDirectory);
    });

    test('correctly converts components in a library', () async {
      final testFixtureDirectory = p.absolute('test/test_fixtures/before_codemod/components_in_library');
      final expectedResultsPath = p.absolute('test/test_fixtures/after_codemod/components_in_library/component_in_library.dart');
      final testFilePath = p.absolute('test/test_fixtures/before_codemod/components_in_library/temp/component_in_library.dart');

      await setupAndCodemod(testFixtureDirectory);

      /// Compare expected results against codemod file in temp directory
      String expectedResults = new File(expectedResultsPath).readAsStringSync();
      String testFile = new File(testFilePath).readAsStringSync();

      expect(testFile, equals(expectedResults));

      await removeTempDir(testFixtureDirectory);
    });
  });
}

/// Creates a temp directory and copies the un-modified test fixtures to it. Then
/// migrater.py is run on these test fixtures to make the codemod changes.
Future<Null> setupAndCodemod(String pathToTestFixtureDirectory) async {
  final pathToMigrater = p.absolute('migrater.py');
  final pathToTempDirectory = p.absolute('${pathToTestFixtureDirectory}/temp');

  await Process.run('/bin/bash',
      ['-c', 'mkdir -p temp && cp -r *.dart /$pathToTempDirectory'], workingDirectory: pathToTestFixtureDirectory);

  await Process.start('/bin/bash', ['-c', 'python $pathToMigrater'], workingDirectory: pathToTempDirectory).then((Process process) async {
    await process.stdin.write('A\nA\n');
    await process.stdin.close();
    await process.exitCode;
  });
}

/// Deletes the temp directory.
Future<Null> removeTempDir(String pathToTestFixtureDirectory) async {
  await Process.run('/bin/bash', ['-c', 'rm -R temp'], workingDirectory: pathToTestFixtureDirectory);
}

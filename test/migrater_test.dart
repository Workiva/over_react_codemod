import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('Migrater', () {
    test('correctly converts components with part directive', () async {
      final pathToTestFixtureDirectory = p.absolute('test/test_fixtures/before_codemod/component_in_parts');
      final pathToExpectedResults = p.absolute('test/test_fixtures/after_codemod/component_in_parts/component_in_part.dart');
      final pathToTestFile = p.absolute('test/test_fixtures/before_codemod/component_in_parts/temp/component_in_part.dart');

      makeComparison(pathToTestFixtureDirectory, pathToExpectedResults, pathToTestFile);
    });

    test('correctly converts components in a library', () async {
      final pathToTestFixtureDirectory = p.absolute('test/test_fixtures/before_codemod/component_in_library');
      final pathToExpectedResults = p.absolute('test/test_fixtures/after_codemod/component_in_library/component_in_library.dart');
      final pathToTestFile = p.absolute('test/test_fixtures/before_codemod/component_in_library/temp/component_in_library.dart');

      makeComparison(pathToTestFixtureDirectory, pathToExpectedResults, pathToTestFile);
    });

    test('correctly converts components without props', () async {
      final pathToTestFixtureDirectory = p.absolute('test/test_fixtures/before_codemod/component_without_props');
      final pathToExpectedResults = p.absolute('test/test_fixtures/after_codemod/component_without_props/component_without_props.dart');
      final pathToTestFile = p.absolute('test/test_fixtures/before_codemod/component_without_props/temp/component_without_props.dart');

      makeComparison(pathToTestFixtureDirectory, pathToExpectedResults, pathToTestFile);
    });

    test('correctly converts single \$PropKeys reference', () async {
      final pathToTestFixtureDirectory = p.absolute('test/test_fixtures/before_codemod/mock_test_single_prop');
      final pathToExpectedResults = p.absolute('test/test_fixtures/after_codemod/mock_test_single_prop/mock_test_single_prop.dart');
      final pathToTestFile = p.absolute('test/test_fixtures/before_codemod/mock_test_single_prop/temp/mock_test_single_prop.dart');

      await makeComparison(pathToTestFixtureDirectory, pathToExpectedResults, pathToTestFile);
    });

    test('correctly coverts multiple \$PropKeys references', () async {
      final pathToTestFixtureDirectory = p.absolute('test/test_fixtures/before_codemod/mock_test_multiple_props');
      final pathToExpectedResults = p.absolute('test/test_fixtures/after_codemod/mock_test_multiple_props/mock_test_multiple_props.dart');
      final pathToTestFile = p.absolute('test/test_fixtures/before_codemod/mock_test_multiple_props/temp/mock_test_multiple_props.dart');

      await makeComparison(pathToTestFixtureDirectory, pathToExpectedResults, pathToTestFile);
    });

    test('correctly coverts single \$Prop reference', () async {
      final pathToTestFixtureDirectory = p.absolute('test/test_fixtures/before_codemod/component_with_single_consumed_prop');
      final pathToExpectedResults = p.absolute('test/test_fixtures/after_codemod/component_with_single_consumed_prop/component_with_single_consumed_prop.dart');
      final pathToTestFile = p.absolute('test/test_fixtures/before_codemod/component_with_single_consumed_prop/temp/component_with_single_consumed_prop.dart');

      await makeComparison(pathToTestFixtureDirectory, pathToExpectedResults, pathToTestFile);
    });

    test('correctly coverts multiple \$Prop references', () async {
      final pathToTestFixtureDirectory = p.absolute('test/test_fixtures/before_codemod/component_with_multiple_consumed_props');
      final pathToExpectedResults = p.absolute('test/test_fixtures/after_codemod/component_with_multiple_consumed_props/component_with_multiple_consumed_props.dart');
      final pathToTestFile = p.absolute('test/test_fixtures/before_codemod/component_with_multiple_consumed_props/temp/component_with_multiple_consumed_props.dart');

      await makeComparison(pathToTestFixtureDirectory, pathToExpectedResults, pathToTestFile);
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

/// Makes the comparison between the expected result (migrated file) and the test file
/// (the file that is migrated during the test run in a temp directory).
Future<Null> makeComparison(String pathToTestFixtureDirectory, String pathToExpectedResults, String pathToTestFile) async {
  await setupAndCodemod(pathToTestFixtureDirectory);

  /// Compare expected results against codemod file in temp directory.
  String expectedResults = new File(pathToExpectedResults).readAsStringSync();
  String testFile = new File(pathToTestFile).readAsStringSync();

  expect(testFile, equals(expectedResults));

  await removeTempDir(pathToTestFixtureDirectory);
}

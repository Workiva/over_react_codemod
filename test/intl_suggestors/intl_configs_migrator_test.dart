// Copyright 2021 Workiva Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:analyzer/error/error.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:over_react_codemod/src/intl_suggestors/intl_configs_migrator.dart';
import 'package:over_react_codemod/src/intl_suggestors/intl_messages.dart';
import 'package:test/test.dart';

import '../resolved_file_context.dart';
import '../util.dart';

void main() {
  group('IntlConfigsMigrator', () {
    final resolvedContext = SharedAnalysisContext.overReact;

    // Warm up analysis in a setUpAll so that if getting the resolved AST times out
    // (which is more common for the WSD context), it fails here instead of failing the first test.
    setUpAll(resolvedContext.warmUpAnalysis);

    late IntlMessages file;
    SuggestorTester? testSuggestor;

    setUp(() async {
      final FileSystem fs = MemoryFileSystem();
      final Directory tmp = await fs.systemTempDirectory.createTemp();
      file = IntlMessages('TestClass', tmp, '');
      file.outputFile.createSync(recursive: true);
    });

    tearDown(() {
      file.deleteSync();
    });

    test('correctly changes display name', () async {
      testSuggestor = getSuggestorTester(ConfigsMigrator('TestClassIntl', file),
          resolvedContext: resolvedContext,
          inputUrl: 'test/input/display_name_config.dart');
      await testSuggestor!(
        input: '''
            class TestExperienceConfig {
              @override
              String get displayName => 'Test Display Name';
            }
            ''',
        expectedOutput: '''
            class TestExperienceConfig {
              @override
              String get displayName => TestClassIntl.testDisplayName;
            }
            ''',
      );
      final expectedFileContent =
          "\n  static String get testDisplayName => Intl.message('Test Display Name', name: 'TestClassIntl_testDisplayName',);";
      expect(file.readAsStringSync(), expectedFileContent);
    });

    test('correctly changes name', () async {
      testSuggestor = getSuggestorTester(ConfigsMigrator('TestClassIntl', file),
          resolvedContext: resolvedContext,
          inputUrl: 'test/input/name_config.dart');

      await testSuggestor!(
        input: '''
            class TestExperienceConfig {
              @override
              String get name => 'Test Name';
            }
            ''',
        expectedOutput: '''
            class TestExperienceConfig {
              @override
              String get name => TestClassIntl.testName;
            }
            ''',
      );
      final expectedFileContent =
          "\n  static String get testName => Intl.message('Test Name', name: 'TestClassIntl_testName',);";
      expect(file.readAsStringSync(), expectedFileContent);
    });

    test('correctly changes title', () async {
      testSuggestor = getSuggestorTester(ConfigsMigrator('TestClassIntl', file),
          resolvedContext: resolvedContext,
          inputUrl: 'test/input/title_config.dart');
      await testSuggestor!(
        input: '''
            class TestExperienceConfig {
              @override
              String get title => 'Test Title';
            }
            ''',
        expectedOutput: '''
            class TestExperienceConfig {
              @override
              String get title => TestClassIntl.testTitle;
            }
            ''',
      );
      final expectedFileContent =
          "\n  static String get testTitle => Intl.message('Test Title', name: 'TestClassIntl_testTitle',);";
      expect(file.readAsStringSync(), expectedFileContent);
    });
  });
}

bool isUndefinedIntlError(AnalysisError error) =>
    error.message.contains("Undefined name 'TestProjectIntl'");

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

import 'package:codemod/codemod.dart';
import 'package:over_react_codemod/src/rmui_preparation_suggestors/constants.dart';
import 'package:over_react_codemod/src/rmui_preparation_suggestors/dart_script_adder.dart';
import 'package:test/test.dart';

import '../util.dart';
import 'html_script_adder_test.dart';

void main() {
  group('DartScriptAdder', () {
    // Test both suggestors together to:
    // 1. verify for all cases that the wrong bundle type isn't added
    // 2. verify they work well together, since they'll never really be run individually
    final testSuggestor = getSuggestorTester(aggregate([
      DartScriptAdder(rmuiBundleProd, true),
      DartScriptAdder(rmuiBundleDev, false)
    ]));

    test('empty file', () async {
      await testSuggestor(expectedPatchCount: 0, input: '');
    });

    test('no matches', () async {
      await testSuggestor(
        expectedPatchCount: 0,
        input: '''
            final script = '<script src="packages/react_testing_library/js/react-testing-library.js"></script>';
          ''',
      );
    });

    group('add non-prod and prod scripts', () {
      for (final pathPrefix in pathPrefixesToTest) {
        jsFileTypes.forEach((testName, scripts) {
          final isTestProd = testName.contains('Prod');

          group(testName, () {
            _dartScriptAdderTests(
              testSuggestor,
              scripts: scripts,
              expectedAddedScript: isTestProd ? rmuiBundleProd : rmuiBundleDev,
              pathPrefix: pathPrefix,
            );
          });
        });
      }
    });
  });
}

void _dartScriptAdderTests(
  SuggestorTester testSuggestor, {
  required List<GetScriptWithPathPrefix> scripts,
  required ScriptToAdd expectedAddedScript,
  required String pathPrefix,
}) {
  final scriptStrings = scripts
      .map((getScriptWithPrefix) => getScriptWithPrefix(pathPrefix))
      .toList();

  group('string literal in a list literal', () {
    test('', () async {
      await testSuggestor(
        expectedPatchCount: 1,
        input: '''
              List<String> _reactHtmlHeaders = const [
                '${scriptStrings.join('\',\n\'')}'
              ];
            ''',
        expectedOutput: '''
              List<String> _reactHtmlHeaders = const [
                '${scriptStrings.join('\',\n\'')}'
                ,\n\'${expectedAddedScript.scriptTag(pathPrefix: pathPrefix)}\'
              ];
            ''',
      );
    });

    test('when there is already a comma after the preceding string', () async {
      await testSuggestor(
        expectedPatchCount: 1,
        input: '''
            List<String> _reactHtmlHeaders = const [
              '${scriptStrings.join('\',\n\'')}',
              '<script src="packages/react_testing_library/js/react-testing-library.js"></script>',
            ];
          ''',
        expectedOutput: '''
            List<String> _reactHtmlHeaders = const [
              '${scriptStrings.join('\',\n\'')}',
              '${expectedAddedScript.scriptTag(pathPrefix: pathPrefix)}',
              '<script src="packages/react_testing_library/js/react-testing-library.js"></script>',
            ];
          ''',
      );
    });

    test('when the added script already exists in the list', () async {
      await testSuggestor(
        expectedPatchCount: 0,
        input: '''
            List<String> _reactHtmlHeaders = const [
              '${scriptStrings.join('\',\n\'')}',
              '${expectedAddedScript.scriptTag(pathPrefix: pathPrefix)}',
            ];
          ''',
      );
    });

    test('with a different script added', () async {
      final someOtherScript =
          ScriptToAdd(path: 'packages/something_else/something-else.js');
      final anotherTestSuggestor = getSuggestorTester(aggregate([
        DartScriptAdder(someOtherScript, false),
        DartScriptAdder(someOtherScript, true),
      ]));

      await anotherTestSuggestor(
        expectedPatchCount: 1,
        input: '''
            List<String> _reactHtmlHeaders = const [
              '${scriptStrings.join('\',\n\'')}',
            ];
          ''',
        expectedOutput: '''
            List<String> _reactHtmlHeaders = const [
              '${scriptStrings.join('\',\n\'')}',
              '${someOtherScript.scriptTag(pathPrefix: pathPrefix)}',
            ];
          ''',
      );
    });

    test('empty list', () async {
      await testSuggestor(
        expectedPatchCount: 0,
        input: '''
            List<String> _reactHtmlHeaders = [];
          ''',
      );
    });

    test('no react-dart js files', () async {
      await testSuggestor(
        expectedPatchCount: 0,
        input: '''
            List<String> _reactHtmlHeaders = [
              '<script src="packages/react_testing_library/js/react-testing-library.js"></script>',
            ];
          ''',
      );
    });

    test('nested in other logic', () async {
      await testSuggestor(
        expectedPatchCount: 1,
        input: '''
            import 'package:dart_dev/dart_dev.dart' show config, TestRunnerConfig, Environment;
            
            main(List<String> args) async {
              config.genTestRunner.configs = [
                new TestRunnerConfig(
                    genHtml: true,
                    directory: 'test/unit',
                    env: Environment.browser,
                    filename: 'generated_runner_test',
                    dartHeaders: const [
                      "import 'package:web_skin/web_skin.dart';",
                      "import 'package:platform_detect/decorator.dart';",
                      "import 'package:web_skin_dart/ui_core.dart';",
                      "import 'package:over_react/over_react.dart';",
                      "import 'package:web_skin_dart/ui_components.dart';",
                    ],
                    htmlHeaders: const [
                      '${scriptStrings.join('\',\n\'')}',
                    ]),
              ];
            }
          ''',
        expectedOutput: '''
            import 'package:dart_dev/dart_dev.dart' show config, TestRunnerConfig, Environment;
            
            main(List<String> args) async {
              config.genTestRunner.configs = [
                new TestRunnerConfig(
                    genHtml: true,
                    directory: 'test/unit',
                    env: Environment.browser,
                    filename: 'generated_runner_test',
                    dartHeaders: const [
                      "import 'package:web_skin/web_skin.dart';",
                      "import 'package:platform_detect/decorator.dart';",
                      "import 'package:web_skin_dart/ui_core.dart';",
                      "import 'package:over_react/over_react.dart';",
                      "import 'package:web_skin_dart/ui_components.dart';",
                    ],
                    htmlHeaders: const [
                      '${scriptStrings.join('\',\n\'')}',
                      '${expectedAddedScript.scriptTag(pathPrefix: pathPrefix)}',
                    ]),
              ];
            }
          ''',
      );
    });
  });

  group('string literal in a variable declaration', () {
    test('', () async {
      await testSuggestor(
        expectedPatchCount: 1,
        input: '''
              const expectedTemplateHeaders = \'\'\'
                ${scriptStrings.join('\n                ')}
              \'\'\';
            ''',
        expectedOutput: '''
              const expectedTemplateHeaders = \'\'\'
                ${scriptStrings.join('\n                ')}
                ${expectedAddedScript.scriptTag(pathPrefix: pathPrefix)}
              \'\'\';
            ''',
      );
    });

    test('with a large string', () async {
      await testSuggestor(
        expectedPatchCount: 1,
        input: '''
            const expectedTemplateHeaders = \'\'\'
              <!DOCTYPE html>
              <html>
                <head>
                  <title>{{testName}}</title>
                  <!--my custom header-->
                  ${scriptStrings.join('\n                  ')}
                  <script src="packages/engine/gopherBindings.js"></script>
                  <!--In order to debug unit tests, use application/dart rather than x-dart-test-->
                  <script src="packages/react_testing_library/js/react-testing-library.js"></script>
                  {{testScript}}
                  <script src="packages/test/dart.js"></script>
                </head>
                <body></body>
              </html>
              \'\'\';
          ''',
        expectedOutput: '''
            const expectedTemplateHeaders = \'\'\'
              <!DOCTYPE html>
              <html>
                <head>
                  <title>{{testName}}</title>
                  <!--my custom header-->
                  ${scriptStrings.join('\n                  ')}
                  ${expectedAddedScript.scriptTag(pathPrefix: pathPrefix)}
                  <script src="packages/engine/gopherBindings.js"></script>
                  <!--In order to debug unit tests, use application/dart rather than x-dart-test-->
                  <script src="packages/react_testing_library/js/react-testing-library.js"></script>
                  {{testScript}}
                  <script src="packages/test/dart.js"></script>
                </head>
                <body></body>
              </html>
              \'\'\';
          ''',
      );
    });

    test('with a different script added', () async {
      final someOtherScript =
          ScriptToAdd(path: 'packages/something_else/something-else.js');
      final anotherTestSuggestor = getSuggestorTester(aggregate([
        DartScriptAdder(someOtherScript, false),
        DartScriptAdder(someOtherScript, true),
      ]));

      await anotherTestSuggestor(
        expectedPatchCount: 1,
        input: '''
            const expectedTemplateHeaders = \'\'\'
              ${scriptStrings.join('\n              ')}
            \'\'\';
          ''',
        expectedOutput: '''
            const expectedTemplateHeaders = \'\'\'
              ${scriptStrings.join('\n              ')}
              ${someOtherScript.scriptTag(pathPrefix: pathPrefix)}
            \'\'\';
          ''',
      );
    });

    test('when the script already exists', () async {
      await testSuggestor(
        expectedPatchCount: 0,
        input: '''
            const expectedTemplateHeaders = \'\'\'
              ${scriptStrings.join('\n              ')}
              ${expectedAddedScript.scriptTag(pathPrefix: pathPrefix)}
            \'\'\';
          ''',
      );
    });
  });
}

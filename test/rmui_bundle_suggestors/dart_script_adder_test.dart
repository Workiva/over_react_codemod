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

import 'package:over_react_codemod/src/rmui_bundle_suggestors/constants.dart';
import 'package:over_react_codemod/src/rmui_bundle_suggestors/dart_script_adder.dart';
import 'package:test/test.dart';

import '../util.dart';
import 'html_script_adder_test.dart';

main() {
  group('DartScriptAdder', () {
    final testSuggestor = getSuggestorTester(DartScriptAdder(rmuiBundleScript));

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

    group('string literal in a list literal', () {
      jsFileTypes.forEach((testName, scripts) {
        test(testName, () async {
          await testSuggestor(
            expectedPatchCount: 1,
            input: '''
              List<String> _reactHtmlHeaders = const [
                '${scripts.join('\',\n\'')}'
              ];
            ''',
            expectedOutput: '''
              List<String> _reactHtmlHeaders = const [
                '${scripts.join('\',\n\'')}',
                '$rmuiBundleScript'
              ];
            ''',
          );
        });
      });

      test('when there is already a comma after the preceding string',
          () async {
        await testSuggestor(
          expectedPatchCount: 1,
          input: '''
            List<String> _reactHtmlHeaders = const [
              '${prodReactOneFile[0]}',
              '<script src="packages/react_testing_library/js/react-testing-library.js"></script>',
            ];
          ''',
          expectedOutput: '''
            List<String> _reactHtmlHeaders = const [
              '${prodReactOneFile[0]}',
              '$rmuiBundleScript',
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
              '${devReact.join('\',\n\'')}',
              '$rmuiBundleScript',
            ];
          ''',
        );
      });

      test('with a different script added', () async {
        final someOtherScript =
            '<script src="packages/something_else/something-else.js"></script>';
        final anotherTestSuggestor =
            getSuggestorTester(DartScriptAdder(someOtherScript));

        await anotherTestSuggestor(
          expectedPatchCount: 1,
          input: '''
            List<String> _reactHtmlHeaders = const [
              '${prodReactOneFile[0]}',
            ];
          ''',
          expectedOutput: '''
            List<String> _reactHtmlHeaders = const [
              '${prodReactOneFile[0]}',
              '$someOtherScript',
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
                      '<script src="packages/react/react_with_addons.js"></script>',
                      '<script src="packages/react/react_dom.js"></script>',
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
                      '<script src="packages/react/react_with_addons.js"></script>',
                      '<script src="packages/react/react_dom.js"></script>',
                      '$rmuiBundleScript',
                    ]),
              ];
            }
          ''',
        );
      });
    });

    group('string literal in a variable declaration', () {
      jsFileTypes.forEach((testName, scripts) {
        test(testName, () async {
          await testSuggestor(
            expectedPatchCount: 1,
            input: '''
              const expectedTemplateHeaders = \'\'\'
                ${scripts.join('\n                ')}
              \'\'\';
            ''',
            expectedOutput: '''
              const expectedTemplateHeaders = \'\'\'
                ${scripts.join('\n                ')}
                $rmuiBundleScript
              \'\'\';
            ''',
          );
        });
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
                  <script src="packages/react/react_with_addons.js"></script>
                  <script src="packages/react/react_dom.js"></script>
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
                  <script src="packages/react/react_with_addons.js"></script>
                  <script src="packages/react/react_dom.js"></script>
                  $rmuiBundleScript
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
            '<script src="packages/something_else/something-else.js"></script>';
        final anotherTestSuggestor =
            getSuggestorTester(DartScriptAdder(someOtherScript));

        await anotherTestSuggestor(
          expectedPatchCount: 1,
          input: '''
            const expectedTemplateHeaders = \'\'\'
              ${prodReactOneFile[0]}
            \'\'\';
          ''',
          expectedOutput: '''
            const expectedTemplateHeaders = \'\'\'
              ${prodReactOneFile[0]}
              $someOtherScript
            \'\'\';
          ''',
        );
      });

      test('when the script already exists', () async {
        await testSuggestor(
          expectedPatchCount: 0,
          input: '''
            const expectedTemplateHeaders = \'\'\'
              ${prodReactOneFile[0]}
              $rmuiBundleScript
            \'\'\';
          ''',
        );
      });
    });
  });
}

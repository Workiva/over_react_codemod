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
          final script = '<script src="/packages/react/react.js"></script>';
        ''',
      );
    });

    group('string literal in a list literal', () {
      test('', () async {
        await testSuggestor(
          expectedPatchCount: 1,
          input: '''
            List<String> _reactHtmlHeaders = const [
              '<script src="packages/react/react_dom.js"></script>',
            ];
          ''',
          expectedOutput: '''
            List<String> _reactHtmlHeaders = const [
              '<script src="packages/react/react_dom.js"></script>',
              '$rmuiBundleScript',
            ];
          ''',
        );
      });

      test('when there are multiple react-dart js files in the list', () async {
        await testSuggestor(
          expectedPatchCount: 1,
          input: '''
            List<String> _reactHtmlHeaders = [
              '<script src="packages/react/react_with_addons.js"></script>',
              '<script src="packages/react/react_dom.js"></script>',
            ];
          ''',
          expectedOutput: '''
            List<String> _reactHtmlHeaders = [
              '<script src="packages/react/react_with_addons.js"></script>',
              '$rmuiBundleScript',
              '<script src="packages/react/react_dom.js"></script>',
            ];
          ''',
        );
      });

      test('when the added script already exists in the list', () async {
        await testSuggestor(
          expectedPatchCount: 0,
          input: '''
            List<String> _reactHtmlHeaders = const [
              '<script src="packages/react/react_dom.js"></script>',
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
              '<script src="packages/react/react_dom.js"></script>',
            ];
          ''',
          expectedOutput: '''
            List<String> _reactHtmlHeaders = const [
              '<script src="packages/react/react_dom.js"></script>',
              '$someOtherScript',
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
                      '$rmuiBundleScript',
                      '<script src="packages/react/react_dom.js"></script>',
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
              <!DOCTYPE html>
              <html>
                <head>
                  <title>{{testName}}</title>
                  <!--my custom header-->
                  <script src="packages/react/react_with_addons.js"></script>
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
                  $rmuiBundleScript
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

      test('with multiple react-dart JS scripts', () async {
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
                  $rmuiBundleScript
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
              <script src="packages/react/react_with_addons.js"></script>
            \'\'\';
          ''',
          expectedOutput: '''
            const expectedTemplateHeaders = \'\'\'
              <script src="packages/react/react_with_addons.js"></script>
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
              <script src="packages/react/react_with_addons.js"></script>
              $rmuiBundleScript
            \'\'\';
          ''',
        );
      });
    });
  });
}

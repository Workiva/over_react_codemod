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
import 'package:over_react_codemod/src/rmui_bundle_suggestors/constants.dart';
import 'package:over_react_codemod/src/rmui_bundle_suggestors/html_script_adder.dart';
import 'package:test/test.dart';

import '../util.dart';

const devReact = [
  '<script src="/packages/react/react.js"></script>',
  '<script src="/packages/react/react_dom.js"></script>',
];

const devReactWithAddons = [
  '<script src="/packages/react/react_with_addons.js"></script>',
  '<script src="/packages/react/react_dom.js"></script>',
];

const prodReact = [
  '<script src="/packages/react/react_prod.js"></script>',
  '<script src="/packages/react/react_dom_prod.js"></script>',
];

const prodReactOneFile = [
  '<script src="/packages/react/react_with_react_dom_prod.js"></script>',
];

const jsFileTypes = {
  'Dev React JS files': devReact,
  'Dev React with addons JS files': devReactWithAddons,
  'Prod React JS files': prodReact,
  'Prod React JS file (one file)': prodReactOneFile,
};

void main() {
  group('HtmlScriptAdder', () {
    // Test both suggestors together to:
    // 1. verify for all cases that the wrong bundle type isn't added
    // 2. verify they work well together, since they'll never really be run individually
    final testSuggestor = getSuggestorTester(aggregate([
      HtmlScriptAdder(rmuiBundleProd, true),
      HtmlScriptAdder(rmuiBundleDev, false)
    ]));

    test('empty file', () async {
      await testSuggestor(expectedPatchCount: 0, input: '');
    });

    test('no matches', () async {
      await testSuggestor(
        expectedPatchCount: 0,
        shouldDartfmtOutput: false,
        input: ''
            '<script src="packages/react_testing_library/js/react-testing-library.js"></script>\n'
            '',
      );
    });

    group('add prod and non-prod script', () {
      jsFileTypes.forEach((testName, scripts) {
        final isTestProd = testName.contains('Prod');

        group(testName, () {
          _htmlScriptAdderTests(
            testSuggestor,
            scripts: scripts,
            expectedAddedScript: isTestProd ? rmuiBundleProd : rmuiBundleDev,
          );
        });
      });
    });
  });
}

void _htmlScriptAdderTests(
  SuggestorTester testSuggestor, {
  required List<String> scripts,
  required String expectedAddedScript,
}) {
  test('basic case', () async {
    await testSuggestor(
      expectedPatchCount: 1,
      shouldDartfmtOutput: false,
      input: ''
          '${scripts.join('\n')}'
          '',
      expectedOutput: ''
          '${scripts.join('\n')}\n'
          '$expectedAddedScript\n'
          '',
    );
  });

  test('with indentation', () async {
    await testSuggestor(
      expectedPatchCount: 1,
      shouldDartfmtOutput: false,
      input: ''
          '  ${scripts.join('\n  ')}'
          '',
      expectedOutput: ''
          '  ${scripts.join('\n  ')}\n'
          '  $expectedAddedScript\n'
          '',
    );
  });

  test('in context with other HTML logic', () async {
    await testSuggestor(
      expectedPatchCount: 1,
      shouldDartfmtOutput: false,
      input: ''
          '<!DOCTYPE html>\n'
          '<html>\n'
          '  <head>\n'
          '    <title>{{testName}}</title>\n'
          '    <!--my custom header-->\n'
          '    ${scripts.join('\n    ')}\n'
          '    <script src="packages/engine/gopherBindings.js"></script>\n'
          '    <!--In order to debug unit tests, use application/dart rather than x-dart-test-->\n'
          '    <script src="packages/react_testing_library/js/react-testing-library.js"></script>\n'
          '    {{testScript}}\n'
          '    <script src="packages/test/dart.js"></script>\n'
          '  </head>\n'
          '  <body></body>\n'
          '</html>\n'
          '',
      expectedOutput: ''
          '<!DOCTYPE html>\n'
          '<html>\n'
          '  <head>\n'
          '    <title>{{testName}}</title>\n'
          '    <!--my custom header-->\n'
          '    ${scripts.join('\n    ')}\n'
          '    $expectedAddedScript\n'
          '    <script src="packages/engine/gopherBindings.js"></script>\n'
          '    <!--In order to debug unit tests, use application/dart rather than x-dart-test-->\n'
          '    <script src="packages/react_testing_library/js/react-testing-library.js"></script>\n'
          '    {{testScript}}\n'
          '    <script src="packages/test/dart.js"></script>\n'
          '  </head>\n'
          '  <body></body>\n'
          '</html>\n'
          '',
    );
  });

  test('with a different script added', () async {
    final someOtherScript =
        '<script src="packages/something_else/something-else.js"></script>';
    final anotherTestSuggestor = getSuggestorTester(aggregate([
      HtmlScriptAdder(someOtherScript, true),
      HtmlScriptAdder(someOtherScript, false),
    ]));

    await anotherTestSuggestor(
      expectedPatchCount: 1,
      shouldDartfmtOutput: false,
      input: ''
          '    ${scripts.join('\n    ')}'
          '',
      expectedOutput: ''
          '    ${scripts.join('\n    ')}\n'
          '    $someOtherScript\n'
          '',
    );
  });

  test('when the script already exists', () async {
    await testSuggestor(
      expectedPatchCount: 0,
      shouldDartfmtOutput: false,
      input: ''
          '    $expectedAddedScript\n'
          '    ${scripts.join('\n    ')}\n'
          '',
    );
  });
}

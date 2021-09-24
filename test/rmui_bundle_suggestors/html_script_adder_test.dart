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
    group('add prod script', () => _htmlScriptAdderTests(isProd: true));

    group('add non-prod script', () => _htmlScriptAdderTests(isProd: false));
  });
}

void _htmlScriptAdderTests({bool isProd = true}) {
  final expectedAddedScript = isProd ? rmuiBundleProd : rmuiBundleDev;
  final testSuggestor =
      getSuggestorTester(HtmlScriptAdder(expectedAddedScript, isProd));

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

  jsFileTypes.forEach((testName, scripts) {
    test(testName, () async {
      final isTestProd = testName.contains('Prod');
      await testSuggestor(
        expectedPatchCount: isProd == isTestProd ? 1 : 0,
        shouldDartfmtOutput: false,
        input: ''
            '${scripts.join('\n')}'
            '',
        expectedOutput: ''
            '${scripts.join('\n')}\n'
            '${isProd == isTestProd ? '$expectedAddedScript\n' : ''}'
            '',
      );
    });
  });

  test('with indentation', () async {
    await testSuggestor(
      expectedPatchCount: 1,
      shouldDartfmtOutput: false,
      input: ''
          '  ${(isProd ? prodReact : devReact).join('\n  ')}'
          '',
      expectedOutput: ''
          '  ${(isProd ? prodReact : devReact).join('\n  ')}\n'
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
          '    ${(isProd ? prodReact : devReact).join('\n    ')}\n'
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
          '    ${(isProd ? prodReact : devReact).join('\n    ')}\n'
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
    final anotherTestSuggestor =
        getSuggestorTester(HtmlScriptAdder(someOtherScript, isProd));

    await anotherTestSuggestor(
      expectedPatchCount: 1,
      shouldDartfmtOutput: false,
      input: ''
          '    ${(isProd ? prodReact : devReact).join('\n    ')}'
          '',
      expectedOutput: ''
          '    ${(isProd ? prodReact : devReact).join('\n    ')}\n'
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
          '    ${(isProd ? prodReact : devReact).join('\n    ')}\n'
          '',
    );
  });
}

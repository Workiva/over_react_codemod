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

main() {
  group('HtmlScriptAdder', () {
    final testSuggestor = getSuggestorTester(HtmlScriptAdder(rmuiBundleScript));

    test('empty file', () async {
      await testSuggestor(expectedPatchCount: 0, input: '');
    });

    test('no matches', () async {
      await testSuggestor(
        expectedPatchCount: 0,
        shouldDartfmtOutput: false,
        input: ''
            '<script src="/packages/react/react.js"></script>\n'
            '',
      );
    });

    test('no indentation', () async {
      await testSuggestor(
        expectedPatchCount: 1,
        shouldDartfmtOutput: false,
        input: ''
            '<script src="/packages/react/react_dom.js"></script>\n'
            '',
        expectedOutput: ''
            '<script src="/packages/react/react_dom.js"></script>\n'
            '$rmuiBundleScript\n'
            '',
      );
    });

    test('with some indentation', () async {
      await testSuggestor(
        expectedPatchCount: 1,
        shouldDartfmtOutput: false,
        input: ''
            '  <script src="/packages/react/react_with_addons.js"></script>\n'
            '',
        expectedOutput: ''
            '  <script src="/packages/react/react_with_addons.js"></script>\n'
            '  $rmuiBundleScript\n'
            '',
      );
    });

    test('with two react-dart js files', () async {
      await testSuggestor(
        expectedPatchCount: 1,
        shouldDartfmtOutput: false,
        input: ''
            '    <script src="/packages/react/react_with_addons.js"></script>\n'
            '    <script src="/packages/react/react_dom.js"></script>\n'
            '',
        expectedOutput: ''
            '    <script src="/packages/react/react_with_addons.js"></script>\n'
            '    $rmuiBundleScript\n'
            '    <script src="/packages/react/react_dom.js"></script>\n'
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
            '    <script src="packages/react/react_with_addons.js"></script>\n'
            '    <script src="packages/react/react_dom.js"></script>\n'
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
            '    <script src="packages/react/react_with_addons.js"></script>\n'
            '    $rmuiBundleScript\n'
            '    <script src="packages/react/react_dom.js"></script>\n'
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
          getSuggestorTester(HtmlScriptAdder(someOtherScript));

      await anotherTestSuggestor(
        expectedPatchCount: 1,
        shouldDartfmtOutput: false,
        input: ''
            '  <script src="/packages/react/react_with_addons.js"></script>\n'
            '',
        expectedOutput: ''
            '  <script src="/packages/react/react_with_addons.js"></script>\n'
            '  $someOtherScript\n'
            '',
      );
    });

    test('when the script already exists', () async {
      await testSuggestor(
        expectedPatchCount: 0,
        shouldDartfmtOutput: false,
        input: ''
            '  $rmuiBundleScript\n'
            '  <script src="/packages/react/react_with_addons.js"></script>\n'
            '',
      );
    });
  });
}

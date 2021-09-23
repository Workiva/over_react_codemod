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
  });
}

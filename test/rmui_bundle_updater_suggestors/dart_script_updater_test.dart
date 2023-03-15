// Copyright 2023 Workiva Inc.
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
import 'package:over_react_codemod/src/rmui_bundle_update_suggestors/constants.dart';
import 'package:over_react_codemod/src/rmui_bundle_update_suggestors/dart_script_updater.dart';
import 'package:test/test.dart';

import '../util.dart';

void main() {
  group('DartScriptAdder', () {
    // Test both suggestors together to:
    // 1. verify for all cases that the wrong bundle type isn't updated
    // 2. verify they work well together, since they'll never really be run individually
    final testSuggestor = getSuggestorTester(aggregate([
      DartScriptUpdater(rmuiBundleDev, rmuiBundleDevUpdated),
      DartScriptUpdater(rmuiBundleProd, rmuiBundleProdUpdated),
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

    test('dev bundle', () async {
      await testSuggestor(
        expectedPatchCount: 2,
        input: /*language=dart*/ '''
              List<String> _reactHtmlHeaders = const [
                '<script src="$rmuiBundleDev"></script>'
              ];
            ''',
        expectedOutput: /*language=dart*/ '''
              List<String> _reactHtmlHeaders = const [
                '<script src="$rmuiBundleDevUpdated" type="module"></script>'
              ];
            ''',
      );
    });

    test('prod bundle', () async {
      await testSuggestor(
        expectedPatchCount: 2,
        input: /*language=dart*/ '''
              List<String> _reactHtmlHeaders = const [
                '<script src="$rmuiBundleProd"></script>'
              ];
            ''',
        expectedOutput: /*language=dart*/ '''
              List<String> _reactHtmlHeaders = const [
                '<script src="$rmuiBundleProdUpdated" type="module"></script>'
              ];
            ''',
      );
    });

    test('will do nothing if the script is already correct', () async {
      await testSuggestor(
        expectedPatchCount: 0,
        shouldDartfmtOutput: false,
        input: /*language=dart*/ '''
            List<String> _reactHtmlHeaders = const [\n'
              \'<script src="$rmuiBundleDevUpdated" type="module"></script>\'\n'
              \'<script src="$rmuiBundleProdUpdated" type="module"></script>\'\n'
            ];\n''',
        expectedOutput: /*language=dart*/ '''
            List<String> _reactHtmlHeaders = const [\n'
              \'<script src="$rmuiBundleDevUpdated" type="module"></script>\'\n'
              \'<script src="$rmuiBundleProdUpdated" type="module"></script>\'\n'
            ];\n''',
      );
    });

    test('with indentation', () async {
      await testSuggestor(
        expectedPatchCount: 2,
        input: /*language=dart*/ '''
                List<String> _reactHtmlHeaders = const [
                '<script src="$rmuiBundleDev"></script>'
              ];
            ''',
        expectedOutput: /*language=dart*/ '''
              List<String> _reactHtmlHeaders = const [
                '<script src="$rmuiBundleDevUpdated" type="module"></script>'
              ];
            ''',
      );
    });

    test('in context with other HTML logic', () async {
      await testSuggestor(
        expectedPatchCount: 2,
        shouldDartfmtOutput: false,
        input: /*language=dart*/ '''
          List<String> _reactHtmlHeaders = const [
            '<!DOCTYPE html>'
            '<html>'
            '  <head>'
            '    <title>{{testName}}</title>'
            '    <!--my custom header-->'
            '    <script src="$rmuiBundleProd"></script>'
            '    <script src="packages/engine/gopherBindings.js"></script>'
            '    <!--In order to debug unit tests, use application/dart rather than x-dart-test-->'
            '    <script src="packages/react_testing_library/js/react-testing-library.js"></script>'
            '    {{testScript}}'
            '    <script src="packages/test/dart.js"></script>'
            '  </head>'
            '  <body></body>'
            '</html>'
          ];''',
        expectedOutput: /*language=dart*/ '''
          List<String> _reactHtmlHeaders = const [
            '<!DOCTYPE html>'
            '<html>'
            '  <head>'
            '    <title>{{testName}}</title>'
            '    <!--my custom header-->'
            '    <script src="$rmuiBundleProdUpdated" type="module"></script>'
            '    <script src="packages/engine/gopherBindings.js"></script>'
            '    <!--In order to debug unit tests, use application/dart rather than x-dart-test-->'
            '    <script src="packages/react_testing_library/js/react-testing-library.js"></script>'
            '    {{testScript}}'
            '    <script src="packages/test/dart.js"></script>'
            '  </head>'
            '  <body></body>'
            '</html>'
          ];\n''',
      );
    });

    test('with existing module attribute', () async {
      await testSuggestor(
        expectedPatchCount: 4,
        shouldDartfmtOutput: false,
        input: /*language=dart*/ '''
          List<String> _reactHtmlHeaders = const [
            '<script type="module" src="$rmuiBundleProd"></script>'
            '<script src="$rmuiBundleDev" type="module" ></script>'
            '<script src="$rmuiBundleDevUpdated"></script>'
            '<script src="$rmuiBundleProdUpdated"></script>'
          ];''',
        expectedOutput: /*language=dart*/ '''
          List<String> _reactHtmlHeaders = const [
            '<script type="module" src="$rmuiBundleProdUpdated"></script>'
            '<script src="$rmuiBundleDevUpdated" type="module" ></script>'
            '<script src="$rmuiBundleDevUpdated" type="module"></script>'
            '<script src="$rmuiBundleProdUpdated" type="module"></script>'
          ];\n''',
      );
    });

    test('will update an existing type attribute', () async {
      await testSuggestor(
        expectedPatchCount: 4,
        shouldDartfmtOutput: false,
        input: /*language=dart*/ '''
          List<String> _reactHtmlHeaders = const [
            '<script src="$rmuiBundleDev" type="js/slk-f.sdkf"></script>'
            '<script src="$rmuiBundleProd" type="js/slkfsdkf"></script>'
          ];''',
        expectedOutput: /*language=dart*/ '''
          List<String> _reactHtmlHeaders = const [
            '<script src="$rmuiBundleDevUpdated" type="module"></script>'
            '<script src="$rmuiBundleProdUpdated" type="module"></script>'
          ];\n''',
      );
    });
  });
}

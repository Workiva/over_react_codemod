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
import 'package:over_react_codemod/src/rmui_bundle_update_suggestors/html_script_updater.dart';
import 'package:test/test.dart';

import '../util.dart';

void main() {
  group('HtmlScriptUpdater', () {
    final testSuggestor = getSuggestorTester(aggregate([
      HtmlScriptUpdater(rmuiBundleDev, rmuiBundleDevUpdated),
      HtmlScriptUpdater(rmuiBundleProd, rmuiBundleProdUpdated),
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

    test('dev bundle', () async {
      await testSuggestor(
        expectedPatchCount: 2,
        shouldDartfmtOutput: false,
        input: ''
            '<script src="packages/react_material_ui/react-material-ui-development.umd.js"></script>\n'
            '',
        expectedOutput: ''
            '<script src="packages/react_material_ui/js/react-material-ui.browser.dev.esm.js" type="module"></script>\n'
            '',
      );
    });

    test('prod bundle', () async {
      await testSuggestor(
        expectedPatchCount: 2,
        shouldDartfmtOutput: false,
        input: ''
            '<script src="packages/react_material_ui/react-material-ui.umd.js"></script>\n'
            '',
        expectedOutput: ''
            '<script src="packages/react_material_ui/js/react-material-ui.browser.min.esm.js" type="module"></script>\n'
            '',
      );
    });

    test('will do nothing if the script is already correct', () async {
      await testSuggestor(
        expectedPatchCount: 0,
        shouldDartfmtOutput: false,
        input: ''
            '<script src="packages/react_material_ui/js/react-material-ui.browser.dev.esm.js" type="module"></script>\n'
            '<script src="packages/react_material_ui/js/react-material-ui.browser.min.esm.js" type="module"></script>\n'
            '',
        expectedOutput: ''
            '<script src="packages/react_material_ui/js/react-material-ui.browser.dev.esm.js" type="module"></script>\n'
            '<script src="packages/react_material_ui/js/react-material-ui.browser.min.esm.js" type="module"></script>\n'
            '',
      );
    });

    test('with indentation', () async {
      await testSuggestor(
        expectedPatchCount: 2,
        shouldDartfmtOutput: false,
        input: ''
            '  <script src="packages/react_material_ui/react-material-ui-development.umd.js"></script>\n'
            '',
        expectedOutput: ''
            '  <script src="packages/react_material_ui/js/react-material-ui.browser.dev.esm.js" type="module"></script>\n'
            '',
      );
    });

    test('in context with other HTML logic', () async {
      await testSuggestor(
        expectedPatchCount: 2,
        shouldDartfmtOutput: false,
        input: ''
            '<!DOCTYPE html>\n'
            '<html>\n'
            '  <head>\n'
            '    <title>{{testName}}</title>\n'
            '    <!--my custom header-->\n'
            '    <script src="packages/react_material_ui/react-material-ui.umd.js"></script>\n'
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
            '    <script src="packages/react_material_ui/js/react-material-ui.browser.min.esm.js" type="module"></script>\n'
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

    test('with existing module attribute', () async {
      await testSuggestor(
        expectedPatchCount: 4,
        shouldDartfmtOutput: false,
        input: ''
            '<script type="module" src="packages/react_material_ui/react-material-ui.umd.js"></script>\n'
            '<script src="packages/react_material_ui/react-material-ui-development.umd.js" type="module" ></script>\n'
            '<script src="packages/react_material_ui/js/react-material-ui.browser.dev.esm.js"></script>\n'
            '<script src="packages/react_material_ui/js/react-material-ui.browser.min.esm.js"></script>\n'
            '',
        expectedOutput: ''
            '<script type="module" src="packages/react_material_ui/js/react-material-ui.browser.min.esm.js"></script>\n'
            '<script src="packages/react_material_ui/js/react-material-ui.browser.dev.esm.js" type="module" ></script>\n'
            '<script src="packages/react_material_ui/js/react-material-ui.browser.dev.esm.js" type="module"></script>\n'
            '<script src="packages/react_material_ui/js/react-material-ui.browser.min.esm.js" type="module"></script>\n'
            '',
      );
    });

    test('will update an existing type attribute', () async {
      await testSuggestor(
        expectedPatchCount: 4,
        shouldDartfmtOutput: false,
        input: ''
            '<script src="packages/react_material_ui/react-material-ui-development.umd.js" type="js/slk-f.sdkf"></script>\n'
            '<script src="packages/react_material_ui/react-material-ui.umd.js" type="js/slkfsdkf"></script>\n'
            '',
        expectedOutput: ''
            '<script src="packages/react_material_ui/js/react-material-ui.browser.dev.esm.js" type="module"></script>\n'
            '<script src="packages/react_material_ui/js/react-material-ui.browser.min.esm.js" type="module"></script>\n'
            '',
      );
    });
  });
}

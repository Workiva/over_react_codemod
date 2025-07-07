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
        expectedPatchCount: 4,
        shouldDartfmtOutput: false,
        input: ''
            '<script src="$rmuiBundleDev"></script>\n'
            '<link rel="preload" href="$rmuiBundleDev" as="script">\n'
            '',
        expectedOutput: ''
            '<script src="$rmuiBundleDevUpdated" type="module"></script>\n'
            '<link rel="preload" href="$rmuiBundleDevUpdated" crossorigin="" as="script">\n'
            '',
      );
    });

    test('prod bundle', () async {
      await testSuggestor(
        expectedPatchCount: 4,
        shouldDartfmtOutput: false,
        input: ''
            '<script src="$rmuiBundleProd"></script>\n'
            '<link rel="preload" href="$rmuiBundleProd" as="script">\n'
            '',
        expectedOutput: ''
            '<script src="$rmuiBundleProdUpdated" type="module"></script>\n'
            '<link rel="preload" href="$rmuiBundleProdUpdated" crossorigin="" as="script">\n'
            '',
      );
    });

    test('will do nothing if the script is already correct', () async {
      await testSuggestor(
        expectedPatchCount: 0,
        shouldDartfmtOutput: false,
        input: ''
            '<script src="$rmuiBundleDevUpdated" type="module"></script>\n'
            '<link rel="preload" href="$rmuiBundleDevUpdated" crossorigin="" as="script">\n'
            '<script src="$rmuiBundleProdUpdated" type="module"></script>\n'
            '<link rel="preload" href="$rmuiBundleProdUpdated" crossorigin="" as="script">\n'
            '',
        expectedOutput: ''
            '<script src="$rmuiBundleDevUpdated" type="module"></script>\n'
            '<link rel="preload" href="$rmuiBundleDevUpdated" crossorigin="" as="script">\n'
            '<script src="$rmuiBundleProdUpdated" type="module"></script>\n'
            '<link rel="preload" href="$rmuiBundleProdUpdated" crossorigin="" as="script">\n'
            '',
      );
    });

    test('with indentation', () async {
      await testSuggestor(
        expectedPatchCount: 4,
        shouldDartfmtOutput: false,
        input: ''
            '  <script src="$rmuiBundleDev"></script>\n'
            '  <link rel="preload" href="$rmuiBundleDev" as="script">\n'
            '',
        expectedOutput: ''
            '  <script src="$rmuiBundleDevUpdated" type="module"></script>\n'
            '  <link rel="preload" href="$rmuiBundleDevUpdated" crossorigin="" as="script">\n'
            '',
      );
    });

    test('in context with other HTML logic', () async {
      await testSuggestor(
        expectedPatchCount: 4,
        shouldDartfmtOutput: false,
        input: ''
            '<!DOCTYPE html>\n'
            '<html>\n'
            '  <head>\n'
            '    <base href="/">\n'
            '    \n'
            '    <!-- MUST BE THE FIRST META TAG WITHIN <HEAD> -->\n'
            '    <meta http-equiv="X-UA-Compatible" content="IE=edge">\n'
            '    <meta charset="UTF-8">\n'
            '    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">\n'
            '    <meta name="apple-mobile-web-app-capable" content="yes">\n'
            '    <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent" />\n'
            '    <meta name="google" content="notranslate" />\n'
            '    \n'
            '    <title>Wdesk</title>\n'
            '    \n'
            '    <!-- Preconnects -->\n'
            '    <link rel="preconnect" href="https://sandbox.wdesk.com">\n'
            '    \n'
            '    <!-- PRELOAD SCRIPTS -->\n'
            '    <link rel="preload" href="packages/react/react_with_react_dom_prod.js" as="script">\n'
            '    <link rel="preload" href="$rmuiBundleProd" as="script">\n'
            '    <link rel="preload" href="main.dart.js" as="script">\n'
            '    \n'
            '    <!-- STYLESHEETS -->\n'
            '    <link rel="stylesheet" href="packages/web_skin/dist/css/web-skin.min.css">\n'
            '  </head>\n'
            '  \n'
            '  <body>\n'
            '    <!-- App Container -->\n'
            '    <div id="shell-container" aria-hidden="true" tabindex="-1"></div>\n'
            '    \n'
            '    <!-- SCRIPTS -->\n'
            '    <script src="packages/react/react_with_react_dom_prod.js"></script>\n'
            '    <script src="$rmuiBundleProd"></script>\n'
            '    <script defer src="main.dart.js"></script>\n'
            '  </body>\n'
            '</html>\n'
            '',
        expectedOutput: ''
            '<!DOCTYPE html>\n'
            '<html>\n'
            '  <head>\n'
            '    <base href="/">\n'
            '    \n'
            '    <!-- MUST BE THE FIRST META TAG WITHIN <HEAD> -->\n'
            '    <meta http-equiv="X-UA-Compatible" content="IE=edge">\n'
            '    <meta charset="UTF-8">\n'
            '    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">\n'
            '    <meta name="apple-mobile-web-app-capable" content="yes">\n'
            '    <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent" />\n'
            '    <meta name="google" content="notranslate" />\n'
            '    \n'
            '    <title>Wdesk</title>\n'
            '    \n'
            '    <!-- Preconnects -->\n'
            '    <link rel="preconnect" href="https://sandbox.wdesk.com">\n'
            '    \n'
            '    <!-- PRELOAD SCRIPTS -->\n'
            '    <link rel="preload" href="packages/react/react_with_react_dom_prod.js" as="script">\n'
            '    <link rel="preload" href="$rmuiBundleProdUpdated" crossorigin="" as="script">\n'
            '    <link rel="preload" href="main.dart.js" as="script">\n'
            '    \n'
            '    <!-- STYLESHEETS -->\n'
            '    <link rel="stylesheet" href="packages/web_skin/dist/css/web-skin.min.css">\n'
            '  </head>\n'
            '  \n'
            '  <body>\n'
            '    <!-- App Container -->\n'
            '    <div id="shell-container" aria-hidden="true" tabindex="-1"></div>\n'
            '    \n'
            '    <!-- SCRIPTS -->\n'
            '    <script src="packages/react/react_with_react_dom_prod.js"></script>\n'
            '    <script src="$rmuiBundleProdUpdated" type="module"></script>\n'
            '    <script defer src="main.dart.js"></script>\n'
            '  </body>\n'
            '</html>\n'
            '',
      );
    });

    test('with existing module and crossorigin attributes', () async {
      await testSuggestor(
        expectedPatchCount: 8,
        shouldDartfmtOutput: false,
        input: ''
            '<script type="module" src="$rmuiBundleProd"></script>\n'
            '<link crossorigin="" rel="preload" href="$rmuiBundleProd" as="script">\n'
            '<script src="$rmuiBundleDev" type="module" ></script>\n'
            '<link rel="preload" href="$rmuiBundleDev" crossorigin="" as="script">\n'
            '<script src="$rmuiBundleDevUpdated"></script>\n'
            '<link rel="preload" href="$rmuiBundleDevUpdated" as="script">\n'
            '<script src="$rmuiBundleProdUpdated"></script>\n'
            '<link rel="preload" href="$rmuiBundleProdUpdated" as="script">\n'
            '',
        expectedOutput: ''
            '<script type="module" src="$rmuiBundleProdUpdated"></script>\n'
            '<link crossorigin="" rel="preload" href="$rmuiBundleProdUpdated" as="script">\n'
            '<script src="$rmuiBundleDevUpdated" type="module" ></script>\n'
            '<link rel="preload" href="$rmuiBundleDevUpdated" crossorigin="" as="script">\n'
            '<script src="$rmuiBundleDevUpdated" type="module"></script>\n'
            '<link rel="preload" href="$rmuiBundleDevUpdated" crossorigin="" as="script">\n'
            '<script src="$rmuiBundleProdUpdated" type="module"></script>\n'
            '<link rel="preload" href="$rmuiBundleProdUpdated" crossorigin="" as="script">\n'
            '',
      );
    });

    test('will update an existing type or crossorigin attribute', () async {
      await testSuggestor(
        expectedPatchCount: 8,
        shouldDartfmtOutput: false,
        input: ''
            '<script src="$rmuiBundleDev" type="js/slk-f.sdkf"></script>\n'
            '<link rel="preload" href="$rmuiBundleDev" crossorigin="sadfsafdsa" as="script">\n'
            '<script src="$rmuiBundleProd" type="js/slkfsdkf"></script>\n'
            '<link rel="preload" href="$rmuiBundleProd" crossorigin="saf/asdf/sa" as="script">\n'
            '',
        expectedOutput: ''
            '<script src="$rmuiBundleDevUpdated" type="module"></script>\n'
            '<link rel="preload" href="$rmuiBundleDevUpdated" crossorigin="" as="script">\n'
            '<script src="$rmuiBundleProdUpdated" type="module"></script>\n'
            '<link rel="preload" href="$rmuiBundleProdUpdated" crossorigin="" as="script">\n'
            '',
      );
    });

    test('just script tags', () async {
      await testSuggestor(
        expectedPatchCount: 4,
        shouldDartfmtOutput: false,
        input: ''
            '<script src="/directory/$rmuiBundleDev"></script>\n'
            '<script src="$rmuiBundleProd"></script>\n'
            '',
        expectedOutput: ''
            '<script src="/directory/$rmuiBundleDevUpdated" type="module"></script>\n'
            '<script src="$rmuiBundleProdUpdated" type="module"></script>\n'
            '',
      );
    });

    test('just link tags', () async {
      await testSuggestor(
        expectedPatchCount: 4,
        shouldDartfmtOutput: false,
        input: ''
            '<link rel="preload" href="$rmuiBundleDev" as="script">\n'
            '<link rel="preload" href="$rmuiBundleProd" as="script">\n'
            '',
        expectedOutput: ''
            '<link rel="preload" href="$rmuiBundleDevUpdated" crossorigin="" as="script">\n'
            '<link rel="preload" href="$rmuiBundleProdUpdated" crossorigin="" as="script">\n'
            '',
      );
    });

    test('removeTag arg', () async {
      final removeTagSuggestor =
          getSuggestorTester(HtmlScriptUpdater.remove(rmuiBundleDev));

      await removeTagSuggestor(
        expectedPatchCount: 4,
        shouldDartfmtOutput: false,
        input: ''
            '<script src="$rmuiBundleDev"></script>\n'
            '<script src="/something_else/$rmuiBundleDev"></script>\n'
            '<link rel="preload" href="$rmuiBundleDev" as="script">\n'
            '<link rel="preload" href="${rmuiBundleDev}abc" as="script">\n'
            '<script src="$rmuiBundleDevUpdated" type="module"></script>\n'
            '<script src="${rmuiBundleDevUpdated}abc" type="module"></script>\n'
            '<link rel="preload" href="$rmuiBundleDev" crossorigin="" as="script">\n'
            '',
        expectedOutput: '\n\n\n'
            '<link rel="preload" href="${rmuiBundleDev}abc" as="script">\n'
            '<script src="$rmuiBundleDevUpdated" type="module"></script>\n'
            '<script src="${rmuiBundleDevUpdated}abc" type="module"></script>\n'
            '',
      );
    });
  });
}

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
        expectedPatchCount: 4,
        input: '''
              List<String> _reactHtmlHeaders = const [
                '<script src="$rmuiBundleDev"></script>',
                '<link rel="preload" href="$rmuiBundleDev" as="script">',
              ];
            ''',
        expectedOutput: '''
              List<String> _reactHtmlHeaders = const [
                '<script src="$rmuiBundleDevUpdated" type="module"></script>',
                '<link rel="preload" href="$rmuiBundleDevUpdated" crossorigin="" as="script">',
              ];
            ''',
      );
    });

    test('prod bundle', () async {
      await testSuggestor(
        expectedPatchCount: 4,
        input: '''
              List<String> _reactHtmlHeaders = const [
                '<script src="$rmuiBundleProd"></script>',
                '<link rel="preload" href="$rmuiBundleProd" as="script">',
              ];
            ''',
        expectedOutput: '''
              List<String> _reactHtmlHeaders = const [
                '<script src="$rmuiBundleProdUpdated" type="module"></script>',
                '<link rel="preload" href="$rmuiBundleProdUpdated" crossorigin="" as="script">',
              ];
            ''',
      );
    });

    test('will do nothing if the script is already correct', () async {
      await testSuggestor(
        expectedPatchCount: 0,
        shouldDartfmtOutput: false,
        input: '''
            List<String> _reactHtmlHeaders = const [
              '<script src="$rmuiBundleDevUpdated" type="module"></script>',
              '<link rel="preload" href="$rmuiBundleDevUpdated" crossorigin="" as="script">',
              '<script src="$rmuiBundleProdUpdated" type="module"></script>',
              '<link rel="preload" href="$rmuiBundleProdUpdated" crossorigin="" as="script">',
            ];\n''',
        expectedOutput: '''
            List<String> _reactHtmlHeaders = const [
              '<script src="$rmuiBundleDevUpdated" type="module"></script>',
              '<link rel="preload" href="$rmuiBundleDevUpdated" crossorigin="" as="script">',
              '<script src="$rmuiBundleProdUpdated" type="module"></script>',
              '<link rel="preload" href="$rmuiBundleProdUpdated" crossorigin="" as="script">',
            ];\n''',
      );
    });

    test('with indentation', () async {
      await testSuggestor(
        expectedPatchCount: 4,
        input: '''
                List<String> _reactHtmlHeaders = const [
                '  <script src="$rmuiBundleDev"></script>',
                '  <link rel="preload" href="$rmuiBundleDev" as="script">',
              ];
            ''',
        expectedOutput: '''
              List<String> _reactHtmlHeaders = const [
                '  <script src="$rmuiBundleDevUpdated" type="module"></script>',
                '  <link rel="preload" href="$rmuiBundleDevUpdated" crossorigin="" as="script">',
              ];
            ''',
      );
    });

    test('in context with other HTML logic', () async {
      await testSuggestor(
        expectedPatchCount: 4,
        shouldDartfmtOutput: false,
        input: '''
          List<String> _reactHtmlHeaders = const [
            '<!DOCTYPE html>',
            '<html>',
            '  <head>',
            '    <base href="/">',
            '    ',
            '    <meta http-equiv="X-UA-Compatible" content="IE=edge">',
            '    <meta charset="UTF-8">',
            '    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">',
            '    <meta name="apple-mobile-web-app-capable" content="yes">',
            '    <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent" />',
            '    <meta name="google" content="notranslate" />',
            '    ',
            '    <title>Wdesk</title>',
            '    ',
            '    <!-- Preconnects -->',
            '    <link rel="preconnect" href="https://sandbox.wdesk.com">',
            '    ',
            '    <!-- PRELOAD SCRIPTS -->',
            '    <link rel="preload" href="packages/react/react_with_react_dom_prod.js" as="script">',
            '    <link rel="preload" href="$rmuiBundleProd" as="script">',
            '    <link rel="preload" href="main.dart.js" as="script">',
            '    ',
            '    <!-- STYLESHEETS -->',
            '    <link rel="stylesheet" href="packages/web_skin/dist/css/web-skin.min.css">',
            '  </head>',
            '  ',
            '  <body>',
            '    <!-- App Container -->',
            '    <div id="shell-container" aria-hidden="true" tabindex="-1"></div>',
            '    ',
            '    <!-- SCRIPTS -->',
            '    <script src="packages/react/react_with_react_dom_prod.js"></script>',
            '    <script src="$rmuiBundleProd"></script>',
            '    <script defer src="main.dart.js"></script>',
            '  </body>',
            '</html>',
          ];''',
        expectedOutput: '''
          List<String> _reactHtmlHeaders = const [
            '<!DOCTYPE html>',
            '<html>',
            '  <head>',
            '    <base href="/">',
            '    ',
            '    <meta http-equiv="X-UA-Compatible" content="IE=edge">',
            '    <meta charset="UTF-8">',
            '    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">',
            '    <meta name="apple-mobile-web-app-capable" content="yes">',
            '    <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent" />',
            '    <meta name="google" content="notranslate" />',
            '    ',
            '    <title>Wdesk</title>',
            '    ',
            '    <!-- Preconnects -->',
            '    <link rel="preconnect" href="https://sandbox.wdesk.com">',
            '    ',
            '    <!-- PRELOAD SCRIPTS -->',
            '    <link rel="preload" href="packages/react/react_with_react_dom_prod.js" as="script">',
            '    <link rel="preload" href="$rmuiBundleProdUpdated" crossorigin="" as="script">',
            '    <link rel="preload" href="main.dart.js" as="script">',
            '    ',
            '    <!-- STYLESHEETS -->',
            '    <link rel="stylesheet" href="packages/web_skin/dist/css/web-skin.min.css">',
            '  </head>',
            '  ',
            '  <body>',
            '    <!-- App Container -->',
            '    <div id="shell-container" aria-hidden="true" tabindex="-1"></div>',
            '    ',
            '    <!-- SCRIPTS -->',
            '    <script src="packages/react/react_with_react_dom_prod.js"></script>',
            '    <script src="$rmuiBundleProdUpdated" type="module"></script>',
            '    <script defer src="main.dart.js"></script>',
            '  </body>',
            '</html>',
          ];\n''',
      );
    });

    test('with existing module or crossorigin attribute', () async {
      await testSuggestor(
        expectedPatchCount: 8,
        shouldDartfmtOutput: false,
        input: '''
          List<String> _reactHtmlHeaders = const [
            '<script type="module" src="$rmuiBundleProd"></script>',
            '<link crossorigin="" rel="preload" href="$rmuiBundleProd" as="script">',
            '<script src="$rmuiBundleDev" type="module" ></script>',
            '<link rel="preload" href="$rmuiBundleDev" crossorigin="" as="script">',
            '<script src="$rmuiBundleDevUpdated"></script>',
            '<link rel="preload" href="$rmuiBundleDevUpdated" as="script">',
            '<script src="$rmuiBundleProdUpdated"></script>',
            '<link rel="preload" href="$rmuiBundleProdUpdated" as="script">',
          ];''',
        expectedOutput: '''
          List<String> _reactHtmlHeaders = const [
            '<script type="module" src="$rmuiBundleProdUpdated"></script>',
            '<link crossorigin="" rel="preload" href="$rmuiBundleProdUpdated" as="script">',
            '<script src="$rmuiBundleDevUpdated" type="module" ></script>',
            '<link rel="preload" href="$rmuiBundleDevUpdated" crossorigin="" as="script">',
            '<script src="$rmuiBundleDevUpdated" type="module"></script>',
            '<link rel="preload" href="$rmuiBundleDevUpdated" crossorigin="" as="script">',
            '<script src="$rmuiBundleProdUpdated" type="module"></script>',
            '<link rel="preload" href="$rmuiBundleProdUpdated" crossorigin="" as="script">',
          ];\n''',
      );
    });

    test('will update an existing type and crossorigin attributes', () async {
      await testSuggestor(
        expectedPatchCount: 8,
        shouldDartfmtOutput: false,
        input: '''
          List<String> _reactHtmlHeaders = const [
            '<script src="$rmuiBundleDev" type="js/slk-f.sdkf"></script>',
            '<link rel="preload" href="$rmuiBundleDev" crossorigin="asdfsafdsf" as="script">',
            '<script src="$rmuiBundleProd" type="js/slkfsdkf"></script>',
            '<link rel="preload" href="$rmuiBundleProd" crossorigin="sadfsa/asdf" as="script">',
          ];''',
        expectedOutput: '''
          List<String> _reactHtmlHeaders = const [
            '<script src="$rmuiBundleDevUpdated" type="module"></script>',
            '<link rel="preload" href="$rmuiBundleDevUpdated" crossorigin="" as="script">',
            '<script src="$rmuiBundleProdUpdated" type="module"></script>',
            '<link rel="preload" href="$rmuiBundleProdUpdated" crossorigin="" as="script">',
          ];\n''',
      );
    });

    test('just script tags', () async {
      await testSuggestor(
        expectedPatchCount: 4,
        input: '''
              List<String> _reactHtmlHeaders = const [
                '<script src="$rmuiBundleDev"></script>',
                '<script src="$rmuiBundleProd"></script>',
              ];
            ''',
        expectedOutput: '''
              List<String> _reactHtmlHeaders = const [
                '<script src="$rmuiBundleDevUpdated" type="module"></script>',
                '<script src="$rmuiBundleProdUpdated" type="module"></script>',
              ];
            ''',
      );
    });

    test('just link tags', () async {
      await testSuggestor(
        expectedPatchCount: 4,
        input: '''
              List<String> _reactHtmlHeaders = const [
                '<link rel="preload" href="$rmuiBundleDev" as="script">',
                '<link rel="preload" href="$rmuiBundleProd" as="script">',
              ];
            ''',
        expectedOutput: '''
              List<String> _reactHtmlHeaders = const [
                '<link rel="preload" href="$rmuiBundleDevUpdated" crossorigin="" as="script">',
                '<link rel="preload" href="$rmuiBundleProdUpdated" crossorigin="" as="script">',
              ];
            ''',
      );
    });

    test('string const', () async {
      await testSuggestor(
        expectedPatchCount: 2,
        input: '''
          const expectedWithReact = \'\'\'
            <!DOCTYPE html>
            <html>
            <head>
            <title>{{testName}}</title>
            <script src="packages/react/react_with_addons.js"></script>
            <script src="packages/react/react_dom.js"></script>
            <script src="$rmuiBundleDev"></script>
            <script src="packages/react_testing_library/js/react-testing-library.js"></script>
            <!--In order to debug unit tests, use application/dart rather than x-dart-test-->
            <!--<script type="application/dart" src="generated_runner_test.dart"></script>-->
              {{testScript}}
              <script src="packages/test/dart.js"></script>
            </head>
            <body></body>
            </html>
          \'\'\';
        ''',
        expectedOutput: '''
          const expectedWithReact = \'\'\'
            <!DOCTYPE html>
            <html>
            <head>
            <title>{{testName}}</title>
            <script src="packages/react/react_with_addons.js"></script>
            <script src="packages/react/react_dom.js"></script>
            <script src="$rmuiBundleDevUpdated" type="module"></script>
            <script src="packages/react_testing_library/js/react-testing-library.js"></script>
            <!--In order to debug unit tests, use application/dart rather than x-dart-test-->
            <!--<script type="application/dart" src="generated_runner_test.dart"></script>-->
              {{testScript}}
              <script src="packages/test/dart.js"></script>
            </head>
            <body></body>
            </html>
          \'\'\';
        ''',
      );
    });

    test('updateAttributes arg', () async {
      final updateSuggestor = getSuggestorTester(
        DartScriptUpdater(rmuiBundleDev, rmuiBundleDevUpdated,
            updateAttributes: false),
      );

      await updateSuggestor(
        expectedPatchCount: 2,
        input: '''
              List<String> _reactHtmlHeaders = const [
                '<script src="$rmuiBundleDev"></script>',
                '<link rel="preload" href="$rmuiBundleDev" as="script">',
              ];
            ''',
        expectedOutput: '''
              List<String> _reactHtmlHeaders = const [
                '<script src="$rmuiBundleDevUpdated"></script>',
                '<link rel="preload" href="$rmuiBundleDevUpdated" as="script">',
              ];
            ''',
      );
    });

    group('remove constructor', () {
      final removeTagSuggestor =
          getSuggestorTester(DartScriptUpdater.remove(rmuiBundleDev));

      test('list', () async {
        await removeTagSuggestor(
          expectedPatchCount: 3,
          input: '''
              List<String> _reactHtmlHeaders = const [
                '<script src="$rmuiBundleDev"></script>',
                '<link rel="preload" href="$rmuiBundleDev" as="script">',
                '<link rel="preload" href="/package/$rmuiBundleDev" as="script">',
                '<script src="$rmuiBundleDevUpdated" type="module"></script>',
                '<link rel="preload" href="$rmuiBundleDevUpdated" crossorigin="" as="script">',
              ];
            ''',
          expectedOutput: '''
              List<String> _reactHtmlHeaders = const [
                '<script src="$rmuiBundleDevUpdated" type="module"></script>',
                '<link rel="preload" href="$rmuiBundleDevUpdated" crossorigin="" as="script">',
              ];
            ''',
        );
      });

      test('string const', () async {
        await removeTagSuggestor(
          expectedPatchCount: 1,
          input: '''
          const expectedWithReact = \'\'\'
            <!DOCTYPE html>
            <html>
            <head>
            <title>{{testName}}</title>
            <script src="packages/react/react_with_addons.js"></script>
            <script src="packages/react/react_dom.js"></script>
            <script src="$rmuiBundleDev"></script>
            <script src="packages/react_testing_library/js/react-testing-library.js"></script>
            <!--In order to debug unit tests, use application/dart rather than x-dart-test-->
            <!--<script type="application/dart" src="generated_runner_test.dart"></script>-->
              {{testScript}}
              <script src="packages/test/dart.js"></script>
            </head>
            <body></body>
            </html>
          \'\'\';
        ''',
          expectedOutput: '''
          const expectedWithReact = \'\'\'
            <!DOCTYPE html>
            <html>
            <head>
            <title>{{testName}}</title>
            <script src="packages/react/react_with_addons.js"></script>
            <script src="packages/react/react_dom.js"></script>
            <script src="packages/react_testing_library/js/react-testing-library.js"></script>
            <!--In order to debug unit tests, use application/dart rather than x-dart-test-->
            <!--<script type="application/dart" src="generated_runner_test.dart"></script>-->
              {{testScript}}
              <script src="packages/test/dart.js"></script>
            </head>
            <body></body>
            </html>
          \'\'\';
        ''',
        );
      });
    });
  });
}

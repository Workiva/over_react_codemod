// Copyright 2025 Workiva Inc.
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

import 'package:over_react_codemod/src/util/package_util.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'mui_migration_test.dart';

void main() {
  group('react_18_upgrade executable', () {
    final react18CodemodScript =
        p.join(findPackageRootFor(p.current), 'bin/react_18_upgrade.dart');

    group('updates script tags', () {
      testCodemod('dev',
          script: react18CodemodScript,
          input: d.dir('project', [
            d.file('dev.html', /*language=html*/ '''
<script src="packages/react/react.js"></script>
        <script src="packages/react/react_dom.js"></script>'''),
            d.file('dev_with_addons.html', /*language=html*/ '''
<script src="packages/react/react_with_addons.js"></script>
        <script src="packages/react/react_dom.js"></script>'''),
          ]),
          expectedOutput: d.dir('project', [
            d.file('dev.html', /*language=html*/ '''
<script src="packages/react/js/react.dev.js"></script>
'''),
            d.file('dev_with_addons.html', /*language=html*/ '''
<script src="packages/react/js/react.dev.js"></script>
'''),
          ]),
          args: ['--yes-to-all']);

      testCodemod('prod',
          script: react18CodemodScript,
          input: d.dir('project', [
            d.file('prod.html', /*language=html*/ '''
<script src="packages/react/react_prod.js"></script>
        <script src="packages/react/react_dom_prod.js"></script>'''),
            d.file('prod_with_addons.html', /*language=html*/ '''
<script src="packages/react/react_with_react_dom_prod.js"></script>
        <script src="packages/react/react_dom_prod.js"></script>''')
          ]),
          expectedOutput: d.dir('project', [
            d.file('prod.html', /*language=html*/ '''
<script src="packages/react/js/react.min.js"></script>
'''),
            d.file('prod_with_addons.html', /*language=html*/ '''
<script src="packages/react/js/react.min.js"></script>
''')
          ]),
          args: ['--yes-to-all']);
    });

    group('updates link tags', () {
      testCodemod('dev',
          script: react18CodemodScript,
          input: d.dir('project', [
            d.file('dev.html', /*language=html*/ '''
<link href="packages/react/react.js">
        <link href="packages/react/react_dom.js">'''),
            d.file('dev_with_addons.html', /*language=html*/ '''
<link href="packages/react/react_with_addons.js">
        <link href="packages/react/react_dom.js">'''),
          ]),
          expectedOutput: d.dir('project', [
            d.file('dev.html', /*language=html*/ '''
<link href="packages/react/js/react.dev.js">
'''),
            d.file('dev_with_addons.html', /*language=html*/ '''
<link href="packages/react/js/react.dev.js">
'''),
          ]),
          args: ['--yes-to-all']);

      testCodemod('prod',
          script: react18CodemodScript,
          input: d.dir('project', [
            d.file('prod.html', /*language=html*/ '''
<link href="packages/react/react_prod.js">
        <link href="packages/react/react_dom_prod.js">'''),
            d.file('prod_with_addons.html', /*language=html*/ '''
<link href="packages/react/react_with_react_dom_prod.js">
        <link href="packages/react/react_dom_prod.js">''')
          ]),
          expectedOutput: d.dir('project', [
            d.file('prod.html', /*language=html*/ '''
<link href="packages/react/js/react.min.js">
'''),
            d.file('prod_with_addons.html', /*language=html*/ '''
<link href="packages/react/js/react.min.js">
''')
          ]),
          args: ['--yes-to-all']);
    });

    group('in Dart files', () {
      testCodemod('list',
          script: react18CodemodScript,
          input: d.dir('project', [
            d.file('main.dart', /*language=dart*/ '''
              List<String> _reactHtmlHeaders = const [
                '<script src="packages/react/react.js"></script>',
                '<script src="packages/react/react_dom.js"></script>',
                '<link rel="preload" href="packages/react/react.js" as="script">',
                '<link rel="preload" href="packages/react/react_dom.js" as="script">',
              ];
            ''')
          ]),
          expectedOutput: d.dir('project', [
            d.file('main.dart', /*language=dart*/ '''
              List<String> _reactHtmlHeaders = const [
                '<script src="packages/react/js/react.dev.js"></script>',
                '<link rel="preload" href="packages/react/js/react.dev.js" as="script">',
              ];
            ''')
          ]),
          args: ['--yes-to-all']);

      testCodemod('string const',
          script: react18CodemodScript,
          input: d.dir('project', [
            d.file('main.dart', '''
              const expectedWithReact = \'\'\'
                <!DOCTYPE html>
                <html>
                <head>
                <title>{{testName}}</title>
                <script src="packages/react/react_with_addons.js"></script>
                <script src="packages/react/react_dom.js"></script>
                <script src="packages/unify_ui/js/unify-ui.browser.dev.esm.js" type="module"></script>
                <script src="packages/react_testing_library/js/react-testing-library.js"></script>
                <!--In order to debug unit tests, use application/dart rather than x-dart-test-->
                <!--<script type="application/dart" src="generated_runner_test.dart"></script>-->
                {{testScript}}
                <script src="packages/test/dart.js"></script>
                </head>
                <body></body>
                </html>
              \'\'\';
            ''')
          ]),
          expectedOutput: d.dir('project', [
            d.file('main.dart', '''
              const expectedWithReact = \'\'\'
                <!DOCTYPE html>
                <html>
                <head>
                <title>{{testName}}</title>
                <script src="packages/react/js/react.dev.js"></script>
                <script src="packages/unify_ui/js/unify-ui.browser.dev.esm.js" type="module"></script>
                <script src="packages/react_testing_library/js/react-testing-library.js"></script>
                <!--In order to debug unit tests, use application/dart rather than x-dart-test-->
                <!--<script type="application/dart" src="generated_runner_test.dart"></script>-->
                {{testScript}}
                <script src="packages/test/dart.js"></script>
                </head>
                <body></body>
                </html>
              \'\'\';
            ''')
          ]),
          args: ['--yes-to-all']);
    });

    testCodemod('--fail-on-changes exits with 0 when no changes needed',
        script: react18CodemodScript,
        input: d.dir('project', [
          d.file('dev.html', /*language=html*/ '''
<script src="packages/react/js/react.dev.js"></script>'''),
          d.file('dev_with_addons.html', /*language=html*/ '''
<script src="packages/react/js/react.dev.js"></script>'''),
          d.file('prod.html', /*language=html*/ '''
<script src="packages/react/js/react.min.js"></script>'''),
          d.file('prod_with_addons.html', /*language=html*/ '''
<script src="packages/react/js/react.min.js"></script>''')
        ]),
        expectedOutput: d.dir('project', [
          d.file('dev.html', /*language=html*/ '''
<script src="packages/react/js/react.dev.js"></script>'''),
          d.file('dev_with_addons.html', /*language=html*/ '''
<script src="packages/react/js/react.dev.js"></script>'''),
          d.file('prod.html', /*language=html*/ '''
<script src="packages/react/js/react.min.js"></script>'''),
          d.file('prod_with_addons.html', /*language=html*/ '''
<script src="packages/react/js/react.min.js"></script>''')
        ]),
        args: ['--fail-on-changes'], body: (out, err) {
      expect(out, contains('No changes needed.'));
    });
  });
}

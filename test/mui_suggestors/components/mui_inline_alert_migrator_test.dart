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

import 'package:over_react_codemod/src/mui_suggestors/components/mui_inline_alert_migrator.dart';
import 'package:test/test.dart';

import '../../resolved_file_context.dart';
import '../../util.dart';
import 'shared.dart';

void main() {
  final resolvedContext = SharedAnalysisContext.wsd;

  // Warm up analysis in a setUpAll so that if getting the resolved AST times out
  // (which is more common for the WSD context), it fails here instead of failing the first test.
  setUpAll(resolvedContext.warmUpAnalysis);

  group('MuiInlineAlertMigrator', () {
    final testSuggestor = getSuggestorTester(
      MuiInlineAlertMigrator(),
      resolvedContext: resolvedContext,
    );

    group('migrates WSD Alerts', () {
      test('that are either unnamespaced or namespaced, and either v1 or v2',
          () async {
        await testSuggestor(
          input: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                Alert()();
                wsd_v1.Alert()();
                wsd_v2.Alert()();
              }
          '''),
          expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                mui.Alert()();
                mui.Alert()();
                mui.Alert()();
              }
          '''),
        );
      });

      test('and not non-WSD Alert or other components', () async {
        await testSuggestor(
          input: withOverReactAndWsdImports(/*language=dart*/ '''
              // Shadows the WSD Alert
              UiFactory Alert;
              content() {
                // Non-WSD Alert
                Alert()();
                
                Tooltip()();
                Dom.div()();
              }
          '''),
        );
      });

      group('unless it is a toast Alert', () {
        for (final prop in MuiInlineAlertMigrator.toastAlertProps) {
          test('as identified by the $prop prop', () async {
            await testSuggestor(
              input: withOverReactAndWsdImports('''
              content(dynamic propValue) {
                (Alert()..$prop = propValue)();
              }
          '''),
            );
          });
        }
      });
    });

    test('updates the factory', () async {
      await testSuggestor(
        input: withOverReactAndWsdImports(/*language=dart*/ '''
            content() {
              Alert()();
            }
        '''),
        expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
            content() {
              mui.Alert()();
            }
        '''),
      );
    });

    group('updates props', () {});
  }, tags: 'wsd');
}

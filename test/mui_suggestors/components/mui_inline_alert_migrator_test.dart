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

    group('updates props', () {
      group('skin', () {
        test('maps basic skin constants properly', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (Alert()..skin = AlertSkin.DEFAULT)();
                  (Alert()..skin = AlertSkin.SUCCESS)();
                  (Alert()..skin = AlertSkin.WARNING)();
                  (Alert()..skin = AlertSkin.DANGER)();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (mui.Alert()..severity = mui.AlertSeverity.info)();
                  (mui.Alert()..severity = mui.AlertSeverity.success)();
                  (mui.Alert()..severity = mui.AlertSeverity.warning)();
                  (mui.Alert()..severity = mui.AlertSeverity.error)();
                }
            '''),
          );
        });

        test('maps a gray skin to the correct variant', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (Alert()..skin = AlertSkin.GRAY)();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (mui.Alert()..variant = mui.AlertVariant.wsdGray)();
                }
            '''),
          );
        });

        test('flags the inverse skin', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (Alert()..skin = AlertSkin.INVERSE)();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (mui.Alert()
                    // FIXME(mui_migration) - skin prop - this prop was converted from the INVERSE skin and should be double checked
                    ..variant = mui.AlertVariant.wsdGray)();
                }
            '''),
          );
        });

        test('any other value', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
                content(dynamic aValue) {
                  (Alert()..skin = aValue)();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
                content(dynamic aValue) {
                  (mui.Alert()
                    // FIXME(mui_migration) - skin prop - manually migrate
                    ..skin = aValue)();
                }
            '''),
          );
        });
      });

      group('heading', () {
        test('is set to a string', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (Alert()..heading = 'An alert title')();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (mui.Alert())(mui.AlertTitle()('An alert title'),);
                }
            '''),
          );
        });

        test('is set to an expression', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
                content(bool value) {
                  (Alert()..heading = value ? 'An alert title' : 'An alternative title')();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
                content(bool value) {
                  (mui.Alert())(mui.AlertTitle()(value ? 'An alert title' : 'An alternative title'),);
                }
            '''),
          );
        });
      });

      group('headingProps', () {
        test('is an inline props map', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (Alert()
                    ..headingProps = (domProps()..className = 'a class')
                    ..heading = 'An alert title'
                    )();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (mui.Alert()
                  // FIXME(mui_migration) - headingProps prop - manually migrate
                    ..headingProps = (domProps()..className = 'a class')
                  )(mui.AlertTitle()('An alert title'),);
                }
            '''),
          );
        });

        test('is set to an expression', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
                content(dynamic expression) {
                  (Alert()
                    ..headingProps = expression
                    ..heading = 'An alert title'
                    )();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
                content(dynamic expression) {
                  (mui.Alert()
                    // FIXME(mui_migration) - headingProps prop - manually migrate
                    ..headingProps = expression
                  )(mui.AlertTitle()('An alert title'),);
                }
            '''),
          );
        });
      });

      group('size', () {
        test('maps WSD AlertSize constants properly', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (Alert()..size = AlertSize.DEFAULT)();
                  (Alert()..size = AlertSize.SMALL)();
                  (Alert()..size = AlertSize.XSMALL)();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (mui.Alert()..size = mui.AlertSize.medium)();
                  (mui.Alert()..size = mui.AlertSize.small)();
                  (mui.Alert()..size = mui.AlertSize.xsmall)();
                }
            '''),
          );
        });

        test('any other value', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
                content(dynamic aValue) {
                  (Alert()..size = aValue)();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
                content(dynamic aValue) {
                  (mui.Alert()
                    // FIXME(mui_migration) - size prop - manually migrate
                    ..size = aValue)();
                }
            '''),
          );
        });
      });
    });
  }, tags: 'wsd');
}

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

import 'package:over_react_codemod/src/mui_suggestors/components/chip/label_to_mui_chip_migrator.dart';
import 'package:test/test.dart';

import '../../../resolved_file_context.dart';
import '../../../util.dart';
import '../shared.dart';
import '../shared_props_migrators/color_props_test.dart';
import 'shared.dart';

void main() {
  final resolvedContext = SharedAnalysisContext.wsd;

  // Warm up analysis in a setUpAll so that if getting the resolved AST times out
  // (which is more common for the WSD context), it fails here instead of failing the first test.
  setUpAll(resolvedContext.warmUpAnalysis);

  group('LabelToMuiChipMigrator', () {
    final testSuggestor = getSuggestorTester(
      LabelToMuiChipMigrator(),
      resolvedContext: resolvedContext,
    );

    group('migrates WSD Labels', () {
      test('that are either unnamespaced or namespaced, and either v1 or v2',
          () async {
        await testSuggestor(
          input: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                Label()();
                wsd_v1.Label()();
                wsd_v2.Label()();
              }
          '''),
          expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                (mui.Chip()..variant = mui.ChipVariant.wsdLabel)();
                (mui.Chip()..variant = mui.ChipVariant.wsdLabel)();
                (mui.Chip()..variant = mui.ChipVariant.wsdLabel)();
              }
          '''),
        );
      });

      test('and not non-WSD Labels or other components', () async {
        await testSuggestor(
          input: withOverReactAndWsdImports(/*language=dart*/ '''
              // Shadows the WSD ButtonGroup
              UiFactory Label;
              content() {
                // Non-WSD Label
                Label()();
                
                Tooltip()();
                Dom.div()();
              }
          '''),
        );
      });
    });

    test('updates the factory', () async {
      await testSuggestor(
        input: withOverReactAndWsdImports(/*language=dart*/ '''
            content() {
              Label()();
            }
        '''),
        expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
            content() {
              (mui.Chip()..variant = mui.ChipVariant.wsdLabel)();
            }
        '''),
      );
    });

    group('updates props', () {
      group('color props', () {
        colorPropsMigratorTests(
            testSuggestor: testSuggestor,
            startingFactoryName: 'Label',
            extraEndingProps: '..variant = mui.ChipVariant.wsdLabel');
      });

      group('isStatus', () {
        test('boolean literal', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (Label()..isStatus = true)();
                  (Label()..isStatus = false)();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (mui.Chip()
                  ..variant = mui.ChipVariant.wsdLabelStatus)();
                  (mui.Chip()
                  ..variant = mui.ChipVariant.wsdLabel)();
                }
            '''),
          );
        });

        test('other expression', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
                content(bool value) {
                  (Label()..isStatus = value)();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
                content(bool value) {
                  (mui.Chip()
                    ..variant = value ? mui.ChipVariant.wsdLabelStatus : mui.ChipVariant.wsdLabel
                  )();
                }
            '''),
          );
        });
      });

      group('when multiple props are used together', () {
        test('all props', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (Label()
                    ..backgroundColor = BackgroundColor.DANGER
                    ..borderColor = BorderColor.DANGER
                    ..textColor = TextColor.DANGER
                    ..isStatus = true
                    )();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (mui.Chip()
                  ..color = mui.ChipColor.error
                  // FIXME(mui_migration) - borderColor prop - this can be converted to the `sx` prop.
                  ..borderColor = BorderColor.DANGER
                  // FIXME(mui_migration) - textColor prop - this can be converted to the `sx` prop.
                  ..textColor = TextColor.DANGER
                  ..variant = mui.ChipVariant.wsdLabelStatus)();
                }
            '''),
          );
        });
      });
    });

    sharedMuiChipPropsMigratorTests(
        startingFactoryName: 'Label',
        endingVariantName: 'wsdLabel',
        testSuggestor: testSuggestor);
  }, tags: 'wsd');
}

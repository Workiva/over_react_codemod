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

import 'package:over_react_codemod/src/mui_suggestors/components/chip/badge_to_mui_chip_migrator.dart';
import 'package:test/test.dart';

import '../../../resolved_file_context.dart';
import '../../../util.dart';
import '../shared.dart';
import '../shared_props_migrators/color_props.dart';
import '../shared_props_migrators/hit_area.dart';
import 'shared.dart';

void main() {
  final resolvedContext = SharedAnalysisContext.wsd;

  // Warm up analysis in a setUpAll so that if getting the resolved AST times out
  // (which is more common for the WSD context), it fails here instead of failing the first test.
  setUpAll(resolvedContext.warmUpAnalysis);

  group('BadgeToMuiChipMigrator', () {
    final testSuggestor = getSuggestorTester(
      BadgeToMuiChipMigrator(),
      resolvedContext: resolvedContext,
    );

    group('migrates WSD Badges', () {
      test('that are either unnamespaced or namespaced, and either v1 or v2',
          () async {
        await testSuggestor(
          input: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                Badge()();
                wsd_v1.Badge()();
                wsd_v2.Badge()();
              }
          '''),
          expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                (mui.Chip()..variant = mui.ChipVariant.wsdBadge)();
                (mui.Chip()..variant = mui.ChipVariant.wsdBadge)();
                (mui.Chip()..variant = mui.ChipVariant.wsdBadge)();
              }
          '''),
        );
      });

      test('and not non-WSD Badges or other components', () async {
        await testSuggestor(
          input: withOverReactAndWsdImports(/*language=dart*/ '''
              // Shadows the WSD ButtonGroup
              UiFactory Badge;
              content() {
                // Non-WSD Badge
                Badge()();
                
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
              Badge()();
            }
        '''),
        expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
            content() {
              (mui.Chip()..variant = mui.ChipVariant.wsdBadge)();
            }
        '''),
      );
    });

    group('updates props', () {
      group('isOutline, when the RHS is a', () {
        test('boolean literal', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (Badge()..isOutline = true)();
                  (Badge()..isOutline = false)();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (mui.Chip()
                  ..color = mui.ChipColor.wsdBadgeOutlined
                  ..variant = mui.ChipVariant.wsdBadge)();
                  (mui.Chip()
                  ..variant = mui.ChipVariant.wsdBadge)();
                }
            '''),
          );
        });

        test('other expression', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
                content(bool value) {
                  (Badge()..isOutline = value)();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
                content(bool value) {
                  (mui.Chip()
                    ..color = value ? mui.ChipColor.wsdBadgeOutlined : mui.ChipColor.default_
                    ..variant = mui.ChipVariant.wsdBadge
                  )();
                }
            '''),
          );
        });
      });

      group('color props', () {
        colorPropsMigratorTests(
            testSuggestor: testSuggestor,
            startingFactoryName: 'Badge',
            extraEndingProps: '..variant = mui.ChipVariant.wsdBadge',
            testsToSkip: [
              ColorPropsMigratorSkippableTests.BACKGROUND_COLOR_DOC_TYPE_COLORS
            ]);

        group('backgroundColor', () {
          group('flagging when the backgroundColor', () {
            test('is for a badge is a DOC_TYPE color', () async {
              await testSuggestor(
                input: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (Badge()..backgroundColor = BackgroundColor.DOC_TYPE_BLUE)();
                  (Badge()..backgroundColor = BackgroundColor.DOC_TYPE_LIGHT_BLUE)();
                  (Badge()..backgroundColor = BackgroundColor.DOC_TYPE_TEAL)();
                  (Badge()..backgroundColor = BackgroundColor.DOC_TYPE_GRAY)();
                  (Badge()..backgroundColor = BackgroundColor.DOC_TYPE_RED)();
                  (Badge()..backgroundColor = BackgroundColor.DOC_TYPE_GREEN)();
                  (Badge()..backgroundColor = BackgroundColor.DOC_TYPE_PURPLE)();
                  (Badge()..backgroundColor = BackgroundColor.DOC_TYPE_ORANGE)();
                }
            '''),
                expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (mui.Chip()
                  // FIXME(mui_migration) - backgroundColor prop - A MUI chip with the badge variant cannot be set to a DOC_TYPE color. Use the `sx` prop and theme palette instead.
                  ..backgroundColor = BackgroundColor.DOC_TYPE_BLUE..variant = mui.ChipVariant.wsdBadge)();
                  (mui.Chip()
                  // FIXME(mui_migration) - backgroundColor prop - A MUI chip with the badge variant cannot be set to a DOC_TYPE color. Use the `sx` prop and theme palette instead.
                  ..backgroundColor = BackgroundColor.DOC_TYPE_LIGHT_BLUE..variant = mui.ChipVariant.wsdBadge)();
                  (mui.Chip()
                  // FIXME(mui_migration) - backgroundColor prop - A MUI chip with the badge variant cannot be set to a DOC_TYPE color. Use the `sx` prop and theme palette instead.
                  ..backgroundColor = BackgroundColor.DOC_TYPE_TEAL..variant = mui.ChipVariant.wsdBadge)();
                  (mui.Chip()
                  // FIXME(mui_migration) - backgroundColor prop - A MUI chip with the badge variant cannot be set to a DOC_TYPE color. Use the `sx` prop and theme palette instead.
                  ..backgroundColor = BackgroundColor.DOC_TYPE_GRAY..variant = mui.ChipVariant.wsdBadge)();
                  (mui.Chip()
                  // FIXME(mui_migration) - backgroundColor prop - A MUI chip with the badge variant cannot be set to a DOC_TYPE color. Use the `sx` prop and theme palette instead.
                  ..backgroundColor = BackgroundColor.DOC_TYPE_RED..variant = mui.ChipVariant.wsdBadge)();
                  (mui.Chip()
                  // FIXME(mui_migration) - backgroundColor prop - A MUI chip with the badge variant cannot be set to a DOC_TYPE color. Use the `sx` prop and theme palette instead.
                  ..backgroundColor = BackgroundColor.DOC_TYPE_GREEN..variant = mui.ChipVariant.wsdBadge)();
                  (mui.Chip()
                  // FIXME(mui_migration) - backgroundColor prop - A MUI chip with the badge variant cannot be set to a DOC_TYPE color. Use the `sx` prop and theme palette instead.
                  ..backgroundColor = BackgroundColor.DOC_TYPE_PURPLE..variant = mui.ChipVariant.wsdBadge)();
                  (mui.Chip()
                  // FIXME(mui_migration) - backgroundColor prop - A MUI chip with the badge variant cannot be set to a DOC_TYPE color. Use the `sx` prop and theme palette instead.
                  ..backgroundColor = BackgroundColor.DOC_TYPE_ORANGE..variant = mui.ChipVariant.wsdBadge)();
                }
            '''),
              );
            });
          });
        });
      });

      group('align', () {
        test('maps alignment values to specific fixme messages', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (Badge()..align = BadgeAlign.RIGHT)();
                  (Badge()..align = BadgeAlign.PULL_RIGHT)();
                  (Badge()..align = BadgeAlign.LEFT)();
                  (Badge()..align = BadgeAlign.PULL_LEFT)();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (mui.Chip()
                  // FIXME(mui_migration) - align prop - Instead of align, move the badge to be after its siblings and add `sx` like so: ..sx = {\'marginLeft\': (mui.Theme theme) => mui.themeSpacingAsRem(.5, theme), \'mr\': 0}
                  ..align = BadgeAlign.RIGHT
                  ..variant = mui.ChipVariant.wsdBadge)();
                  (mui.Chip()
                  // FIXME(mui_migration) - align prop - Instead of align, move the badge to be after its siblings and add `sx` like so: ..sx = {\'float\': \'right\', \'mr\': 0}
                  ..align = BadgeAlign.PULL_RIGHT
                  ..variant = mui.ChipVariant.wsdBadge)();
                  (mui.Chip()
                  // FIXME(mui_migration) - align prop - Manually verify. BadgeAlign.LEFT is the default and may be able to be removed. Otherwise, `sx` can be used like so: ..sx = {\'marginRight\': (mui.Theme theme) => mui.themeSpacingAsRem(.5, theme)}
                  ..align = BadgeAlign.LEFT
                  ..variant = mui.ChipVariant.wsdBadge)();
                  (mui.Chip()
                  // FIXME(mui_migration) - align prop - Instead of align, `sx` can be used like so: ..sx = {\'float\': \'left\', \'mr\': 0}
                  ..align = BadgeAlign.PULL_LEFT
                  ..variant = mui.ChipVariant.wsdBadge)();
                }
            '''),
          );
        });

        test('handles other expressions', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
                 content(dynamic alignment) {
                  (Badge()..align = alignment)();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
                 content(dynamic alignment) {
                  (mui.Chip()
                  // FIXME(mui_migration) - align prop - Cannot migrate the `align` prop. Use `sx` instead.
                  ..align = alignment
                  ..variant = mui.ChipVariant.wsdBadge)();
                }
            '''),
          );
        });
      });

      group('when multiple props are used together', () {
        test('all non-hit area props', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (Badge()
                    ..backgroundColor = BackgroundColor.DANGER
                    ..borderColor = BorderColor.DANGER
                    ..textColor = TextColor.DANGER
                    ..isOutline = true
                    ..align = BadgeAlign.RIGHT
                    )();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  // FIXME(mui_migration) Both `isOutline` and `backgroundColor` attempt to set the `color` prop. This should be manually verified.
                  (mui.Chip()
                  ..color = mui.ChipColor.error
                  // FIXME(mui_migration) - borderColor prop - this can be converted to the `sx` prop.
                  ..borderColor = BorderColor.DANGER
                  // FIXME(mui_migration) - textColor prop - this can be converted to the `sx` prop.
                  ..textColor = TextColor.DANGER
                  ..color = mui.ChipColor.wsdBadgeOutlined
                  // FIXME(mui_migration) - align prop - Instead of align, move the badge to be after its siblings and add `sx` like so: ..sx = {\'marginLeft\': (mui.Theme theme) => mui.themeSpacingAsRem(.5, theme), \'mr\': 0}
                  ..align = BadgeAlign.RIGHT
                  ..variant = mui.ChipVariant.wsdBadge)();
                }
            '''),
          );
        });

        test('background color and isOutline', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (Badge()..backgroundColor = BackgroundColor.DANGER..isOutline = true)();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  // FIXME(mui_migration) Both `isOutline` and `backgroundColor` attempt to set the `color` prop. This should be manually verified.
                  (mui.Chip()
                  ..color = mui.ChipColor.error
                  ..color = mui.ChipColor.wsdBadgeOutlined
                  ..variant = mui.ChipVariant.wsdBadge)();
                }
            '''),
          );
        });

        test('background color (zesty crayon) and isOutline', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (Badge()..backgroundColor = BackgroundColor.GRAY..isOutline = true)();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  // FIXME(mui_migration) Both `isOutline` and `backgroundColor` attempt to set the `color` prop. This should be manually verified.
                  (mui.Chip()
                  ..color = mui.ChipColor.wsdBadgeOutlined
                  ..sx = {'backgroundColor': (mui.Theme theme) => theme.palette.gray.main, 'color': (mui.Theme theme) => theme.palette.common.white,}
                  ..variant = mui.ChipVariant.wsdBadge)();
                }
            '''),
          );
        });
      });
    });

    sharedHitAreaMixinTests(
        startingFactoryName: 'Badge',
        endingFactoryName: 'Chip',
        testSuggestor: testSuggestor,
        extraEndingProps: '..variant = mui.ChipVariant.wsdBadge');
    sharedMuiChipPropsMigratorTests(
        startingFactoryName: 'Badge',
        endingVariantName: 'wsdBadge',
        testSuggestor: testSuggestor);
  }, tags: 'wsd');
}

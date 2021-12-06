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

import 'package:over_react_codemod/src/mui_suggestors/components/mui_chip_migrator.dart';
import 'package:test/test.dart';

import '../../resolved_file_context.dart';
import '../../util.dart';
import 'shared.dart';

void main() {
  final resolvedContext = SharedAnalysisContext.wsd;

  // Warm up analysis in a setUpAll so that if getting the resolved AST times out
  // (which is more common for the WSD context), it fails here instead of failing the first test.
  setUpAll(resolvedContext.warmUpAnalysis);

  group('MuiChipMigrator', () {
    final testSuggestor = getSuggestorTester(
      MuiChipMigrator(),
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

      test('and not non-WSD ButtonGroups or other components', () async {
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

    group('moves the child to be the label prop', () {
      group('when the child is', () {
        test('a react node', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (Badge())(Dom.span()('Badge Label'));
                }
            '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (mui.Chip()
                    ..label = Dom.span()('Badge Label')
                    ..variant = mui.ChipVariant.wsdBadge)();
                }
            '''),
          );
        });

        test('a primitive', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
            content() {
              (Badge())(45);
            }
        '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
            content() {
              (mui.Chip()
                ..label = 45
                ..variant = mui.ChipVariant.wsdBadge)();
            }
        '''),
          );
        });

        test('a variable', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
            content() {
              final label = 45;
            
              (Badge())(label);
            }
        '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
            content() {
              final label = 45;
            
              (mui.Chip()
                ..label = label
                ..variant = mui.ChipVariant.wsdBadge
              )();
            }
        '''),
          );
        });

        test('a function call', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
            content() {
              final label = () => 45;
            
              (Badge())(label());
            }
        '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
            content() {
              final label = () => 45;
            
              (mui.Chip()
                ..label = label()
                ..variant = mui.ChipVariant.wsdBadge
              )();
            }
        '''),
          );
        });

        test('an accessor', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
             class BadgeLabel {
                static int get label => 45;
              }
              
            content() {
              (Badge())(BadgeLabel.label);
            }
        '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
            class BadgeLabel {
              static int get label => 45;
            }
         
            content() {
              (mui.Chip()
                ..label = BadgeLabel.label
                ..variant = mui.ChipVariant.wsdBadge
              )();
            }
        '''),
          );
        });
      });

      group('unless', () {
        test('the child is empty', () async {
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

        test('there are multiple variadic children', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
            content() {
              Badge()('first child', 'second child');
            }
        '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
            content() {
              (mui.Chip()..variant = mui.ChipVariant.wsdBadge)(
              // FIXME(mui_migration) - Multiple children detected. Manually migrate the children into the `label` prop.
              'first child', 
              'second child');
            }
        '''),
          );
        });

        test('there are multiple non-variadic children', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
            content() {
              Badge()(['Badge Label', 'Suffix']);
            }
        '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
            content() {
              (mui.Chip()
                ..variant = mui.ChipVariant.wsdBadge
              )([
                // FIXME(mui_migration) - Multiple children detected. Manually migrate the children into the `label` prop.
                'Badge Label', 'Suffix'
              ]);
            }
        '''),
          );
        });

        test('the child is a CollectionElementComponentChild', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
            content() {
              Badge()([
              if (true) 'badge'
              ]);
            }
        '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
            content() {
              (mui.Chip()..variant = mui.ChipVariant.wsdBadge)([
                // FIXME(mui_migration) - Complex expression logic detected. Manually migrate the children into the `label` prop.
                if (true) 'badge'
              ]);
            }
        '''),
          );
        });

        test('the child is an unknown ReactNodeTypeCategory', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
            content() {
              dynamic unknown = Dom.span()('label');
            
              Badge()(unknown);
            }
        '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
            content() {
              dynamic unknown = Dom.span()('label');
            
              (mui.Chip()..variant = mui.ChipVariant.wsdBadge)(
              // FIXME(mui_migration) - Unknown child type detected. Manually migrate the children into the `label` prop.
              unknown);
            }
        '''),
          );
        });

        test('the child is an `other` ReactNodeTypeCategory', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
            content() {
              final unknown = () async => 'a function';  
            
              Badge()(unknown);
            }
        '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
            content() {
              final unknown = () async => 'a function';  
            
              (mui.Chip()..variant = mui.ChipVariant.wsdBadge)(
              // FIXME(mui_migration) - Unknown child type detected. Manually migrate the children into the `label` prop.
              unknown);
            }
        '''),
          );
        });
      });
    });

    group('updates props', () {
      group('isDisabled, when the RHS is a', () {
        test('boolean literal', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (Badge()..isDisabled = true)();
                  (Badge()..isDisabled = false)();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (mui.Chip()
                  // FIXME(mui_migration) - isDisabled prop - if this badge has mouse handlers that should fire when disabled or needs to show a tooltip/overlay when disabled, add a wrapper element
                  ..disabled = true
                  ..variant = mui.ChipVariant.wsdBadge)();
                  (mui.Chip()
                  // FIXME(mui_migration) - isDisabled prop - if this badge has mouse handlers that should fire when disabled or needs to show a tooltip/overlay when disabled, add a wrapper element
                  ..disabled = false
                  ..variant = mui.ChipVariant.wsdBadge)();
                }
            '''),
          );
        });

        test('other expression', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
                content(bool value) {
                  (Badge()..isDisabled = value)();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
                content(bool value) {
                  (mui.Chip()
                    // FIXME(mui_migration) - isDisabled prop - if this badge has mouse handlers that should fire when disabled or needs to show a tooltip/overlay when disabled, add a wrapper element
                    ..disabled = value 
                    ..variant = mui.ChipVariant.wsdBadge
                  )();
                }
            '''),
          );
        });
      });

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

      group('backgroundColor', () {
        test('maps non-DOC_TYPE color constants properly', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (Badge()..backgroundColor = BackgroundColor.DANGER)();
                  (Badge()..backgroundColor = BackgroundColor.ALTERNATE)();
                  (Badge()..backgroundColor = BackgroundColor.DEFAULT)();
                  (Badge()..backgroundColor = BackgroundColor.SUCCESS)();
                  (Badge()..backgroundColor = BackgroundColor.WARNING)();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (mui.Chip()..color = mui.ChipColor.error..variant = mui.ChipVariant.wsdBadge)();
                  (mui.Chip()..color = mui.ChipColor.secondary..variant = mui.ChipVariant.wsdBadge)();
                  (mui.Chip()..color = mui.ChipColor.inherit..variant = mui.ChipVariant.wsdBadge)();
                  (mui.Chip()..color = mui.ChipColor.success..variant = mui.ChipVariant.wsdBadge)();
                  (mui.Chip()..color = mui.ChipColor.warning..variant = mui.ChipVariant.wsdBadge)();
                }
            '''),
          );
        });

        test('maps Zesty Crayon colors to the sx prop', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (Badge()..backgroundColor = BackgroundColor.GREEN)();
                  (Badge()..backgroundColor = BackgroundColor.BLUE)();
                  (Badge()..backgroundColor = BackgroundColor.ORANGE)();
                  (Badge()..backgroundColor = BackgroundColor.RED)();
                  (Badge()..backgroundColor = BackgroundColor.GRAY)();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (mui.Chip()..sx = {'backgroundColor': (mui.Theme theme) => theme.palette.green.main, 'color': (mui.Theme theme) => theme.palette.common.white,}..variant = mui.ChipVariant.wsdBadge)();
                  (mui.Chip()..sx = {'backgroundColor': (mui.Theme theme) => theme.palette.blue.main, 'color': (mui.Theme theme) => theme.palette.common.white,}..variant = mui.ChipVariant.wsdBadge)();
                  (mui.Chip()..sx = {'backgroundColor': (mui.Theme theme) => theme.palette.orange.main, 'color': (mui.Theme theme) => theme.palette.common.white,}..variant = mui.ChipVariant.wsdBadge)();
                  (mui.Chip()..sx = {'backgroundColor': (mui.Theme theme) => theme.palette.red.main, 'color': (mui.Theme theme) => theme.palette.common.white,}..variant = mui.ChipVariant.wsdBadge)();
                  (mui.Chip()..sx = {'backgroundColor': (mui.Theme theme) => theme.palette.gray.main, 'color': (mui.Theme theme) => theme.palette.common.white,}..variant = mui.ChipVariant.wsdBadge)();
                }
            '''),
          );
        });

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

          test('is another expression', () async {
            await testSuggestor(
              input: withOverReactAndWsdImports(/*language=dart*/ '''
                content(dynamic otherBackgroundColor) {
                  (Badge()..backgroundColor = otherBackgroundColor)();
                }
            '''),
              expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
                content(dynamic otherBackgroundColor) {
                  (mui.Chip()
                    // FIXME(mui_migration) - backgroundColor prop - manually migrate
                    ..backgroundColor = otherBackgroundColor
                    ..variant = mui.ChipVariant.wsdBadge
                  )();
                }
            '''),
            );
          });
        });
      });

      group('borderColor', () {
        test('gets flagged for manual migration', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (Badge()..borderColor = BorderColor.DANGER)();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (mui.Chip()
                  // FIXME(mui_migration) - borderColor prop - manually migrate
                  ..borderColor = BorderColor.DANGER
                  ..variant = mui.ChipVariant.wsdBadge)();
                }
            '''),
          );
        });
      });

      group('textColor', () {
        test('gets flagged for manual migration', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (Badge()..textColor = TextColor.DANGER)();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (mui.Chip()
                  // FIXME(mui_migration) - textColor prop - manually migrate
                  ..textColor = TextColor.DANGER
                  ..variant = mui.ChipVariant.wsdBadge)();
                }
            '''),
          );
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
                  // FIXME(mui_migration) - borderColor prop - manually migrate
                  ..borderColor = BorderColor.DANGER
                  // FIXME(mui_migration) - textColor prop - manually migrate
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
  }, tags: 'wsd');
}

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

  group('MuiButtonGroupMigrator', () {
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
                    ..variant = mui.ChipVariant.wsdBadge
                    ..label = Dom.span()('Badge Label'))();
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
                ..variant = mui.ChipVariant.wsdBadge
                ..label = 45)();
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
                ..variant = mui.ChipVariant.wsdBadge
                ..label = label
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
                ..variant = mui.ChipVariant.wsdBadge
                ..label = label()
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
                ..variant = mui.ChipVariant.wsdBadge
                ..label = BadgeLabel.label
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

    group('updates props', () {});
  }, tags: 'wsd');
}

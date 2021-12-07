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

import 'package:meta/meta.dart';
import 'package:test/test.dart';

import '../../../util.dart';
import '../shared.dart';

/// Tests for logic shared between components that are migrating to the MUI chip
/// component.
void sharedMuiChipPropsMigratorTests({
  @required SuggestorTester? testSuggestor,
  @required String? startingFactoryName,
  @required String? endingVariantName,
}) {
  if (startingFactoryName == null ||
      endingVariantName == null ||
      testSuggestor == null) {
    throw ArgumentError(
        'startingFactoryName, endingVariantName and testSuggestor are required parameters');
  }

  group('shared MuiChipPropsMigrator', () {
    group('migrateChildrenToLabelProp moves the child to be the label prop',
        () {
      group('when the child is', () {
        test('a react node', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports('''
                content() {
                  ($startingFactoryName())(Dom.span()('Label Body'));
                }
            '''),
            expectedOutput: withOverReactAndWsdImports('''
                content() {
                  (mui.Chip()
                    ..label = Dom.span()('Label Body')
                    ..variant = mui.ChipVariant.$endingVariantName)();
                }
            '''),
          );
        });

        test('a primitive', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports('''
            content() {
              ($startingFactoryName())(45);
            }
        '''),
            expectedOutput: withOverReactAndWsdImports('''
            content() {
              (mui.Chip()
                ..label = 45
                ..variant = mui.ChipVariant.$endingVariantName)();
            }
        '''),
          );
        });

        test('a variable', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports('''
            content() {
              final labelBody = 45;
            
              ($startingFactoryName())(labelBody);
            }
        '''),
            expectedOutput: withOverReactAndWsdImports('''
            content() {
              final labelBody = 45;
            
              (mui.Chip()
                ..label = labelBody
                ..variant = mui.ChipVariant.$endingVariantName
              )();
            }
        '''),
          );
        });

        test('a function call', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports('''
            content() {
              final labelBody = () => 45;
            
              ($startingFactoryName())(labelBody());
            }
        '''),
            expectedOutput: withOverReactAndWsdImports('''
            content() {
              final labelBody = () => 45;
            
              (mui.Chip()
                ..label = labelBody()
                ..variant = mui.ChipVariant.$endingVariantName
              )();
            }
        '''),
          );
        });

        test('an accessor', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports('''
             class LabelClass {
                static int get labelBody => 45;
              }
              
            content() {
              ($startingFactoryName())(LabelClass.labelBody);
            }
        '''),
            expectedOutput: withOverReactAndWsdImports('''
            class LabelClass {
              static int get labelBody => 45;
            }
         
            content() {
              (mui.Chip()
                ..label = LabelClass.labelBody
                ..variant = mui.ChipVariant.$endingVariantName
              )();
            }
        '''),
          );
        });
      });

      group('unless', () {
        test('the child is empty', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports('''
            content() {
              $startingFactoryName()();
            }
        '''),
            expectedOutput: withOverReactAndWsdImports('''
            content() {
              (mui.Chip()..variant = mui.ChipVariant.$endingVariantName)();
            }
        '''),
          );
        });

        test('there are multiple variadic children', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports('''
            content() {
              $startingFactoryName()('first child', 'second child');
            }
        '''),
            expectedOutput: withOverReactAndWsdImports('''
            content() {
              (mui.Chip()..variant = mui.ChipVariant.$endingVariantName)(
              // FIXME(mui_migration) - Multiple children detected. Manually migrate the children into the `label` prop.
              'first child', 
              'second child');
            }
        '''),
          );
        });

        test('there are multiple non-variadic children', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports('''
            content() {
              $startingFactoryName()(['Label Body', 'Suffix']);
            }
        '''),
            expectedOutput: withOverReactAndWsdImports('''
            content() {
              (mui.Chip()
                ..variant = mui.ChipVariant.$endingVariantName
              )([
                // FIXME(mui_migration) - Multiple children detected. Manually migrate the children into the `label` prop.
                'Label Body', 'Suffix'
              ]);
            }
        '''),
          );
        });

        test('the child is a CollectionElementComponentChild', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports('''
            content() {
              $startingFactoryName()([
              if (true) 'label body'
              ]);
            }
        '''),
            expectedOutput: withOverReactAndWsdImports('''
            content() {
              (mui.Chip()..variant = mui.ChipVariant.$endingVariantName)([
                // FIXME(mui_migration) - Complex expression logic detected. Manually migrate the children into the `label` prop.
                if (true) 'label body'
              ]);
            }
        '''),
          );
        });

        test('the child is an unknown ReactNodeTypeCategory', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports('''
            content() {
              dynamic unknown = Dom.span()('label body');
            
              $startingFactoryName()(unknown);
            }
        '''),
            expectedOutput: withOverReactAndWsdImports('''
            content() {
              dynamic unknown = Dom.span()('label body');
            
              (mui.Chip()..variant = mui.ChipVariant.$endingVariantName)(
              // FIXME(mui_migration) - Unknown child type detected. Manually migrate the children into the `label` prop.
              unknown);
            }
        '''),
          );
        });

        test('the child is an `other` ReactNodeTypeCategory', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports('''
            content() {
              final unknown = () async => 'a function';  
            
              $startingFactoryName()(unknown);
            }
        '''),
            expectedOutput: withOverReactAndWsdImports('''
            content() {
              final unknown = () async => 'a function';  
            
              (mui.Chip()..variant = mui.ChipVariant.$endingVariantName)(
              // FIXME(mui_migration) - Unknown child type detected. Manually migrate the children into the `label` prop.
              unknown);
            }
        '''),
          );
        });
      });
    });
  });
}

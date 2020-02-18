// Copyright 2020 Workiva Inc.
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

import 'package:over_react_codemod/src/boilerplate_suggestors/advanced_props_and_state_class_migrator.dart';
import 'package:over_react_codemod/src/boilerplate_suggestors/boilerplate_utilities.dart';
import 'package:test/test.dart';

import '../util.dart';

void main() {
  group('AdvancedPropsAndStateClassMigrator', () {
    var runCount = 0;
    final converter = ClassToMixinConverter();
    SuggestorTester testSuggestor({
      bool convertClassesWithExternalSuperclass = false,
      Map<String, String> visitedClassNames = const {},
    }) {
      runCount++;
      final tester = getSuggestorTester(AdvancedPropsAndStateClassMigrator(
          converter,
          treatUnvisitedClassesAsExternal: runCount > 1,
          convertClassesWithExternalSuperclass:
              convertClassesWithExternalSuperclass));

      // If customVisitedClassNameKeys is set, append the value of `converter.visitedClassNames`.
      // This is done to ensure that those custom classNames are not treated as members of an external library API.
      if (visitedClassNames.isNotEmpty) {
        converter.setVisitedClassNames(
            {...converter.visitedClassNames, ...visitedClassNames});
      }

      return tester;
    }

    tearDown(() {
      runCount = 0;
      converter.setVisitedClassNames({});
      isPublicForTest = false;
    });

    group('does not perform a migration when', () {
      test('it\'s an empty file', () {
        testSuggestor()(expectedPatchCount: 0, input: '');

        expect(converter.visitedClassNames, isEmpty);
      });

      test('the class is simple', () {
        testSuggestor()(
          expectedPatchCount: 0,
          input: r'''
          @Factory()
          UiFactory<FooProps> Foo =
              // ignore: undefined_identifier
              $Foo;
  
          @Props()
          class _$FooProps extends UiProps {
            String foo;
            int bar;
          }
  
          @Component2()
          class FooComponent extends UiComponent2<FooProps> {
            @override
            render() {
              return Dom.ul()(
                Dom.li()('Foo: ', props.foo),
                Dom.li()('Bar: ', props.bar),
              );
            }
          }
        ''',
        );

        expect(converter.classWasMigrated('FooProps'), isFalse);
      });

      test('the class is not Component2, but does add a FIXME comment', () {
        testSuggestor()(
          expectedPatchCount: 1,
          input: r'''
          @Factory()
          UiFactory<FooProps> Foo =
              // ignore: undefined_identifier
              $Foo;
  
          @Props()
          class _$FooProps extends UiProps with SomePropsMixin {
            String foo;
            int bar;
          }
  
          @Component()
          class FooComponent extends UiComponent<FooProps> {
            @override
            render() {
              return Dom.ul()(
                Dom.li()('Foo: ', props.foo),
                Dom.li()('Bar: ', props.bar),
              );
            }
          }
      ''',
          expectedOutput: '''
          @Factory()
          UiFactory<FooProps> Foo =
              // ignore: undefined_identifier
              \$Foo;
  
          // FIXME: `FooProps` could not be auto-migrated to the new over_react boilerplate 
          // because `FooComponent` does not extend from `react.Component2`.
          // 
          // Once you have upgraded the component, you can remove this FIXME comment and 
          // re-run the boilerplate migration script:
          // pub run over_react_codemod:boilerplate_upgrade
          @Props()
          class _\$FooProps extends UiProps with SomePropsMixin {
            String foo;
            int bar;
          }
  
          @Component()
          class FooComponent extends UiComponent<FooProps> {
            @override
            render() {
              return Dom.ul()(
                Dom.li()('Foo: ', props.foo),
                Dom.li()('Bar: ', props.bar),
              );
            }
          }
      ''',
        );

        expect(converter.classWasMigrated('FooProps'), isFalse);
      });

      test('the class is publicly exported, but does add a FIXME comment', () {
        isPublicForTest = true;

        testSuggestor()(
          expectedPatchCount: 1,
          input: r'''
          @Factory()
          UiFactory<FooProps> Foo =
              // ignore: undefined_identifier
              $Foo;
  
          @Props()
          class _$FooProps extends UiProps with SomePropsMixin {
            String foo;
            int bar;
          }
  
          @Component2()
          class FooComponent extends UiComponent2<FooProps> {
            @override
            render() {
              return Dom.ul()(
                Dom.li()('Foo: ', props.foo),
                Dom.li()('Bar: ', props.bar),
              );
            }
          }
      ''',
          expectedOutput: '''
          @Factory()
          UiFactory<FooProps> Foo =
              // ignore: undefined_identifier
              \$Foo;
  
          // FIXME: `FooProps` could not be auto-migrated to the new over_react boilerplate 
          // because doing so would be a breaking change since `FooProps` is exported from a 
          // library in this repo.
          //
          // To complete the migration, you should: 
          //   1. Deprecate `FooProps`.
          //   2. Make a copy of it, renaming it something like `FooPropsV2`.
          //   3. Replace all your current usage of the deprecated `FooProps` with `FooPropsV2`.
          //   4. Add a `hide FooPropsV2` clause to all places where it is exported, and then run:
          //        pub run over_react_codemod:boilerplate_upgrade
          //   5a. If `FooProps` had consumers outside this repo, and it was intentionally made public,
          //       remove the `hide` clause you added in step 4 so that the new mixin created from `FooPropsV2` 
          //       will be a viable replacement for `FooProps`.
          //   5b. If `FooProps` had no consumers outside this repo, and you have no reason to make the new
          //       "V2" class / mixin public, update the `hide` clause you added in step 4 to include both the 
          //       concrete class and the newly created mixin.
          //   6. Remove this FIXME comment.
          @Props()
          class _\$FooProps extends UiProps with SomePropsMixin {
            String foo;
            int bar;
          }
  
          @Component2()
          class FooComponent extends UiComponent2<FooProps> {
            @override
            render() {
              return Dom.ul()(
                Dom.li()('Foo: ', props.foo),
                Dom.li()('Bar: ', props.bar),
              );
            }
          }
      ''',
        );

        expect(converter.classWasMigrated('FooProps'), isFalse);
      });

      group(
          'the class extends from a class not found within ClassToMixinConverter.visitedClassNames',
          () {
        const externalSuperclassName = 'SomeExternalPropsClass';

        final input = '''
            @Factory()
            UiFactory<FooProps> Foo =
                // ignore: undefined_identifier
                \$Foo;
            
            @Props()
            class _\$FooProps extends $externalSuperclassName {
              String foo;
              int bar;
            }
            
            @Component2()
            class FooComponent extends UiComponent2<FooProps> {
              @override
              render() {
                return Dom.ul()(
                  Dom.li()('Foo: ', props.foo),
                  Dom.li()('Bar: ', props.bar),
                );
              }
            }
            ''';

        final expectedOutputWithExternalSuperclassReasonComment = '''
        @Factory()
        UiFactory<FooProps> Foo =
            // ignore: undefined_identifier
            \$Foo;
        
        // FIXME: `FooProps` could not be auto-migrated to the new over_react boilerplate 
        // because it extends from: $externalSuperclassName - which comes from an external library.
        //
        // To complete the migration, you should:
        //   1. Check on the boilerplate migration status of the library it comes from.
        //   2. Once the library has released a version that includes updated boilerplate,
        //      bump the lower bound of your dependency to that version in your `pubspec.yaml`, and run `pub get`.
        //   3. Re-run the migration script with the following flag:
        //      pub run over_react_codemod:boilerplate_upgrade --convert-classes-with-external-superclasses
        //   4. Once the migration is complete, you should notice that $externalSuperclassName has been deprecated. 
        //      Follow the deprecation instructions to consume the replacement by either updating your usage to
        //      the new class name and/or updating to a different entrypoint that exports the version(s) of 
        //      $externalSuperclassName that is compatible with the new over_react boilerplate.
        @Props()
        class _\$FooProps extends $externalSuperclassName {
          String foo;
          int bar;
        }
        
        @Component2()
        class FooComponent extends UiComponent2<FooProps> {
          @override
          render() {
            return Dom.ul()(
              Dom.li()('Foo: ', props.foo),
              Dom.li()('Bar: ', props.bar),
            );
          }
        }
      ''';

        group('but does add a FIXME comment', () {
          setUp(() {
            // When it is run the first time, nothing should happen since
            // we don't know if the custom classes are external or not.
            testSuggestor()(expectedPatchCount: 0, input: input);
            testSuggestor()(
              expectedPatchCount: 1,
              input: input,
              expectedOutput: expectedOutputWithExternalSuperclassReasonComment,
            );
          });

          test('', () {
            expect(
                converter.visitedClassNames,
                {
                  'FooProps': null,
                },
                reason:
                    'FooProps should not be converted since $externalSuperclassName is external, and the --convert-classes-with-external-superclasses flag is not set');
          });

          test(
              'which then gets removed from the declaration that is converted to a mixin, and replaced '
              'with updated instructions on the new concrete class declaration when the script '
              'is re-ran with the --convert-classes-with-external-superclasses flag set',
              () {
            // Run it a third time - this time simulating `--convert-classes-with-external-superclasses`
            // being set - which allows conversion of external superclasses
            testSuggestor(convertClassesWithExternalSuperclass: true)(
              expectedPatchCount: 7,
              input: expectedOutputWithExternalSuperclassReasonComment,
              expectedOutput: '''
              @Factory()
              UiFactory<FooProps> Foo =
                  // ignore: undefined_identifier
                  \$Foo;
  
              @Props()
              mixin FooPropsMixin on UiProps {
                String foo;
                int bar;
              }
  
              // FIXME:
              //   1. Ensure that all mixins used by $externalSuperclassName are also mixed into this class.
              //   2. Fix any analyzer warnings on this class about missing mixins.
              //   3. You should notice that $externalSuperclassName is deprecated.  
              //      Follow the deprecation instructions to consume the replacement by either updating your usage to
              //      the new class/mixin name and/or updating to a different entrypoint that exports the version of 
              //      $externalSuperclassName that is compatible with the new over_react boilerplate.
              //
              //      If it is not deprecated, something most likely went wrong during the migration of the 
              //      library that contains it. 
              class FooProps = UiProps with $externalSuperclassName, FooPropsMixin;
  
              @Component2()
              class FooComponent extends UiComponent2<FooProps> {
                @override
                render() {
                  return Dom.ul()(
                    Dom.li()('Foo: ', props.foo),
                    Dom.li()('Bar: ', props.bar),
                  );
                }
              }
            ''',
            );

            expect(
                converter.visitedClassNames,
                {
                  'FooProps': 'FooPropsMixin',
                },
                reason:
                    'FooProps should be converted to a mixin since the --convert-classes-with-external-superclasses flag is set');
          });
        });

        test(
            'unless the --convert-classes-with-external-superclasses flag is set',
            () {
          // When it is run the first time, nothing should happen since
          // we don't know if the custom classes are external or not.
          testSuggestor()(expectedPatchCount: 0, input: input);
          // Run it a second time - this time simulating `--convert-classes-with-external-superclasses`
          // being set - which allows conversion of external superclasses
          testSuggestor(convertClassesWithExternalSuperclass: true)(
            expectedPatchCount: 6,
            input: '''
            @Factory()
            UiFactory<FooProps> Foo =
                // ignore: undefined_identifier
                \$Foo;

            @Props()
            class _\$FooProps extends $externalSuperclassName {
              String foo;
              int bar;
            }

            @Component2()
            class FooComponent extends UiComponent2<FooProps> {
              @override
              render() {
                return Dom.ul()(
                  Dom.li()('Foo: ', props.foo),
                  Dom.li()('Bar: ', props.bar),
                );
              }
            }
          ''',
            expectedOutput: '''
              @Factory()
              UiFactory<FooProps> Foo =
                  // ignore: undefined_identifier
                  \$Foo;
  
              @Props()
              mixin FooPropsMixin on UiProps {
                String foo;
                int bar;
              }
  
              // FIXME:
              //   1. Ensure that all mixins used by $externalSuperclassName are also mixed into this class.
              //   2. Fix any analyzer warnings on this class about missing mixins.
              //   3. You should notice that $externalSuperclassName is deprecated.  
              //      Follow the deprecation instructions to consume the replacement by either updating your usage to
              //      the new class/mixin name and/or updating to a different entrypoint that exports the version of 
              //      $externalSuperclassName that is compatible with the new over_react boilerplate.
              //
              //      If it is not deprecated, something most likely went wrong during the migration of the 
              //      library that contains it. 
              class FooProps = UiProps with $externalSuperclassName, FooPropsMixin;
  
              @Component2()
              class FooComponent extends UiComponent2<FooProps> {
                @override
                render() {
                  return Dom.ul()(
                    Dom.li()('Foo: ', props.foo),
                    Dom.li()('Bar: ', props.bar),
                  );
                }
              }
            ''',
          );

          expect(
              converter.visitedClassNames,
              {
                'FooProps': 'FooPropsMixin',
              },
              reason:
                  'FooProps should be converted to a mixin since the --convert-classes-with-external-superclasses flag is set');
        });
      });

      group(
          'the class mixes in and extends from classes not found within ClassToMixinConverter.visitedClassNames',
          () {
        const externalSuperclassName = 'SomeExternalPropsClass';
        const externalMixinName = 'SomeExternalMixin';

        final input = '''
            @Factory()
            UiFactory<FooProps> Foo =
                // ignore: undefined_identifier
                \$Foo;
            
            @Props()
            class _\$FooProps extends $externalSuperclassName with $externalMixinName {
              String foo;
              int bar;
            }
            
            @Component2()
            class FooComponent extends UiComponent2<FooProps> {
              @override
              render() {
                return Dom.ul()(
                  Dom.li()('Foo: ', props.foo),
                  Dom.li()('Bar: ', props.bar),
                );
              }
            }
            ''';

        final expectedOutputWithExternalSuperclassReasonComment = '''
        @Factory()
        UiFactory<FooProps> Foo =
            // ignore: undefined_identifier
            \$Foo;
        
        // FIXME: `FooProps` could not be auto-migrated to the new over_react boilerplate 
        // because it mixes in: $externalMixinName - which comes from an external library.
        //
        // To complete the migration, you should:
        //   1. Check on the boilerplate migration status of the library it comes from.
        //   2. Once the library has released a version that includes updated boilerplate,
        //      bump the lower bound of your dependency to that version in your `pubspec.yaml`, and run `pub get`.
        //   3. Re-run the migration script with the following flag:
        //      pub run over_react_codemod:boilerplate_upgrade --convert-classes-with-external-superclasses
        //   4. Once the migration is complete, you should notice that $externalMixinName has been deprecated. 
        //      Follow the deprecation instructions to consume the replacement by either updating your usage to
        //      the new mixin name and/or updating to a different entrypoint that exports the version(s) of 
        //      $externalMixinName that is compatible with the new over_react boilerplate.
        //
        // FIXME: `FooProps` could not be auto-migrated to the new over_react boilerplate 
        // because it extends from: $externalSuperclassName - which comes from an external library.
        //
        // To complete the migration, you should:
        //   1. Check on the boilerplate migration status of the library it comes from.
        //   2. Once the library has released a version that includes updated boilerplate,
        //      bump the lower bound of your dependency to that version in your `pubspec.yaml`, and run `pub get`.
        //   3. Re-run the migration script with the following flag:
        //      pub run over_react_codemod:boilerplate_upgrade --convert-classes-with-external-superclasses
        //   4. Once the migration is complete, you should notice that $externalSuperclassName has been deprecated. 
        //      Follow the deprecation instructions to consume the replacement by either updating your usage to
        //      the new class name and/or updating to a different entrypoint that exports the version(s) of 
        //      $externalSuperclassName that is compatible with the new over_react boilerplate.
        @Props()
        class _\$FooProps extends $externalSuperclassName with $externalMixinName {
          String foo;
          int bar;
        }
        
        @Component2()
        class FooComponent extends UiComponent2<FooProps> {
          @override
          render() {
            return Dom.ul()(
              Dom.li()('Foo: ', props.foo),
              Dom.li()('Bar: ', props.bar),
            );
          }
        }
      ''';

        group('but does add a FIXME comment', () {
          setUp(() {
            // When it is run the first time, nothing should happen since
            // we don't know if the custom classes are external or not.
            testSuggestor()(expectedPatchCount: 0, input: input);
            testSuggestor()(
              expectedPatchCount: 1,
              input: input,
              expectedOutput: expectedOutputWithExternalSuperclassReasonComment,
            );
          });

          test('', () {
            expect(
                converter.visitedClassNames,
                {
                  'FooProps': null,
                },
                reason:
                    'FooProps should not be converted since $externalSuperclassName and $externalMixinName are external, and the --convert-classes-with-external-superclasses flag is not set');
          });

          test(
              'which then gets removed from the declaration that is converted to a mixin, and replaced '
              'with updated instructions on the new concrete class declaration when the script '
              'is re-ran with the --convert-classes-with-external-superclasses flag set',
              () {
            // Run it a third time - this time simulating `--convert-classes-with-external-superclasses`
            // being set - which allows conversion of external superclasses
            testSuggestor(convertClassesWithExternalSuperclass: true)(
              expectedPatchCount: 8,
              input: expectedOutputWithExternalSuperclassReasonComment,
              expectedOutput: '''
              @Factory()
              UiFactory<FooProps> Foo =
                  // ignore: undefined_identifier
                  \$Foo;
  
              @Props()
              mixin FooPropsMixin on UiProps {
                String foo;
                int bar;
              }
  
              // FIXME:
              //   1. Ensure that all mixins used by $externalSuperclassName are also mixed into this class.
              //   2. Fix any analyzer warnings on this class about missing mixins.
              //   3. You should notice that $externalSuperclassName, $externalMixinName are deprecated.  
              //      Follow the deprecation instructions to consume the replacement by either updating your usage to
              //      the new class/mixin name and/or updating to a different entrypoint that exports the versions of 
              //      $externalSuperclassName, $externalMixinName that are compatible with the new over_react boilerplate.
              //
              //      If they are not deprecated, something most likely went wrong during the migration of the 
              //      library that contains them. 
              class FooProps = UiProps with $externalSuperclassName, FooPropsMixin, $externalMixinName;
  
              @Component2()
              class FooComponent extends UiComponent2<FooProps> {
                @override
                render() {
                  return Dom.ul()(
                    Dom.li()('Foo: ', props.foo),
                    Dom.li()('Bar: ', props.bar),
                  );
                }
              }
            ''',
            );

            expect(
                converter.visitedClassNames,
                {
                  'FooProps': 'FooPropsMixin',
                },
                reason:
                    'FooProps should be converted to a mixin since the --convert-classes-with-external-superclasses flag is set');
          });
        });

        test(
            'unless the --convert-classes-with-external-superclasses flag is set',
            () {
          // When it is run the first time, nothing should happen since
          // we don't know if the custom classes are external or not.
          testSuggestor()(expectedPatchCount: 0, input: input);
          // Run it a second time - this time simulating `--convert-classes-with-external-superclasses`
          // being set - which allows conversion of external superclasses
          testSuggestor(convertClassesWithExternalSuperclass: true)(
            expectedPatchCount: 7,
            input: input,
            expectedOutput: '''
              @Factory()
              UiFactory<FooProps> Foo =
                  // ignore: undefined_identifier
                  \$Foo;
  
              @Props()
              mixin FooPropsMixin on UiProps {
                String foo;
                int bar;
              }
  
              // FIXME:
              //   1. Ensure that all mixins used by $externalSuperclassName are also mixed into this class.
              //   2. Fix any analyzer warnings on this class about missing mixins.
              //   3. You should notice that $externalSuperclassName, $externalMixinName are deprecated.  
              //      Follow the deprecation instructions to consume the replacement by either updating your usage to
              //      the new class/mixin name and/or updating to a different entrypoint that exports the versions of 
              //      $externalSuperclassName, $externalMixinName that are compatible with the new over_react boilerplate.
              //
              //      If they are not deprecated, something most likely went wrong during the migration of the 
              //      library that contains them. 
              class FooProps = UiProps with $externalSuperclassName, FooPropsMixin, $externalMixinName;
  
              @Component2()
              class FooComponent extends UiComponent2<FooProps> {
                @override
                render() {
                  return Dom.ul()(
                    Dom.li()('Foo: ', props.foo),
                    Dom.li()('Bar: ', props.bar),
                  );
                }
              }
            ''',
          );

          expect(
              converter.visitedClassNames,
              {
                'FooProps': 'FooPropsMixin',
              },
              reason:
                  'FooProps should be converted to a mixin since the --convert-classes-with-external-superclasses flag is set');
        });
      });

      group(
          'the class extends from a custom class that has been visited, '
          'but not yet converted to the new boilerplate after two runs '
          'but does add a FIXME comment', () {
        final expectedOutputWithUnMigratedSuperclassReasonComment = '''
        @Factory()
        UiFactory<FooProps> Foo =
            // ignore: undefined_identifier
            \$Foo;
        
        // FIXME: `FooProps` could not be auto-migrated to the new over_react boilerplate 
        // because it extends from `ADifferentPropsClass`, which was not able to be migrated.
        //
        // To complete the migration, you should:
        //   1. Look at the "FIXME" comment that has been added to `ADifferentPropsClass` - 
        //      and follow the steps outlined there to complete the migration.
        //   2. Re-run the migration script:
        //      pub run over_react_codemod:boilerplate_upgrade
        @Props()
        class _\$FooProps extends ADifferentPropsClass {
          String foo;
          int bar;
        }

        @Component2()
        class FooComponent extends UiComponent2<FooProps> {
          @override
          render() {
            return Dom.ul()(
              Dom.li()('Foo: ', props.foo),
              Dom.li()('Bar: ', props.bar),
            );
          }
        }
        ''';

        test('', () {
          const input = r'''
          @Factory()
          UiFactory<FooProps> Foo =
              // ignore: undefined_identifier
              $Foo;
  
          @Props()
          class _$FooProps extends ADifferentPropsClass {
            String foo;
            int bar;
          }
  
          @Component2()
          class FooComponent extends UiComponent2<FooProps> {
            @override
            render() {
              return Dom.ul()(
                Dom.li()('Foo: ', props.foo),
                Dom.li()('Bar: ', props.bar),
              );
            }
          }
        ''';

          // When it is run the first time, nothing should happen since
          // we don't know if the custom classes are "migratable" or not.
          testSuggestor()(expectedPatchCount: 0, input: input);
          testSuggestor(
            visitedClassNames: {
              'ADifferentPropsClass': null,
            },
          )(
            expectedPatchCount: 1,
            input: input,
            expectedOutput: expectedOutputWithUnMigratedSuperclassReasonComment,
          );

          expect(converter.visitedClassNames, {
            'ADifferentPropsClass': null,
            'FooProps': null,
          });
        });

        test(
            'which then gets removed and replaced with updated instructions '
            'when the script is re-ran after the consumer makes the class "migratable"',
            () {
          // When it is run the first time, nothing should happen since
          // we don't know if the custom classes are "migratable" or not.
          testSuggestor()(
              expectedPatchCount: 0,
              input: expectedOutputWithUnMigratedSuperclassReasonComment);
          testSuggestor(
            visitedClassNames: {
              'ADifferentPropsClass': 'ADifferentPropsClassMixin',
            },
          )(
            expectedPatchCount: 7,
            input: expectedOutputWithUnMigratedSuperclassReasonComment,
            expectedOutput: '''
            @Factory()
            UiFactory<FooProps> Foo =
                // ignore: undefined_identifier
                \$Foo;
            
            @Props()
            mixin FooPropsMixin on UiProps {
              String foo;
              int bar;
            }

            // FIXME:
            //   1. Ensure that all mixins used by ADifferentPropsClass are also mixed into this class.
            //   2. Fix any analyzer warnings on this class about missing mixins.
            class FooProps = UiProps with ADifferentPropsClassMixin, FooPropsMixin;
    
            @Component2()
            class FooComponent extends UiComponent2<FooProps> {
              @override
              render() {
                return Dom.ul()(
                  Dom.li()('Foo: ', props.foo),
                  Dom.li()('Bar: ', props.bar),
                );
              }
            }
          ''',
          );

          expect(converter.visitedClassNames, {
            'ADifferentPropsClass': 'ADifferentPropsClassMixin',
            'FooProps': 'FooPropsMixin',
          });
        });
      });

      group(
          'the class uses one or more mixins not found within ClassToMixinConverter.visitedClassNames:',
          () {
        group('single external mixin:', () {
          const externalMixinName = 'SomeExternalMixin';

          final input = '''
          @Factory()
          UiFactory<FooProps> Foo =
              // ignore: undefined_identifier
              \$Foo;

          @Props()
          class _\$FooProps extends UiProps with $externalMixinName {
            String foo;
            int bar;
          }

          @Component2()
          class FooComponent extends UiComponent2<FooProps> {
            @override
            render() {
              return Dom.ul()(
                Dom.li()('Foo: ', props.foo),
                Dom.li()('Bar: ', props.bar),
              );
            }
          }
          ''';

          final expectedOutputWithExternalMixinReasonComment = '''
          @Factory()
          UiFactory<FooProps> Foo =
              // ignore: undefined_identifier
              \$Foo;

          // FIXME: `FooProps` could not be auto-migrated to the new over_react boilerplate 
          // because it mixes in: $externalMixinName - which comes from an external library.
          //
          // To complete the migration, you should:
          //   1. Check on the boilerplate migration status of the library it comes from.
          //   2. Once the library has released a version that includes updated boilerplate,
          //      bump the lower bound of your dependency to that version in your `pubspec.yaml`, and run `pub get`.
          //   3. Re-run the migration script with the following flag:
          //      pub run over_react_codemod:boilerplate_upgrade --convert-classes-with-external-superclasses
          //   4. Once the migration is complete, you should notice that $externalMixinName has been deprecated. 
          //      Follow the deprecation instructions to consume the replacement by either updating your usage to
          //      the new mixin name and/or updating to a different entrypoint that exports the version(s) of 
          //      $externalMixinName that is compatible with the new over_react boilerplate.
          @Props()
          class _\$FooProps extends UiProps with $externalMixinName {
            String foo;
            int bar;
          }

          @Component2()
          class FooComponent extends UiComponent2<FooProps> {
            @override
            render() {
              return Dom.ul()(
                Dom.li()('Foo: ', props.foo),
                Dom.li()('Bar: ', props.bar),
              );
            }
          }
        ''';

          group('but does add a FIXME comment', () {
            setUp(() {
              // When it is run the first time, nothing should happen since
              // we don't know if the custom classes are external or not.
              testSuggestor()(expectedPatchCount: 0, input: input);
              testSuggestor()(
                expectedPatchCount: 1,
                input: input,
                expectedOutput: expectedOutputWithExternalMixinReasonComment,
              );
            });

            test('', () {
              expect(
                  converter.visitedClassNames,
                  {
                    'FooProps': null,
                  },
                  reason:
                      'FooProps should not be converted since $externalMixinName is external, and the --convert-classes-with-external-superclasses flag is not set');
            });

            test(
                'which then gets removed from the declaration that is converted to a mixin, and replaced '
                'with updated instructions on the new concrete class declaration when the script '
                'is re-ran with the --convert-classes-with-external-superclasses flag set',
                () {
              // Run it a third time - this time simulating `--convert-classes-with-external-superclasses`
              // being set - which allows conversion of external mixins
              testSuggestor(convertClassesWithExternalSuperclass: true)(
                expectedPatchCount: 7,
                input: expectedOutputWithExternalMixinReasonComment,
                expectedOutput: '''
                @Factory()
                UiFactory<FooProps> Foo =
                    // ignore: undefined_identifier
                    \$Foo;
    
                @Props()
                mixin FooPropsMixin on UiProps {
                  String foo;
                  int bar;
                }
    
                // FIXME:
                //   1. You should notice that $externalMixinName is deprecated.  
                //      Follow the deprecation instructions to consume the replacement by either updating your usage to
                //      the new class/mixin name and/or updating to a different entrypoint that exports the version of 
                //      $externalMixinName that is compatible with the new over_react boilerplate.
                //
                //      If it is not deprecated, something most likely went wrong during the migration of the 
                //      library that contains it. 
                class FooProps = UiProps with FooPropsMixin, $externalMixinName;
    
                @Component2()
                class FooComponent extends UiComponent2<FooProps> {
                  @override
                  render() {
                    return Dom.ul()(
                      Dom.li()('Foo: ', props.foo),
                      Dom.li()('Bar: ', props.bar),
                    );
                  }
                }
              ''',
              );

              expect(
                  converter.visitedClassNames,
                  {
                    'FooProps': 'FooPropsMixin',
                  },
                  reason:
                      'FooProps should be converted to a mixin since the --convert-classes-with-external-superclasses flag is set');
            });
          });
        });

        group('multiple external mixins:', () {
          const externalMixinNames = 'SomeExternalMixin, AnotherExternalMixin';

          final input = '''
          @Factory()
          UiFactory<FooProps> Foo =
              // ignore: undefined_identifier
              \$Foo;

          @Props()
          class _\$FooProps extends UiProps with $externalMixinNames {
            String foo;
            int bar;
          }

          @Component2()
          class FooComponent extends UiComponent2<FooProps> {
            @override
            render() {
              return Dom.ul()(
                Dom.li()('Foo: ', props.foo),
                Dom.li()('Bar: ', props.bar),
              );
            }
          }
          ''';

          final expectedOutputWithExternalMixinReasonComment = '''
          @Factory()
          UiFactory<FooProps> Foo =
              // ignore: undefined_identifier
              \$Foo;

          // FIXME: `FooProps` could not be auto-migrated to the new over_react boilerplate 
          // because it mixes in: $externalMixinNames - which come from an external library.
          //
          // To complete the migration, you should:
          //   1. Check on the boilerplate migration status of the library they come from.
          //   2. Once the library has released a version that includes updated boilerplate,
          //      bump the lower bound of your dependency to that version in your `pubspec.yaml`, and run `pub get`.
          //   3. Re-run the migration script with the following flag:
          //      pub run over_react_codemod:boilerplate_upgrade --convert-classes-with-external-superclasses
          //   4. Once the migration is complete, you should notice that $externalMixinNames have been deprecated. 
          //      Follow the deprecation instructions to consume the replacements by either updating your usage to
          //      the new mixin names and/or updating to a different entrypoint that exports the version(s) of 
          //      $externalMixinNames that are compatible with the new over_react boilerplate.
          @Props()
          class _\$FooProps extends UiProps with $externalMixinNames {
            String foo;
            int bar;
          }

          @Component2()
          class FooComponent extends UiComponent2<FooProps> {
            @override
            render() {
              return Dom.ul()(
                Dom.li()('Foo: ', props.foo),
                Dom.li()('Bar: ', props.bar),
              );
            }
          }
        ''';

          group('but does add a FIXME comment', () {
            setUp(() {
              // When it is run the first time, nothing should happen since
              // we don't know if the custom classes are external or not.
              testSuggestor()(expectedPatchCount: 0, input: input);
              testSuggestor()(
                expectedPatchCount: 1,
                input: input,
                expectedOutput: expectedOutputWithExternalMixinReasonComment,
              );
            });

            test('', () {
              expect(
                  converter.visitedClassNames,
                  {
                    'FooProps': null,
                  },
                  reason:
                      'FooProps should not be converted since $externalMixinNames are external, and the --convert-classes-with-external-superclasses flag is not set');
            });

            test(
                'which then gets removed from the declaration that is converted to a mixin, and replaced '
                'with updated instructions on the new concrete class declaration when the script '
                'is re-ran with the --convert-classes-with-external-superclasses flag set',
                () {
              // Run it a third time - this time simulating `--convert-classes-with-external-superclasses`
              // being set - which allows conversion of external mixins
              testSuggestor(convertClassesWithExternalSuperclass: true)(
                expectedPatchCount: 7,
                input: expectedOutputWithExternalMixinReasonComment,
                expectedOutput: '''
                @Factory()
                UiFactory<FooProps> Foo =
                    // ignore: undefined_identifier
                    \$Foo;
    
                @Props()
                mixin FooPropsMixin on UiProps {
                  String foo;
                  int bar;
                }
    
                // FIXME:
                //   1. You should notice that $externalMixinNames are deprecated.  
                //      Follow the deprecation instructions to consume the replacement by either updating your usage to
                //      the new class/mixin name and/or updating to a different entrypoint that exports the versions of 
                //      $externalMixinNames that are compatible with the new over_react boilerplate.
                //
                //      If they are not deprecated, something most likely went wrong during the migration of the 
                //      library that contains them. 
                class FooProps = UiProps with FooPropsMixin, $externalMixinNames;
    
                @Component2()
                class FooComponent extends UiComponent2<FooProps> {
                  @override
                  render() {
                    return Dom.ul()(
                      Dom.li()('Foo: ', props.foo),
                      Dom.li()('Bar: ', props.bar),
                    );
                  }
                }
              ''',
              );

              expect(
                  converter.visitedClassNames,
                  {
                    'FooProps': 'FooPropsMixin',
                  },
                  reason:
                      'FooProps should be converted to a mixin since the --convert-classes-with-external-superclasses flag is set');
            });
          });
        });
      });
    });

    group('performs a migration when the class(es) are advanced', () {
      group(
          'and there are both a props and a state class that extend '
          'from custom classes that were converted to the new boilerplate', () {
        const input = r'''
          @Factory()
          UiFactory<FooProps> Foo =
              // ignore: undefined_identifier
              $Foo;
  
          @Props()
          class _$FooProps extends ADifferentPropsClass {
            String foo;
            int bar;
          }
  
          @State()
          class _$FooState extends ADifferentStateClass {
            String foo;
            int bar;
          }
  
          @Component2()
          class FooComponent extends UiStatefulComponent2<FooProps, FooState> {
            @override
            render() {
              return Dom.ul()(
                Dom.li()('Foo: ', props.foo),
                Dom.li()('Bar: ', props.bar),
              );
            }
          }
        ''';

        final expectedOutput = '''
        @Factory()
        UiFactory<FooProps> Foo =
            // ignore: undefined_identifier
            \$Foo;

        @Props()
        mixin FooPropsMixin on UiProps {
          String foo;
          int bar;
        }

        // FIXME:
        //   1. Ensure that all mixins used by ADifferentPropsClass are also mixed into this class.
        //   2. Fix any analyzer warnings on this class about missing mixins.
        class FooProps = UiProps with ADifferentPropsClassMixin, FooPropsMixin;

        @State()
        mixin FooStateMixin on UiState {
          String foo;
          int bar;
        }
        
        // FIXME:
        //   1. Ensure that all mixins used by ADifferentStateClass are also mixed into this class.
        //   2. Fix any analyzer warnings on this class about missing mixins.
        class FooState = UiState with ADifferentStateClassMixin, FooStateMixin;

        @Component2()
        class FooComponent extends UiStatefulComponent2<FooProps, FooState> {
          @override
          render() {
            return Dom.ul()(
              Dom.li()('Foo: ', props.foo),
              Dom.li()('Bar: ', props.bar),
            );
          }
        }
      ''';

        test('on the first run', () {
          // Simulates the case where the superclasses were visited first and successfully converted
          testSuggestor(
            visitedClassNames: {
              'ADifferentPropsClass': 'ADifferentPropsClassMixin',
              'ADifferentStateClass': 'ADifferentStateClassMixin',
            },
          )(
            expectedPatchCount: 12,
            input: input,
            expectedOutput: expectedOutput,
          );

          expect(converter.visitedClassNames, {
            'ADifferentPropsClass': 'ADifferentPropsClassMixin',
            'ADifferentStateClass': 'ADifferentStateClassMixin',
            'FooProps': 'FooPropsMixin',
            'FooState': 'FooStateMixin',
          });
        });

        test('on the second run', () {
          // When it is run the first time, nothing should happen since
          // we don't know if the custom classes are external or not.
          testSuggestor(
            visitedClassNames: {
              'ADifferentPropsClass': null,
              'ADifferentStateClass': null,
            },
          )(expectedPatchCount: 0, input: input);
          testSuggestor(
            visitedClassNames: {
              'ADifferentPropsClass': 'ADifferentPropsClassMixin',
              'ADifferentStateClass': 'ADifferentStateClassMixin',
            },
          )(
            expectedPatchCount: 12,
            input: input,
            expectedOutput: expectedOutput,
          );

          expect(converter.visitedClassNames, {
            'ADifferentPropsClass': 'ADifferentPropsClassMixin',
            'ADifferentStateClass': 'ADifferentStateClassMixin',
            'FooProps': 'FooPropsMixin',
            'FooState': 'FooStateMixin',
          });
        });
      });

      group(
          'and there are both a props and state class that use mixins that were converted to the new boilerplate',
          () {
        const input = r'''
        @Factory()
        UiFactory<FooProps> Foo =
            // ignore: undefined_identifier
            $Foo;

        @Props()
        class _$FooProps extends UiProps with AMixin, AnotherMixin {
          String foo;
          int bar;
        }

        @State()
        class _$FooState extends UiState with AStateMixin, AnotherStateMixin {
          String foo;
          int bar;
        }

        @Component2()
        class FooComponent extends UiStatefulComponent2<FooProps, FooState> {
          @override
          render() {
            return Dom.ul()(
              Dom.li()('Foo: ', props.foo),
              Dom.li()('Bar: ', props.bar),
            );
          }
        }
        ''';

        const expectedOutput = r'''
        @Factory()
        UiFactory<FooProps> Foo =
            // ignore: undefined_identifier
            $Foo;

        @Props()
        mixin FooPropsMixin on UiProps {
          String foo;
          int bar;
        }

        class FooProps = UiProps with FooPropsMixin, AMixin, AnotherMixin;

        @State()
        mixin FooStateMixin on UiState {
          String foo;
          int bar;
        }

        class FooState = UiState with FooStateMixin, AStateMixin, AnotherStateMixin;

        @Component2()
        class FooComponent extends UiStatefulComponent2<FooProps, FooState> {
          @override
          render() {
            return Dom.ul()(
              Dom.li()('Foo: ', props.foo),
              Dom.li()('Bar: ', props.bar),
            );
          }
        }
      ''';

        test('on the first run', () {
          // Simulates the case where the superclasses were visited first and successfully converted
          testSuggestor(
            visitedClassNames: {
              'AMixin': 'AMixin',
              'AnotherMixin': 'AnotherMixin',
              'AStateMixin': 'AStateMixin',
              'AnotherStateMixin': 'AnotherStateMixin',
            },
          )(
            expectedPatchCount: 12,
            input: input,
            expectedOutput: expectedOutput,
          );

          expect(converter.visitedClassNames, {
            'AMixin': 'AMixin',
            'AnotherMixin': 'AnotherMixin',
            'AStateMixin': 'AStateMixin',
            'AnotherStateMixin': 'AnotherStateMixin',
            'FooProps': 'FooPropsMixin',
            'FooState': 'FooStateMixin',
          });
        });

        test('on the second run', () {
          // When it is run the first time, nothing should happen since
          // we don't know if the custom mixins are external or not.
          testSuggestor()(expectedPatchCount: 0, input: input);
          testSuggestor(
            visitedClassNames: {
              'AMixin': 'AMixin',
              'AnotherMixin': 'AnotherMixin',
              'AStateMixin': 'AStateMixin',
              'AnotherStateMixin': 'AnotherStateMixin',
            },
          )(
            expectedPatchCount: 12,
            input: input,
            expectedOutput: expectedOutput,
          );

          expect(converter.visitedClassNames, {
            'AMixin': 'AMixin',
            'AnotherMixin': 'AnotherMixin',
            'AStateMixin': 'AStateMixin',
            'AnotherStateMixin': 'AnotherStateMixin',
            'FooProps': 'FooPropsMixin',
            'FooState': 'FooStateMixin',
          });
        });
      });

      group('and there is just a props class', () {
        group('that extends from the reserved FluxUiProps class', () {
          test('and uses no mixins', () {
            final input = r'''
            @Factory()
            UiFactory<FooProps> Foo =
                // ignore: undefined_identifier
                $Foo;
  
            @Props()
            class _$FooProps extends FluxUiProps<SomeActions, SomeStore> {
              String foo;
              int bar;
            }
  
            @Component2()
            class FooComponent extends FluxUiComponent2<FooProps> {
              @override
              render() {
                return Dom.ul()(
                  Dom.li()('Foo: ', props.foo),
                  Dom.li()('Bar: ', props.bar),
                );
              }
            }
            ''';

            testSuggestor()(
              expectedPatchCount: 6,
              input: input,
              expectedOutput: r'''
              @Factory()
              UiFactory<FooProps> Foo =
                  // ignore: undefined_identifier
                  $Foo;
  
              @Props()
              mixin FooPropsMixin on UiProps {
                String foo;
                int bar;
              }
  
              class FooProps = UiProps with FluxUiPropsMixin<SomeActions, SomeStore>, FooPropsMixin;
  
              @Component2()
              class FooComponent extends FluxUiComponent2<FooProps> {
                @override
                render() {
                  return Dom.ul()(
                    Dom.li()('Foo: ', props.foo),
                    Dom.li()('Bar: ', props.bar),
                  );
                }
              }
            ''',
            );

            expect(converter.visitedClassNames, {
              'FooProps': 'FooPropsMixin',
            });
          });

          group('and uses a mixin', () {
            const input = r'''
            @Factory()
            UiFactory<FooProps> Foo =
                // ignore: undefined_identifier
                $Foo;
  
            @Props()
            class _$FooProps extends FluxUiProps<SomeActions, SomeStore> with SomePropsMixin<SomeStore> {
              String foo;
              int bar;
            }
  
            @Component2()
            class FooComponent extends FluxUiComponent2<FooProps> {
              @override
              render() {
                return Dom.ul()(
                  Dom.li()('Foo: ', props.foo),
                  Dom.li()('Bar: ', props.bar),
                );
              }
            }
            ''';

            const expectedOutput = r'''
            @Factory()
            UiFactory<FooProps> Foo =
                // ignore: undefined_identifier
                $Foo;

            @Props()
            mixin FooPropsMixin on UiProps {
              String foo;
              int bar;
            }

            class FooProps = UiProps 
                with 
                    FluxUiPropsMixin<SomeActions, SomeStore>, 
                    FooPropsMixin, 
                    SomePropsMixin<SomeStore>;

            @Component2()
            class FooComponent extends FluxUiComponent2<FooProps> {
              @override
              render() {
                return Dom.ul()(
                  Dom.li()('Foo: ', props.foo),
                  Dom.li()('Bar: ', props.bar),
                );
              }
            }
          ''';

            test('that has already been converted', () {
              testSuggestor(visitedClassNames: {
                'SomePropsMixin': 'SomePropsMixin',
              })(
                expectedPatchCount: 7,
                input: input,
                expectedOutput: expectedOutput,
              );

              expect(converter.visitedClassNames, {
                'SomePropsMixin': 'SomePropsMixin',
                'FooProps': 'FooPropsMixin',
              });
            });

            test('that has not been converted the first time around', () {
              // When it is run the first time, nothing should happen since
              // we don't know if the mixin(s) are external or not.
              testSuggestor()(expectedPatchCount: 0, input: input);
              testSuggestor(visitedClassNames: {
                'SomePropsMixin': 'SomePropsMixin',
              })(
                expectedPatchCount: 7,
                input: input,
                expectedOutput: expectedOutput,
              );

              expect(converter.visitedClassNames, {
                'SomePropsMixin': 'SomePropsMixin',
                'FooProps': 'FooPropsMixin',
              });
            });
          });
        });

        group('that extends from an arbitrary custom class', () {
          test('that is not abstract', () {
            testSuggestor(visitedClassNames: {
              'ADifferentPropsClass': 'ADifferentPropsClassMixin',
            })(
              expectedPatchCount: 6,
              input: r'''
              @Factory()
              UiFactory<FooProps> Foo =
                  // ignore: undefined_identifier
                  $Foo;

              @Props()
              class _$FooProps extends ADifferentPropsClass {
                String foo;
                int bar;
              }

              @Component2()
              class FooComponent extends UiComponent2<FooProps> {
                @override
                render() {
                  return Dom.ul()(
                    Dom.li()('Foo: ', props.foo),
                    Dom.li()('Bar: ', props.bar),
                  );
                }
              }
            ''',
              expectedOutput: r'''
              @Factory()
              UiFactory<FooProps> Foo =
                  // ignore: undefined_identifier
                  $Foo;

              @Props()
              mixin FooPropsMixin on UiProps {
                String foo;
                int bar;
              }

              // FIXME:
              //   1. Ensure that all mixins used by ADifferentPropsClass are also mixed into this class.
              //   2. Fix any analyzer warnings on this class about missing mixins.
              class FooProps = UiProps with ADifferentPropsClassMixin, FooPropsMixin;

              @Component2()
              class FooComponent extends UiComponent2<FooProps> {
                @override
                render() {
                  return Dom.ul()(
                    Dom.li()('Foo: ', props.foo),
                    Dom.li()('Bar: ', props.bar),
                  );
                }
              }
            ''',
            );

            expect(converter.visitedClassNames, {
              'ADifferentPropsClass': 'ADifferentPropsClassMixin',
              'FooProps': 'FooPropsMixin',
            });
          });

          group('that is abstract', () {
            test('with members of its own', () {
              const input = r'''
              @AbstractProps()
              abstract class _$AbstractBlockProps extends SomeAbstractPropsClass
                  with
                      LayoutPropsMixin,
                      // ignore: mixin_of_non_class, undefined_class
                      $LayoutPropsMixin,
                      BlockPropsMixin,
                      // ignore: mixin_of_non_class, undefined_class
                      $BlockPropsMixin
                  implements
                      BlockClassHelperMapView {
                String foo;
                int bar;
              }

              @AbstractComponent2()
              abstract class AbstractBlockComponent<T extends AbstractBlockProps> extends UiComponent2<T>
                  with LayoutMixin<T>, BlockMixin<T> {}
            ''';

              // When it is run the first time, nothing should happen since
              // we don't know if the mixin(s) are external or not.
              testSuggestor()(expectedPatchCount: 0, input: input);
              testSuggestor(visitedClassNames: {
                'SomeAbstractPropsClass': 'SomeAbstractPropsClass',
                'LayoutPropsMixin': 'LayoutPropsMixin',
                'BlockPropsMixin': null,
              })(
                expectedPatchCount: 8,
                input: input,
                expectedOutput: r'''
                @AbstractProps()
                mixin AbstractBlockPropsMixin on UiProps implements BlockClassHelperMapView {
                  String foo;
                  int bar;
                }

                // FIXME:
                //   1. Ensure that all mixins used by SomeAbstractPropsClass are also mixed into this class.
                //   2. Fix any analyzer warnings on this class about missing mixins.
                abstract class AbstractBlockProps implements
                        SomeAbstractPropsClass,
                        AbstractBlockPropsMixin,
                        LayoutPropsMixin,
                        BlockPropsMixin, // ignore: mixin_of_non_class, undefined_class
                        $BlockPropsMixin,
                        BlockClassHelperMapView {}

                @AbstractComponent2()
                abstract class AbstractBlockComponent<T extends AbstractBlockProps> extends UiComponent2<T>
                    with LayoutMixin<T>, BlockMixin<T> {}
              ''',
              );

              expect(converter.visitedClassNames, {
                'SomeAbstractPropsClass': 'SomeAbstractPropsClass',
                'LayoutPropsMixin': 'LayoutPropsMixin',
                'BlockPropsMixin': null,
                'AbstractBlockProps': 'AbstractBlockPropsMixin',
              });
            });

            test('with no members', () {
              const input = r'''
              @AbstractProps()
              abstract class _$AbstractBlockProps extends SomeAbstractPropsClass
                  with
                      LayoutPropsMixin,
                      // ignore: mixin_of_non_class, undefined_class
                      $LayoutPropsMixin,
                      BlockPropsMixin,
                      // ignore: mixin_of_non_class, undefined_class
                      $BlockPropsMixin
                  implements
                      BlockClassHelperMapView {}

              @AbstractComponent2()
              abstract class AbstractBlockComponent<T extends AbstractBlockProps> extends UiComponent2<T>
                  with LayoutMixin<T>, BlockMixin<T> {}
            ''';

              // When it is run the first time, nothing should happen since
              // we don't know if the mixin(s) are external or not.
              testSuggestor()(expectedPatchCount: 0, input: input);
              testSuggestor(visitedClassNames: {
                'SomeAbstractPropsClass': 'SomeAbstractPropsClass',
                'LayoutPropsMixin': 'LayoutPropsMixin',
                'BlockPropsMixin': null,
              })(
                expectedPatchCount: 2,
                input: input,
                expectedOutput: r'''
                // FIXME:
                //   1. Ensure that all mixins used by SomeAbstractPropsClass are also mixed into this class.
                //   2. Fix any analyzer warnings on this class about missing mixins.
                abstract class AbstractBlockProps implements
                        SomeAbstractPropsClass,
                        LayoutPropsMixin,
                        BlockPropsMixin, // ignore: mixin_of_non_class, undefined_class
                        $BlockPropsMixin,
                        BlockClassHelperMapView {}

                @AbstractComponent2()
                abstract class AbstractBlockComponent<T extends AbstractBlockProps> extends UiComponent2<T>
                    with LayoutMixin<T>, BlockMixin<T> {}
              ''',
              );

              expect(converter.visitedClassNames, {
                'SomeAbstractPropsClass': 'SomeAbstractPropsClass',
                'LayoutPropsMixin': 'LayoutPropsMixin',
                'BlockPropsMixin': null,
                'AbstractBlockProps': 'AbstractBlockProps',
              });
            });
          });

          group('that has an analagous abstract component class', () {
            test('and members of its own', () {
              testSuggestor(visitedClassNames: {
                'SomeAbstractPropsClass': 'SomeAbstractPropsClassMixin',
              })(
                expectedPatchCount: 6,
                input: r'''
                @Factory()
                UiFactory<FooProps> Foo =
                    // ignore: undefined_identifier
                    $Foo;

                @Props()
                class _$FooProps extends SomeAbstractPropsClass implements SomeInterface {
                  String foo;
                  int bar;
                }

                @Component2()
                class FooComponent extends AbstractComponentClass<FooProps> {
                  @override
                  render() {
                    return Dom.ul()(
                      Dom.li()('Foo: ', props.foo),
                      Dom.li()('Bar: ', props.bar),
                    );
                  }
                }
              ''',
                expectedOutput: r'''
                @Factory()
                UiFactory<FooProps> Foo =
                    // ignore: undefined_identifier
                    $Foo;

                @Props()
                mixin FooPropsMixin on UiProps implements SomeInterface {
                  String foo;
                  int bar;
                }

                // FIXME:
                //   1. Ensure that all mixins used by SomeAbstractPropsClass are also mixed into this class.
                //   2. Fix any analyzer warnings on this class about missing mixins.
                class FooProps = UiProps with SomeAbstractPropsClassMixin, FooPropsMixin
                    implements SomeAbstractPropsClass, SomeInterface;

                @Component2()
                class FooComponent extends AbstractComponentClass<FooProps> {
                  @override
                  render() {
                    return Dom.ul()(
                      Dom.li()('Foo: ', props.foo),
                      Dom.li()('Bar: ', props.bar),
                    );
                  }
                }
              ''',
              );

              expect(converter.visitedClassNames, {
                'SomeAbstractPropsClass': 'SomeAbstractPropsClassMixin',
                'FooProps': 'FooPropsMixin',
              });
            });

            test('but no members of its own', () {
              testSuggestor(visitedClassNames: {
                'SomeAbstractPropsClass': 'SomeAbstractPropsClass',
              })(
                expectedPatchCount: 2,
                input: r'''
                @Factory()
                UiFactory<FooProps> Foo =
                    // ignore: undefined_identifier
                    $Foo;

                @Props()
                class _$FooProps extends SomeAbstractPropsClass implements SomeInterface {}

                @Component2()
                class FooComponent extends AbstractComponentClass<FooProps> {
                  @override
                  render() {
                    return Dom.ul()(
                      Dom.li()('Foo: ', props.foo),
                      Dom.li()('Bar: ', props.bar),
                    );
                  }
                }
              ''',
                expectedOutput: r'''
                @Factory()
                UiFactory<FooProps> Foo =
                    // ignore: undefined_identifier
                    $Foo;

                // FIXME:
                //   1. Ensure that all mixins used by SomeAbstractPropsClass are also mixed into this class.
                //   2. Fix any analyzer warnings on this class about missing mixins.
                class FooProps extends UiProps implements SomeAbstractPropsClass, SomeInterface {}

                @Component2()
                class FooComponent extends AbstractComponentClass<FooProps> {
                  @override
                  render() {
                    return Dom.ul()(
                      Dom.li()('Foo: ', props.foo),
                      Dom.li()('Bar: ', props.bar),
                    );
                  }
                }
              ''',
              );

              expect(converter.visitedClassNames, {
                'SomeAbstractPropsClass': 'SomeAbstractPropsClass',
                'FooProps': 'FooProps',
              });
            });
          });
        });

        test('that extends from UiProps, but uses mixins', () {
          const input = r'''
          @Factory()
          UiFactory<FooProps> Foo =
              // ignore: undefined_identifier
              $Foo;

          @Props()
          class _$FooProps extends UiProps
              with ConvertedMixin,
                   // ignore: mixin_of_non_class, undefined_class
                   $ConvertedMixin,
                   UnconvertedMixin,
                   // ignore: mixin_of_non_class, undefined_class
                   $UnconvertedMixin {
            String foo;
            int bar;
          }

          @Component2()
          class FooComponent extends UiComponent2<FooProps> {
            @override
            render() {
              return Dom.ul()(
                Dom.li()('Foo: ', props.foo),
                Dom.li()('Bar: ', props.bar),
              );
            }
          }
        ''';

          // When it is run the first time, nothing should happen since
          // we don't know for sure if UnconvertedMixin can be converted yet.
          testSuggestor()(expectedPatchCount: 0, input: input);
          testSuggestor(visitedClassNames: {
            'ConvertedMixin': 'ConvertedMixin',
            'UnconvertedMixin': null,
          })(
            expectedPatchCount: 6,
            input: input,
            expectedOutput: r'''
            @Factory()
            UiFactory<FooProps> Foo =
                // ignore: undefined_identifier
                $Foo;

            @Props()
            mixin FooPropsMixin on UiProps {
              String foo;
              int bar;
            }

            class FooProps = UiProps
                with FooPropsMixin, ConvertedMixin, UnconvertedMixin, // ignore: mixin_of_non_class, undefined_class
                $UnconvertedMixin;

            @Component2()
            class FooComponent extends UiComponent2<FooProps> {
              @override
              render() {
                return Dom.ul()(
                  Dom.li()('Foo: ', props.foo),
                  Dom.li()('Bar: ', props.bar),
                );
              }
            }
          ''',
          );

          expect(converter.visitedClassNames, {
            'ConvertedMixin': 'ConvertedMixin',
            'UnconvertedMixin': null,
            'FooProps': 'FooPropsMixin',
          });
        });

        group('that extends from UiProps, uses mixins, implements interfaces',
            () {
          test('and is not abstract', () {
            testSuggestor(visitedClassNames: {
              'ConvertedMixin': 'ConvertedMixin',
            })(
              expectedPatchCount: 6,
              input: r'''
              @Factory()
              UiFactory<FooProps> Foo =
                  // ignore: undefined_identifier
                  $Foo;

              @Props()
              class _$FooProps extends UiProps with ConvertedMixin implements SomeInterface, SomeOtherInterface {
                String foo;
                int bar;
              }

              @Component2()
              class FooComponent extends UiComponent2<FooProps> {
                @override
                render() {
                  return Dom.ul()(
                    Dom.li()('Foo: ', props.foo),
                    Dom.li()('Bar: ', props.bar),
                  );
                }
              }
            ''',
              expectedOutput: r'''
              @Factory()
              UiFactory<FooProps> Foo =
                  // ignore: undefined_identifier
                  $Foo;

              @Props()
              mixin FooPropsMixin on UiProps implements SomeInterface, SomeOtherInterface {
                String foo;
                int bar;
              }

              class FooProps = UiProps with FooPropsMixin, ConvertedMixin implements SomeInterface, SomeOtherInterface;

              @Component2()
              class FooComponent extends UiComponent2<FooProps> {
                @override
                render() {
                  return Dom.ul()(
                    Dom.li()('Foo: ', props.foo),
                    Dom.li()('Bar: ', props.bar),
                  );
                }
              }
            ''',
            );

            expect(converter.visitedClassNames, {
              'ConvertedMixin': 'ConvertedMixin',
              'FooProps': 'FooPropsMixin',
            });
          });

          group('and is abstract', () {
            test('with members of its own', () {
              const input = r'''
              @AbstractProps()
              abstract class _$AbstractBlockProps extends UiProps
                  with
                      LayoutPropsMixin,
                      // ignore: mixin_of_non_class, undefined_class
                      $LayoutPropsMixin,
                      BlockPropsMixin,
                      // ignore: mixin_of_non_class, undefined_class
                      $BlockPropsMixin
                  implements
                      BlockClassHelperMapView {
                String foo;
                int bar;
              }

              @AbstractComponent2()
              abstract class AbstractBlockComponent<T extends AbstractBlockProps> extends UiComponent2<T>
                  with LayoutMixin<T>, BlockMixin<T> {}
            ''';

              // When it is run the first time, nothing should happen since
              // we don't know if the mixin(s) are external or not.
              testSuggestor()(expectedPatchCount: 0, input: input);
              testSuggestor(visitedClassNames: {
                'LayoutPropsMixin': 'LayoutPropsMixin',
                'BlockPropsMixin': null,
              })(
                expectedPatchCount: 7,
                input: input,
                expectedOutput: r'''
                @AbstractProps()
                mixin AbstractBlockPropsMixin on UiProps implements BlockClassHelperMapView {
                  String foo;
                  int bar;
                }

                abstract class AbstractBlockProps implements
                        AbstractBlockPropsMixin,
                        LayoutPropsMixin,
                        BlockPropsMixin, // ignore: mixin_of_non_class, undefined_class
                        $BlockPropsMixin,
                        BlockClassHelperMapView {}

                @AbstractComponent2()
                abstract class AbstractBlockComponent<T extends AbstractBlockProps> extends UiComponent2<T>
                    with LayoutMixin<T>, BlockMixin<T> {}
              ''',
              );

              expect(converter.visitedClassNames, {
                'LayoutPropsMixin': 'LayoutPropsMixin',
                'BlockPropsMixin': null,
                'AbstractBlockProps': 'AbstractBlockPropsMixin',
              });
            });

            test('with no members', () {
              const input = r'''
              @AbstractProps()
              abstract class _$AbstractBlockProps extends UiProps
                  with
                      LayoutPropsMixin,
                      // ignore: mixin_of_non_class, undefined_class
                      $LayoutPropsMixin,
                      BlockPropsMixin,
                      // ignore: mixin_of_non_class, undefined_class
                      $BlockPropsMixin
                  implements
                      BlockClassHelperMapView {}

              @AbstractComponent2()
              abstract class AbstractBlockComponent<T extends AbstractBlockProps> extends UiComponent2<T>
                  with LayoutMixin<T>, BlockMixin<T> {}
            ''';

              // When it is run the first time, nothing should happen since
              // we don't know if the mixin(s) are external or not.
              testSuggestor()(expectedPatchCount: 0, input: input);
              testSuggestor(visitedClassNames: {
                'LayoutPropsMixin': 'LayoutPropsMixin',
                'BlockPropsMixin': null,
              })(
                expectedPatchCount: 2,
                input: input,
                expectedOutput: r'''
                abstract class AbstractBlockProps implements
                        LayoutPropsMixin,
                        BlockPropsMixin, // ignore: mixin_of_non_class, undefined_class
                        $BlockPropsMixin,
                        BlockClassHelperMapView {}

                @AbstractComponent2()
                abstract class AbstractBlockComponent<T extends AbstractBlockProps> extends UiComponent2<T>
                    with LayoutMixin<T>, BlockMixin<T> {}
              ''',
              );

              expect(converter.visitedClassNames, {
                'LayoutPropsMixin': 'LayoutPropsMixin',
                'BlockPropsMixin': null,
                'AbstractBlockProps': 'AbstractBlockProps',
              });
            });
          });
        });

        group(
            'and there is already a mixin that matches the name of the class appended with "Mixin"',
            () {
          test('and the class has no members of its own', () {
            testSuggestor(visitedClassNames: {
              'FooPropsMixin': 'FooPropsMixin',
            })(
              expectedPatchCount: 2,
              input: r'''
              @Factory()
              UiFactory<FooProps> Foo =
                  // ignore: undefined_identifier
                  $Foo;

              @PropsMixin()
              mixin FooPropsMixin on UiProps {
                String foo;
                int bar;
              }

              @Props()
              class _$FooProps extends UiProps with FooPropsMixin {}

              @Component2()
              class FooComponent extends UiComponent2<FooProps, FooState> {
                @override
                render() {
                  return Dom.ul()(
                    Dom.li()('Foo: ', props.foo),
                    Dom.li()('Bar: ', props.bar),
                  );
                }
              }
            ''',
              expectedOutput: r'''
              @Factory()
              UiFactory<FooProps> Foo =
                  // ignore: undefined_identifier
                  $Foo;

              @PropsMixin()
              mixin FooPropsMixin on UiProps {
                String foo;
                int bar;
              }

              class FooProps = UiProps with FooPropsMixin;

              @Component2()
              class FooComponent extends UiComponent2<FooProps, FooState> {
                @override
                render() {
                  return Dom.ul()(
                    Dom.li()('Foo: ', props.foo),
                    Dom.li()('Bar: ', props.bar),
                  );
                }
              }
            ''',
            );

            expect(converter.visitedClassNames, {
              'FooPropsMixin': 'FooPropsMixin',
              'FooProps': 'FooProps',
            });
          });

          test('and the class has members', () {
            testSuggestor(visitedClassNames: {
              'FooPropsMixin': 'FooPropsMixin',
            })(
              expectedPatchCount: 3,
              input: r'''
              @Factory()
              UiFactory<FooProps> Foo =
                  // ignore: undefined_identifier
                  $Foo;

              @PropsMixin()
              mixin FooPropsMixin on UiProps {
                String foo;
                int bar;
              }

              @Props()
              class _$FooProps extends UiProps with FooPropsMixin {
                String baz;
              }

              @Component2()
              class FooComponent extends UiComponent2<FooProps, FooState> {
                @override
                render() {
                  return Dom.ul()(
                    Dom.li()('Foo: ', props.foo),
                    Dom.li()('Bar: ', props.bar),
                  );
                }
              }
            ''',
              expectedOutput: r'''
              @Factory()
              UiFactory<FooProps> Foo =
                  // ignore: undefined_identifier
                  $Foo;

              @PropsMixin()
              mixin FooPropsMixin on UiProps {
                String foo;
                int bar;
                String baz;
              }

              class FooProps = UiProps with FooPropsMixin;

              @Component2()
              class FooComponent extends UiComponent2<FooProps, FooState> {
                @override
                render() {
                  return Dom.ul()(
                    Dom.li()('Foo: ', props.foo),
                    Dom.li()('Bar: ', props.bar),
                  );
                }
              }
            ''',
            );

            expect(converter.visitedClassNames, {
              'FooPropsMixin': 'FooPropsMixin',
              'FooProps': 'FooProps',
            });
          });
        });
      });

      test(
          'and there are classes that extend from arbitrary custom classes, along with mixins',
          () {
        const input = r'''
        @Factory()
        UiFactory<FooProps> Foo =
            // ignore: undefined_identifier
            $Foo;

        @Props()
        class _$FooProps extends ADifferentPropsClass with AMixin, AnotherMixin {
          String foo;
          int bar;
        }

        @State()
        class _$FooState extends ADifferentStateClass with AStateMixin, AnotherStateMixin {
          String foo;
          int bar;
        }

        @Component2()
        class FooComponent extends UiStatefulComponent2<FooProps, FooState> {
          @override
          render() {
            return Dom.ul()(
              Dom.li()('Foo: ', props.foo),
              Dom.li()('Bar: ', props.bar),
            );
          }
        }
      ''';

        // When it is run the first time, nothing should happen since
        // we don't know if the mixin(s) are external or not.
        testSuggestor()(expectedPatchCount: 0, input: input);
        testSuggestor(visitedClassNames: {
          'AMixin': 'AMixin',
          'AnotherMixin': 'AnotherMixin',
          'ADifferentPropsClass': 'ADifferentPropsClassMixin',
          'AStateMixin': 'AStateMixin',
          'AnotherStateMixin': 'AnotherStateMixin',
          'ADifferentStateClass': 'ADifferentStateClass',
        })(
          expectedPatchCount: 14,
          input: input,
          expectedOutput: r'''
          @Factory()
          UiFactory<FooProps> Foo =
              // ignore: undefined_identifier
              $Foo;

          @Props()
          mixin FooPropsMixin on UiProps {
            String foo;
            int bar;
          }

          // FIXME:
          //   1. Ensure that all mixins used by ADifferentPropsClass are also mixed into this class.
          //   2. Fix any analyzer warnings on this class about missing mixins.
          class FooProps = UiProps with ADifferentPropsClassMixin, FooPropsMixin, AMixin, AnotherMixin;

          @State()
          mixin FooStateMixin on UiState {
            String foo;
            int bar;
          }

          // FIXME:
          //   1. Ensure that all mixins used by ADifferentStateClass are also mixed into this class.
          //   2. Fix any analyzer warnings on this class about missing mixins.
          class FooState = UiState with ADifferentStateClass, FooStateMixin, AStateMixin, AnotherStateMixin;

          @Component2()
          class FooComponent extends UiStatefulComponent2<FooProps, FooState> {
            @override
            render() {
              return Dom.ul()(
                Dom.li()('Foo: ', props.foo),
                Dom.li()('Bar: ', props.bar),
              );
            }
          }
        ''',
        );

        expect(converter.visitedClassNames, {
          'AMixin': 'AMixin',
          'AnotherMixin': 'AnotherMixin',
          'ADifferentPropsClass': 'ADifferentPropsClassMixin',
          'AStateMixin': 'AStateMixin',
          'AnotherStateMixin': 'AnotherStateMixin',
          'ADifferentStateClass': 'ADifferentStateClass',
          'FooProps': 'FooPropsMixin',
          'FooState': 'FooStateMixin',
        });
      });

      group(
          'and there is a props class that extends from an arbitrary custom class, along with a mixin that has '
          'a name that matches the name of the class appended with "Mixin"',
          () {
        group('and that mixin exists in the same root', () {
          setUp(() {
            converter.setVisitedClassNames({
              'FooPropsMixin': 'FooPropsMixin',
              'ADifferentPropsClass': 'ADifferentPropsClassMixin',
            });
          });

          test('and the class has no members', () {
            testSuggestor()(
              expectedPatchCount: 2,
              input: r'''
              @Factory()
              UiFactory<FooProps> Foo =
                  // ignore: undefined_identifier
                  $Foo;

              @PropsMixin()
              mixin FooPropsMixin on UiProps {
                String foo;
                int bar;
              }

              @Props()
              class _$FooProps extends ADifferentPropsClass with FooPropsMixin {}

              @Component2()
              class FooComponent extends UiComponent2<FooProps, FooState> {
                @override
                render() {
                  return Dom.ul()(
                    Dom.li()('Foo: ', props.foo),
                    Dom.li()('Bar: ', props.bar),
                  );
                }
              }
            ''',
              expectedOutput: r'''
              @Factory()
              UiFactory<FooProps> Foo =
                  // ignore: undefined_identifier
                  $Foo;

              @PropsMixin()
              mixin FooPropsMixin on UiProps {
                String foo;
                int bar;
              }

              // FIXME:
              //   1. Ensure that all mixins used by ADifferentPropsClass are also mixed into this class.
              //   2. Fix any analyzer warnings on this class about missing mixins.
              class FooProps = UiProps with ADifferentPropsClassMixin, FooPropsMixin;

              @Component2()
              class FooComponent extends UiComponent2<FooProps, FooState> {
                @override
                render() {
                  return Dom.ul()(
                    Dom.li()('Foo: ', props.foo),
                    Dom.li()('Bar: ', props.bar),
                  );
                }
              }
            ''',
            );

            expect(converter.visitedClassNames, {
              'FooPropsMixin': 'FooPropsMixin',
              'ADifferentPropsClass': 'ADifferentPropsClassMixin',
              'FooProps': 'FooProps',
            });
          });

          test('and the class has members', () {
            testSuggestor()(
              expectedPatchCount: 3,
              input: r'''
              @Factory()
              UiFactory<FooProps> Foo =
                  // ignore: undefined_identifier
                  $Foo;

              @PropsMixin()
              mixin FooPropsMixin on UiProps {
                String foo;
                int bar;
              }

              @Props()
              class _$FooProps extends ADifferentPropsClass with FooPropsMixin {
                String baz;
              }

              @Component2()
              class FooComponent extends UiComponent2<FooProps, FooState> {
                @override
                render() {
                  return Dom.ul()(
                    Dom.li()('Foo: ', props.foo),
                    Dom.li()('Bar: ', props.bar),
                  );
                }
              }
            ''',
              expectedOutput: r'''
              @Factory()
              UiFactory<FooProps> Foo =
                  // ignore: undefined_identifier
                  $Foo;

              @PropsMixin()
              mixin FooPropsMixin on UiProps {
                String foo;
                int bar;
                String baz;
              }

              // FIXME:
              //   1. Ensure that all mixins used by ADifferentPropsClass are also mixed into this class.
              //   2. Fix any analyzer warnings on this class about missing mixins.
              class FooProps = UiProps with ADifferentPropsClassMixin, FooPropsMixin;

              @Component2()
              class FooComponent extends UiComponent2<FooProps, FooState> {
                @override
                render() {
                  return Dom.ul()(
                    Dom.li()('Foo: ', props.foo),
                    Dom.li()('Bar: ', props.bar),
                  );
                }
              }
            ''',
            );

            expect(converter.visitedClassNames, {
              'FooPropsMixin': 'FooPropsMixin',
              'ADifferentPropsClass': 'ADifferentPropsClassMixin',
              'FooProps': 'FooProps',
            });
          });
        });

        group(
            'and that mixin does not exist in the same root, but has already been converted',
            () {
          setUp(() {
            converter.setVisitedClassNames({
              'ADifferentPropsClass': 'ADifferentPropsClassMixin',
              'FooPropsMixin': 'FooPropsMixin',
            });
          });

          test('and the class has no members', () {
            testSuggestor()(
              expectedPatchCount: 2,
              input: r'''
              @Factory()
              UiFactory<FooProps> Foo =
                  // ignore: undefined_identifier
                  $Foo;

              @Props()
              class _$FooProps extends ADifferentPropsClass with FooPropsMixin {}

              @Component2()
              class FooComponent extends UiComponent2<FooProps, FooState> {
                @override
                render() {
                  return Dom.ul()(
                    Dom.li()('Foo: ', props.foo),
                    Dom.li()('Bar: ', props.bar),
                  );
                }
              }
            ''',
              expectedOutput: r'''
              @Factory()
              UiFactory<FooProps> Foo =
                  // ignore: undefined_identifier
                  $Foo;

              // FIXME:
              //   1. Ensure that all mixins used by ADifferentPropsClass are also mixed into this class.
              //   2. Fix any analyzer warnings on this class about missing mixins.
              class FooProps = UiProps with ADifferentPropsClassMixin, FooPropsMixin;

              @Component2()
              class FooComponent extends UiComponent2<FooProps, FooState> {
                @override
                render() {
                  return Dom.ul()(
                    Dom.li()('Foo: ', props.foo),
                    Dom.li()('Bar: ', props.bar),
                  );
                }
              }
            ''',
            );

            expect(converter.visitedClassNames, {
              'ADifferentPropsClass': 'ADifferentPropsClassMixin',
              'FooPropsMixin': 'FooPropsMixin',
              'FooProps': 'FooProps',
            });
          });

          test('and the class has members', () {
            testSuggestor()(
              expectedPatchCount: 2,
              input: r'''
              @Factory()
              UiFactory<FooProps> Foo =
                  // ignore: undefined_identifier
                  $Foo;

              @Props()
              class _$FooProps extends ADifferentPropsClass with FooPropsMixin {
                String baz;
              }

              @Component2()
              class FooComponent extends UiComponent2<FooProps, FooState> {
                @override
                render() {
                  return Dom.ul()(
                    Dom.li()('Foo: ', props.foo),
                    Dom.li()('Bar: ', props.bar),
                  );
                }
              }
            ''',
              expectedOutput: r'''
              @Factory()
              UiFactory<FooProps> Foo =
                  // ignore: undefined_identifier
                  $Foo;

              // FIXME:
              //   1. Ensure that all mixins used by ADifferentPropsClass are also mixed into this class.
              //   2. Fix any analyzer warnings on this class about missing mixins.
              class FooProps extends UiProps with ADifferentPropsClassMixin, FooPropsMixin {
                // FIXME: Everything in this body needs to be moved to the body of FooPropsMixin.
                // Once that is done, the body can be removed, and `extends` can be replaced with `=`.
                String baz;
              }

              @Component2()
              class FooComponent extends UiComponent2<FooProps, FooState> {
                @override
                render() {
                  return Dom.ul()(
                    Dom.li()('Foo: ', props.foo),
                    Dom.li()('Bar: ', props.bar),
                  );
                }
              }
            ''',
            );

            expect(converter.visitedClassNames, {
              'ADifferentPropsClass': 'ADifferentPropsClassMixin',
              'FooPropsMixin': 'FooPropsMixin',
              'FooProps': 'FooProps',
            });
          });
        });
      });
    });
  });
}

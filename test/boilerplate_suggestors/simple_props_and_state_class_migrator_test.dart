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

import 'package:over_react_codemod/src/boilerplate_suggestors/boilerplate_utilities.dart';
import 'package:over_react_codemod/src/boilerplate_suggestors/migration_decision.dart';
import 'package:over_react_codemod/src/boilerplate_suggestors/simple_props_and_state_class_migrator.dart';
import 'package:test/test.dart';

import '../util.dart';

main() {
  group('SimplePropsAndStateClassMigrator', () {
    final converter = ClassToMixinConverter();
    final testSuggestor =
        getSuggestorTester(SimplePropsAndStateClassMigrator(converter));

    tearDown(() {
      converter.setVisitedClassNames({});
      isPublicForTest = false;
    });

    group('does not migrate when', () {
      test('its an empty file', () {
        testSuggestor(expectedPatchCount: 0, input: '');

        expect(converter.visitedClassNames, isEmpty);
      });

      test('there are no matches', () {
        testSuggestor(
          expectedPatchCount: 0,
          input: '''
        library foo;
        var a = 'b';
        class Foo {}
      ''',
        );

        expect(converter.visitedClassNames, isEmpty);
      });

      test('the component is not Component2, but does add a FIXME comment', () {
        testSuggestor(
          expectedPatchCount: 1,
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
          expectedOutput: r'''
        @Factory()
        UiFactory<FooProps> Foo =
            // ignore: undefined_identifier
            $Foo;

        // FIXME: `FooProps` could not be auto-migrated to the new over_react boilerplate 
        // because `FooComponent` does not extend from `react.Component2`.
        // 
        // Once you have upgraded the component, you can remove this FIXME comment and 
        // re-run the boilerplate migration script:
        // pub run over_react_codemod:boilerplate_upgrade
        @Props()
        class _$FooProps extends UiProps {
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

        expect(converter.visitedClassNames, {
          'FooProps': null,
        });
      });

      test('the class is a PropsMixin', () {
        testSuggestor(
          expectedPatchCount: 0,
          input: r'''
        @Factory()
        UiFactory<FooProps> Foo =
            // ignore: undefined_identifier
            $Foo;
        
        @PropsMixin()
        class FooPropsMixin {
          String foo;
          int bar;
        }

        @Props()
        class _$FooProps extends UiProps with FooPropsMixin {
          String foo;
          int bar;
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
          'FooProps': null,
        });
      });

      test('the class is publicly exported, but does add a FIXME comment', () {
        isPublicForTest = true;

        testSuggestor(
          expectedPatchCount: 1,
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
  
          @Component()
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
          class _\$FooProps extends UiProps {
            String foo;
            int bar;
          }
  
          @Component()
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
          'FooProps': null,
        });
      });

      group('the classes are not simple', () {
        test('and there are both a props and a state class', () {
          testSuggestor(
            expectedPatchCount: 0,
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
      ''',
          );

          expect(converter.visitedClassNames, {
            'FooProps': null,
            'FooState': null,
          });
        });

        test('and there is just a props class', () {
          testSuggestor(
            expectedPatchCount: 0,
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
            'FooProps': null,
          });
        });
      });
    });

    group('migrates when the classes are simple', () {
      test('and there are both a props and a state class', () {
        testSuggestor(
          expectedPatchCount: 6,
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
    
          @State()
          class _$FooState extends UiState {
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
        ''',
          expectedOutput: r'''
          @Factory()
          UiFactory<FooProps> Foo =
              // ignore: undefined_identifier
              $Foo;
    
          @Props()
          mixin FooProps on UiProps {
            String foo;
            int bar;
          }
    
          @State()
          mixin FooState on UiState {
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
        ''',
        );

        expect(converter.visitedClassNames, {
          'FooProps': 'FooProps',
          'FooState': 'FooState',
        });
      });

      test('and there is only a props class', () {
        testSuggestor(
          expectedPatchCount: 3,
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
          expectedOutput: r'''
          @Factory()
          UiFactory<FooProps> Foo =
              // ignore: undefined_identifier
              $Foo;
    
          @Props()
          mixin FooProps on UiProps {
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

        expect(converter.visitedClassNames, {
          'FooProps': 'FooProps',
        });
      });

      test('and are abstract', () {
        testSuggestor(
          expectedPatchCount: 8,
          input: r'''
          @Factory()
          UiFactory<FooProps> Foo =
              // ignore: undefined_identifier
              $Foo;
    
          @AbstractProps()
          abstract class _$FooProps extends UiProps {
            String foo;
            int bar;
          }
    
          @AbstractState()
          abstract class _$FooState extends UiState {
            String foo;
            int bar;
          }
    
          @AbstractComponent2()
          abstract class FooComponent extends UiStatefulComponent2<FooProps, FooState> {
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
    
          @AbstractProps()
          mixin FooProps on UiProps {
            String foo;
            int bar;
          }
    
          @AbstractState()
          mixin FooState on UiState {
            String foo;
            int bar;
          }
    
          @AbstractComponent2()
          abstract class FooComponent extends UiStatefulComponent2<FooProps, FooState> {
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
          'FooProps': 'FooProps',
          'FooState': 'FooState',
        });
      });
    });
  });
}

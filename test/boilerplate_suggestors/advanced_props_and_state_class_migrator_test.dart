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
    final testSuggestor =
        getSuggestorTester(AdvancedPropsAndStateClassMigrator());

    tearDown(() {
      propsAndStateClassNamesConvertedToNewBoilerplate = {};
    });

    group('does not operate when', () {
      test('it\'s an empty file', () {
        testSuggestor(expectedPatchCount: 0, input: '');

        expect(propsAndStateClassNamesConvertedToNewBoilerplate, isEmpty);
      });

      test('the class is simple', () {
        testSuggestor(
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

        expect(propsAndStateClassNamesConvertedToNewBoilerplate, isEmpty);
      });

      test(
          'the class is advanced and the classes extend from a custom class in addition to having mixins',
          () {
        testSuggestor(
          expectedPatchCount: 0,
          input: r'''
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
        ''',
        );

        expect(propsAndStateClassNamesConvertedToNewBoilerplate, isEmpty);
      });
    });

    group('operates when the classes are advanced', () {
      group('and there are both a props and a state class', () {
        test('and the classes extend from a custom class', () {
          testSuggestor(
            expectedPatchCount: 12,
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
      
              // FIXME: Verify that:
              //   1. ADifferentPropsClassMixin does not implement additional mixins.
              //   2. any other mixins found here do not implement additional mixins.
              class FooProps = UiProps with ADifferentPropsClassMixin, FooPropsMixin;
      
              @State()
              mixin FooStateMixin on UiState {
                String foo;
                int bar;
              }
              
              // FIXME: Verify that:
              //   1. ADifferentStateClassMixin does not implement additional mixins.
              //   2. any other mixins found here do not implement additional mixins.
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
          ''',
          );

          expect(propsAndStateClassNamesConvertedToNewBoilerplate, {
            'FooProps': 'FooPropsMixin',
            'FooState': 'FooStateMixin',
          });
        });

        test('and the class uses mixins', () {
          testSuggestor(
            expectedPatchCount: 12,
            input: r'''
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
          ''',
          );

          expect(propsAndStateClassNamesConvertedToNewBoilerplate, {
            'FooProps': 'FooPropsMixin',
            'FooState': 'FooStateMixin',
          });
        });
      });

      group('and there is just a props class', () {
        test('and the class does not extend from UiProps', () {
          testSuggestor(
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
            
            // FIXME: Verify that:
            //   1. ADifferentPropsClassMixin does not implement additional mixins.
            //   2. any other mixins found here do not implement additional mixins.
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

          expect(propsAndStateClassNamesConvertedToNewBoilerplate, {
            'FooProps': 'FooPropsMixin',
          });
        });

        test('and the class uses mixins', () {
          testSuggestor(
            expectedPatchCount: 6,
            input: r'''
            @Factory()
            UiFactory<FooProps> Foo =
                // ignore: undefined_identifier
                $Foo;
      
            @Props()
            class _$FooProps extends UiProps with AMixin, AnotherMixin {
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
            
            class FooProps = UiProps with FooPropsMixin, AMixin, AnotherMixin;
      
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

          expect(propsAndStateClassNamesConvertedToNewBoilerplate, {
            'FooProps': 'FooPropsMixin',
          });
        });
      });

      test(
          'and have a custom class with mixins when `shouldMigrateCustomClassAndMixins` is true',
          () {
        final testSuggestorWithFlag = getSuggestorTester(
            AdvancedPropsAndStateClassMigrator(
                shouldMigrateCustomClassAndMixins: true));

        testSuggestorWithFlag(
          expectedPatchCount: 14,
          input: r'''
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
          
          // FIXME: Verify that:
          //   1. ADifferentPropsClassMixin does not implement additional mixins.
          //   2. any other mixins found here do not implement additional mixins.          
          class FooProps = UiProps with ADifferentPropsClassMixin, FooPropsMixin, AMixin, AnotherMixin;
  
          @State()
          mixin FooStateMixin on UiState {
            String foo;
            int bar;
          }
          
          // FIXME: Verify that:
          //   1. ADifferentStateClassMixin does not implement additional mixins.
          //   2. any other mixins found here do not implement additional mixins.
          class FooState = UiState with ADifferentStateClassMixin, FooStateMixin, AStateMixin, AnotherStateMixin;
  
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

        expect(propsAndStateClassNamesConvertedToNewBoilerplate, {
          'FooProps': 'FooPropsMixin',
          'FooState': 'FooStateMixin',
        });
      });
    });
  });
}

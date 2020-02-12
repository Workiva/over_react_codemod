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
    final converter = ClassToMixinConverter();
    final testSuggestor =
        getSuggestorTester(AdvancedPropsAndStateClassMigrator(converter));

    tearDown(() {
      converter.setConvertedClassNames({});
    });

    group('does not operate when', () {
      test('it\'s an empty file', () {
        testSuggestor(expectedPatchCount: 0, input: '');

        expect(converter.convertedClassNames, isEmpty);
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

        expect(converter.convertedClassNames, isEmpty);
      });
    });

    group('operates when the classes are advanced', () {
      group('and there are both a props and a state class', () {
        test(
            'and the classes extend from custom classes that have not been converted to the new boilerplate yet',
            () {
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
      
              // FIXME:
              //   1. Ensure that all mixins used by ADifferentPropsClass are also mixed into this class.
              //   2. Fix any analyzer warnings on this class about missing mixins
              class FooProps = UiProps with ADifferentPropsClass, FooPropsMixin;
      
              @State()
              mixin FooStateMixin on UiState {
                String foo;
                int bar;
              }
              
              // FIXME:
              //   1. Ensure that all mixins used by ADifferentStateClass are also mixed into this class.
              //   2. Fix any analyzer warnings on this class about missing mixins
              class FooState = UiState with ADifferentStateClass, FooStateMixin;
      
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

          expect(converter.convertedClassNames, {
            'FooProps': 'FooPropsMixin',
            'FooState': 'FooStateMixin',
          });
        });

        test(
            'and the classes extend from custom classes that have been converted to the new boilerplate',
            () {
          converter.setConvertedClassNames({
            'ADifferentPropsClass': 'ADifferentPropsClassMixin',
            'ADifferentStateClass': 'ADifferentStateClassMixin',
          });

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
      
              // FIXME:
              //   1. Ensure that all mixins used by ADifferentPropsClassMixin are also mixed into this class.
              //   2. Fix any analyzer warnings on this class about missing mixins
              class FooProps = UiProps with ADifferentPropsClassMixin, FooPropsMixin;
      
              @State()
              mixin FooStateMixin on UiState {
                String foo;
                int bar;
              }
              
              // FIXME:
              //   1. Ensure that all mixins used by ADifferentStateClassMixin are also mixed into this class.
              //   2. Fix any analyzer warnings on this class about missing mixins
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

          expect(converter.convertedClassNames, {
            'ADifferentPropsClass': 'ADifferentPropsClassMixin',
            'ADifferentStateClass': 'ADifferentStateClassMixin',
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

          expect(converter.convertedClassNames, {
            'FooProps': 'FooPropsMixin',
            'FooState': 'FooStateMixin',
          });
        });
      });

      group('and there is just a props class', () {
        test('that extends from the reserved FluxUiProps class', () {
          testSuggestor(
            expectedPatchCount: 6,
            input: r'''
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
            //   1. Ensure that all mixins used by FluxUiPropsMixin are also mixed into this class.
            //   2. Fix any analyzer warnings on this class about missing mixins
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

          expect(converter.convertedClassNames, {
            'FooProps': 'FooPropsMixin',
          });
        });

        test('that extends from the reserved BuiltReduxUiProps class', () {
          testSuggestor(
            expectedPatchCount: 6,
            input: r'''
            @Factory()
            UiFactory<FooProps> Foo =
                // ignore: undefined_identifier
                $Foo;
    
            @Props()
            class _$FooProps extends BuiltReduxUiProps<_, __, ___> {
              String foo;
              int bar;
            }
    
            @Component2()
            class FooComponent extends BuiltReduxUiComponent2<_, __, ___, FooProps, _____> {
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
            //   1. Ensure that all mixins used by BuiltReduxUiPropsMixin are also mixed into this class.
            //   2. Fix any analyzer warnings on this class about missing mixins
            class FooProps = UiProps with BuiltReduxUiPropsMixin<_, __, ___>, FooPropsMixin;
    
            @Component2()
            class FooComponent extends BuiltReduxUiComponent2<_, __, ___, FooProps, _____> {
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

          expect(converter.convertedClassNames, {
            'FooProps': 'FooPropsMixin',
          });
        });

        test('that extends from an arbitrary custom class', () {
          converter.setConvertedClassNames({
            'ADifferentPropsClass': 'ADifferentPropsClassMixin',
          });

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
            
            // FIXME:
            //   1. Ensure that all mixins used by ADifferentPropsClassMixin are also mixed into this class.
            //   2. Fix any analyzer warnings on this class about missing mixins
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

          expect(converter.convertedClassNames, {
            'ADifferentPropsClass': 'ADifferentPropsClassMixin',
            'FooProps': 'FooPropsMixin',
          });
        });

        test('that extends from UiProps, but uses mixins', () {
          converter.setConvertedClassNames({
            'ConvertedMixin': 'ConvertedMixin',
          });

          testSuggestor(
            expectedPatchCount: 6,
            input: r'''
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
            
            class FooProps = UiProps 
                with FooPropsMixin, ConvertedMixin, UnconvertedMixin, $UnconvertedMixin;
      
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

          expect(converter.convertedClassNames, {
            'ConvertedMixin': 'ConvertedMixin',
            'FooProps': 'FooPropsMixin',
          });
        });

        group(
            'and there is already a mixin that matches the name of the class appended with "Mixin"',
            () {
          test('and the class has no members of its own', () {
            converter.setConvertedClassNames({
              'FooPropsMixin': 'FooPropsMixin',
            });

            testSuggestor(
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

            expect(converter.convertedClassNames, {
              'FooPropsMixin': 'FooPropsMixin',
              'FooProps': 'FooProps',
            });
          });

          test('and the class has members', () {
            converter.setConvertedClassNames({
              'FooPropsMixin': 'FooPropsMixin',
            });

            testSuggestor(
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
              }
              
              class FooProps extends UiProps with FooPropsMixin {
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

            expect(converter.convertedClassNames, {
              'FooPropsMixin': 'FooPropsMixin',
              'FooProps': 'FooProps',
            });
          });
        });
      });

      test(
          'and there are classes that extend from arbitrary custom classes, along with mixins',
          () {
        // Omit the state class intentionally to verify that the boilerplate
        // is not updated to point at a mixin name that is not "known" as a previously converted class.
        converter.setConvertedClassNames({
          'ADifferentPropsClass': 'ADifferentPropsClassMixin',
        });

        testSuggestor(
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
          
          // FIXME:
          //   1. Ensure that all mixins used by ADifferentPropsClassMixin are also mixed into this class.
          //   2. Fix any analyzer warnings on this class about missing mixins        
          class FooProps = UiProps with ADifferentPropsClassMixin, FooPropsMixin, AMixin, AnotherMixin;
  
          @State()
          mixin FooStateMixin on UiState {
            String foo;
            int bar;
          }
          
          // FIXME:
          //   1. Ensure that all mixins used by ADifferentStateClass are also mixed into this class.
          //   2. Fix any analyzer warnings on this class about missing mixins
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

        expect(converter.convertedClassNames, {
          'ADifferentPropsClass': 'ADifferentPropsClassMixin',
          'FooProps': 'FooPropsMixin',
          'FooState': 'FooStateMixin',
        });
      });

      group(
          'and there is a props class that extends from an arbitrary custom class, along with a mixin that has '
          'a name that matches the name of the class appended with "Mixin"',
          () {
        test('and the class has no members', () {
          converter.setConvertedClassNames({
            'ADifferentPropsClass': 'ADifferentPropsClassMixin',
            'FooPropsMixin': 'FooPropsMixin',
          });

          testSuggestor(
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
            //   1. Ensure that all mixins used by ADifferentPropsClassMixin are also mixed into this class.
            //   2. Fix any analyzer warnings on this class about missing mixins        
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

          expect(converter.convertedClassNames, {
            'ADifferentPropsClass': 'ADifferentPropsClassMixin',
            'FooPropsMixin': 'FooPropsMixin',
            'FooProps': 'FooProps',
          });
        });

        test('and the class has members', () {
          converter.setConvertedClassNames({
            'ADifferentPropsClass': 'ADifferentPropsClassMixin',
            'FooPropsMixin': 'FooPropsMixin',
          });

          testSuggestor(
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
            }
            
            // FIXME:
            //   1. Ensure that all mixins used by ADifferentPropsClassMixin are also mixed into this class.
            //   2. Fix any analyzer warnings on this class about missing mixins        
            class FooProps extends UiProps with ADifferentPropsClassMixin, FooPropsMixin {
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

          expect(converter.convertedClassNames, {
            'ADifferentPropsClass': 'ADifferentPropsClassMixin',
            'FooPropsMixin': 'FooPropsMixin',
            'FooProps': 'FooProps',
          });
        });
      });
    });
  });
}

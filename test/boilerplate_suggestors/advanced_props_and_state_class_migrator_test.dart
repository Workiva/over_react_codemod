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
import 'package:over_react_codemod/src/boilerplate_suggestors/boilerplate_constants.dart';
import 'package:over_react_codemod/src/boilerplate_suggestors/boilerplate_utilities.dart';
import 'package:test/test.dart';

import '../util.dart';

void main() {
  group('AdvancedPropsAndStateClassMigrator', () {
    group('', () {
      AdvancedPropsAndStateClassMigratorTestHelper(
        path: 'test/boilerplate_suggestors/semver_report.json',
        shouldTreatAllComponentsAsPrivate: false,
        isValidFilePath: true,
      );
    });

    group('with --treat-all-components-as-private flag', () {
      AdvancedPropsAndStateClassMigratorTestHelper(
        path: 'test/boilerplate_suggestors/semver_report.json',
        shouldTreatAllComponentsAsPrivate: true,
        isValidFilePath: true,
      );
    });

    group('with invalid file path', () {
      AdvancedPropsAndStateClassMigratorTestHelper(
        path: 'test/boilerplate_suggestors/does_not_exist.json',
        shouldTreatAllComponentsAsPrivate: false,
        isValidFilePath: false,
      );
    });
  });
}

void AdvancedPropsAndStateClassMigratorTestHelper({
  String path,
  bool shouldTreatAllComponentsAsPrivate,
  bool isValidFilePath,
}) {
  final converter = ClassToMixinConverter();
  final semverHelper = getSemverHelper(path,
      shouldTreatAllComponentsAsPrivate: shouldTreatAllComponentsAsPrivate);
  SuggestorTester testSuggestor;

  setUpAll(() async {
    testSuggestor = getSuggestorTester(
        AdvancedPropsAndStateClassMigrator(converter, await semverHelper));
  });

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

    test('advanced classes are public API', () {
      testSuggestor(
        expectedPatchCount: shouldTreatAllComponentsAsPrivate ? 10 : 2,
        input: r'''
            @Factory()
            UiFactory<BarProps> Bar =
                // ignore: undefined_identifier
                $Bar;

            @Props()
            class BarProps extends ADifferentPropsClass {
              String foo;
              int bar;
            }

            @State()
            class BarState extends ADifferentStateClass {
              String foo;
              int bar;
            }

            @Component2()
            class BarComponent extends UiStatefulComponent2<BarProps, BarState> {
              @override
              render() {
                return Dom.ul()(
                  Dom.li()('Foo: ', props.foo),
                  Dom.li()('Bar: ', props.bar),
                );
              }
            }
          ''',
        expectedOutput: shouldTreatAllComponentsAsPrivate
            ? r'''
            @Factory()
              UiFactory<BarProps> Bar =
                  // ignore: undefined_identifier
                  $Bar;

              @Props()
              mixin BarPropsMixin on UiProps {
                String foo;
                int bar;
              }

              // FIXME:
              //   1. Ensure that all mixins used by ADifferentPropsClass are also mixed into this class.
              //   2. Fix any analyzer warnings on this class about missing mixins
              class BarProps = UiProps with ADifferentPropsClassMixin, BarPropsMixin;

              @State()
              mixin BarStateMixin on UiState {
                String foo;
                int bar;
              }

              // FIXME:
              //   1. Ensure that all mixins used by ADifferentStateClass are also mixed into this class.
              //   2. Fix any analyzer warnings on this class about missing mixins
              class BarState = UiState with ADifferentStateClassMixin, BarStateMixin;

              @Component2()
              class BarComponent extends UiStatefulComponent2<BarProps, BarState> {
                @override
                render() {
                  return Dom.ul()(
                    Dom.li()('Foo: ', props.foo),
                    Dom.li()('Bar: ', props.bar),
                  );
                }
              }
          '''
            : '''
            @Factory()
            UiFactory<BarProps> Bar =
                // ignore: undefined_identifier
                \$Bar;

            ${exportLocationsComment([
                isValidFilePath
                    ? 'lib/web_skin_dart.dart/BarProps'
                    : reportNotAvailableComment
              ])}
            @Props()
            class BarProps extends ADifferentPropsClass {
              String foo;
              int bar;
            }

            ${exportLocationsComment([
                isValidFilePath
                    ? 'lib/web_skin_dart.dart/BarState'
                    : reportNotAvailableComment
              ])}
            @State()
            class BarState extends ADifferentStateClass {
              String foo;
              int bar;
            }

            @Component2()
            class BarComponent extends UiStatefulComponent2<BarProps, BarState> {
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
          converter.convertedClassNames,
          shouldTreatAllComponentsAsPrivate
              ? {
                  'BarProps': 'BarPropsMixin',
                  'BarState': 'BarStateMixin',
                }
              : {});
    });
  });

  group('operates when the classes are advanced', () {
    group('and there are both a props and a state class', () {
      test('and the classes extend from a custom class', () {
        testSuggestor(
          expectedPatchCount: isValidFilePath ? 12 : 2,
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
          expectedOutput: isValidFilePath
              ? r'''
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
              class FooProps = UiProps with ADifferentPropsClassMixin, FooPropsMixin;
      
              @State()
              mixin FooStateMixin on UiState {
                String foo;
                int bar;
              }
              
              // FIXME:
              //   1. Ensure that all mixins used by ADifferentStateClass are also mixed into this class.
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
          '''
              : '''
            @Factory()
            UiFactory<FooProps> Foo =
                // ignore: undefined_identifier
                \$Foo;
    
            ${exportLocationsComment([reportNotAvailableComment])}
            @Props()
            class _\$FooProps extends ADifferentPropsClass {
              String foo;
              int bar;
            }
    
            ${exportLocationsComment([reportNotAvailableComment])}
            @State()
            class _\$FooState extends ADifferentStateClass {
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

        expect(
            converter.convertedClassNames,
            isValidFilePath
                ? {
                    'FooProps': 'FooPropsMixin',
                    'FooState': 'FooStateMixin',
                  }
                : {});
      });

      test('and the class uses mixins', () {
        testSuggestor(
          expectedPatchCount: isValidFilePath ? 12 : 2,
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
          expectedOutput: isValidFilePath
              ? r'''
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
          '''
              : '''
            @Factory()
            UiFactory<FooProps> Foo =
                // ignore: undefined_identifier
                \$Foo;
            
            ${exportLocationsComment([reportNotAvailableComment])}
            @Props()
            class _\$FooProps extends UiProps with AMixin, AnotherMixin {
              String foo;
              int bar;
            }
            
            ${exportLocationsComment([reportNotAvailableComment])}
            @State()
            class _\$FooState extends UiState with AStateMixin, AnotherStateMixin {
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

        expect(
            converter.convertedClassNames,
            isValidFilePath
                ? {
                    'FooProps': 'FooPropsMixin',
                    'FooState': 'FooStateMixin',
                  }
                : {});
      });
    });

    group('and there is just a props class', () {
      test('and the class does not extend from UiProps', () {
        testSuggestor(
          expectedPatchCount: isValidFilePath ? 6 : 1,
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
          expectedOutput: isValidFilePath
              ? r'''
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
          '''
              : '''
            @Factory()
            UiFactory<FooProps> Foo =
                // ignore: undefined_identifier
                \$Foo;
      
            ${exportLocationsComment([reportNotAvailableComment])}
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
          ''',
        );

        expect(
            converter.convertedClassNames,
            isValidFilePath
                ? {
                    'FooProps': 'FooPropsMixin',
                  }
                : {});
      });

      test('and the class uses mixins', () {
        testSuggestor(
          expectedPatchCount: isValidFilePath ? 6 : 1,
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
          expectedOutput: isValidFilePath
              ? r'''
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
          '''
              : '''
            @Factory()
            UiFactory<FooProps> Foo =
                // ignore: undefined_identifier
                \$Foo;
      
            ${exportLocationsComment([reportNotAvailableComment])}
            @Props()
            class _\$FooProps extends UiProps with AMixin, AnotherMixin {
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

        expect(
            converter.convertedClassNames,
            isValidFilePath
                ? {
                    'FooProps': 'FooPropsMixin',
                  }
                : {});
      });
    });

    test('and there is a custom class with mixins', () {
      testSuggestor(
        expectedPatchCount: isValidFilePath ? 14 : 2,
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
        expectedOutput: isValidFilePath
            ? r'''
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
          class FooProps = UiProps with ADifferentPropsClassMixin, FooPropsMixin, AMixin, AnotherMixin;
  
          @State()
          mixin FooStateMixin on UiState {
            String foo;
            int bar;
          }
          
          // FIXME:
          //   1. Ensure that all mixins used by ADifferentStateClass are also mixed into this class.
          //   2. Fix any analyzer warnings on this class about missing mixins
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
        '''
            : '''
          @Factory()
          UiFactory<FooProps> Foo =
              // ignore: undefined_identifier
              \$Foo;
          
          ${exportLocationsComment([reportNotAvailableComment])}
          @Props()
          class _\$FooProps extends ADifferentPropsClass with AMixin, AnotherMixin {
            String foo;
            int bar;
          }
          
          ${exportLocationsComment([reportNotAvailableComment])}
          @State()
          class _\$FooState extends ADifferentStateClass with AStateMixin, AnotherStateMixin {
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

      expect(
          converter.convertedClassNames,
          isValidFilePath
              ? {
                  'FooProps': 'FooPropsMixin',
                  'FooState': 'FooStateMixin',
                }
              : {});
    });
  });
}

String exportLocationsComment(List<String> locations) =>
    '// This class was not updated because it was exported from: $locations';

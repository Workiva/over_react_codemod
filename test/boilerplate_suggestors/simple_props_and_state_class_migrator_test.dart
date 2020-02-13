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

import 'package:over_react_codemod/src/boilerplate_suggestors/boilerplate_constants.dart';
import 'package:over_react_codemod/src/boilerplate_suggestors/boilerplate_utilities.dart';
import 'package:over_react_codemod/src/boilerplate_suggestors/simple_props_and_state_class_migrator.dart';
import 'package:test/test.dart';

import '../util.dart';
import 'advanced_props_and_state_class_migrator_test.dart';

void main() {
  group('SimplePropsAndStateClassMigrator', () {
    group('', () {
      SimplePropsAndStateClassMigratorTestHelper(
        path: 'test/boilerplate_suggestors/semver_report.json',
        shouldTreatAllComponentsAsPrivate: false,
        isValidFilePath: true,
      );
    });

    group('with --treat-all-components-as-private flag', () {
      SimplePropsAndStateClassMigratorTestHelper(
        path: 'test/boilerplate_suggestors/semver_report.json',
        shouldTreatAllComponentsAsPrivate: true,
        isValidFilePath: true,
      );
    });

    group('with invalid file path', () {
      SimplePropsAndStateClassMigratorTestHelper(
        path: 'test/boilerplate_suggestors/does_not_exist.json',
        shouldTreatAllComponentsAsPrivate: false,
        isValidFilePath: false,
      );
    });
  });
}

void SimplePropsAndStateClassMigratorTestHelper({
  String path,
  bool shouldTreatAllComponentsAsPrivate,
  bool isValidFilePath,
}) {
  final converter = ClassToMixinConverter();
  SuggestorTester testSuggestor;

  setUpAll(() async {
    testSuggestor = getSuggestorTester(SimplePropsAndStateClassMigrator(
        converter,
        await getSemverHelper(path,
            shouldTreatAllComponentsAsPrivate:
                shouldTreatAllComponentsAsPrivate)));
  });

  tearDown(() {
    converter.setConvertedClassNames({});
  });

  group('does not run when', () {
    test('its an empty file', () {
      testSuggestor(expectedPatchCount: 0, input: '');

      expect(converter.convertedClassNames, isEmpty);
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

      expect(converter.convertedClassNames, isEmpty);
    });

    test('the component is not Component2', () {
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
  
          @Component()
          class FooComponent extends UiComponent<FooProps, FooState> {
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

      expect(converter.convertedClassNames, isEmpty);
    });

    test('when the props class is publicly exported', () {
      testSuggestor(
        expectedPatchCount: shouldTreatAllComponentsAsPrivate ? 2 : 1,
        input: r'''
          @Factory()
          UiFactory<ButtonProps> Button =
              // ignore: undefined_identifier
              $Button;
    
          @Props()
          class ButtonProps extends UiProps {
            String foo;
            int bar;
          }
    
          @Component2()
          class ButtonComponent extends UiComponent2<ButtonProps> {
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
            UiFactory<ButtonProps> Button =
                // ignore: undefined_identifier
                $Button;
    
            @Props()
            mixin ButtonProps on UiProps {
              String foo;
              int bar;
            }
      
            @Component2()
            class ButtonComponent extends UiComponent2<ButtonProps> {
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
            UiFactory<ButtonProps> Button =
                // ignore: undefined_identifier
                \$Button;
      
            ${exportLocationsComment(isValidFilePath ? [
                'lib/web_skin_dart.dart/ButtonProps',
                'lib/another_file.dart/ButtonProps'
              ] : [reportNotAvailableComment])}
            @Props()
            class ButtonProps extends UiProps {
              String foo;
              int bar;
            }
      
            @Component2()
            class ButtonComponent extends UiComponent2<ButtonProps> {
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
              ? {'ButtonProps': 'ButtonProps'}
              : isEmpty);
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

        expect(converter.convertedClassNames, isEmpty);
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

        expect(converter.convertedClassNames, isEmpty);
      });
    });
  });

  group('runs when the classes are simple', () {
    test('and there are both a props and a state class', () {
      testSuggestor(
        expectedPatchCount: isValidFilePath ? 6 : 2,
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
        expectedOutput: isValidFilePath
            ? r'''
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
        '''
            : '''
          @Factory()
          UiFactory<FooProps> Foo =
              // ignore: undefined_identifier
              \$Foo;
          
          ${exportLocationsComment([reportNotAvailableComment])}
          @Props()
          class _\$FooProps extends UiProps {
            String foo;
            int bar;
          }
          
          ${exportLocationsComment([reportNotAvailableComment])}
          @State()
          class _\$FooState extends UiState {
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
                  'FooProps': 'FooProps',
                  'FooState': 'FooState',
                }
              : isEmpty);
    });

    test('and there is only a props class', () {
      testSuggestor(
        expectedPatchCount: isValidFilePath ? 3 : 1,
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
        expectedOutput: isValidFilePath
            ? r'''
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
        '''
            : '''
          @Factory()
          UiFactory<FooProps> Foo =
              // ignore: undefined_identifier
              \$Foo;
    
          ${exportLocationsComment([reportNotAvailableComment])}
          @Props()
          class _\$FooProps extends UiProps {
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
                  'FooProps': 'FooProps',
                }
              : isEmpty);
    });

    test('and are abstract', () {
      testSuggestor(
        expectedPatchCount: isValidFilePath ? 8 : 2,
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
        expectedOutput: isValidFilePath
            ? r'''
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
          '''
            : '''
          @Factory()
          UiFactory<FooProps> Foo =
              // ignore: undefined_identifier
              \$Foo;
    
          ${exportLocationsComment([reportNotAvailableComment])}
          @AbstractProps()
          abstract class _\$FooProps extends UiProps {
            String foo;
            int bar;
          }
    
          ${exportLocationsComment([reportNotAvailableComment])}
          @AbstractState()
          abstract class _\$FooState extends UiState {
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

      expect(
          converter.convertedClassNames,
          isValidFilePath
              ? {
                  'FooProps': 'FooProps',
                  'FooState': 'FooState',
                }
              : isEmpty);
    });
  });
}

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

import 'dart:convert';
import 'dart:io';

import 'package:over_react_codemod/src/boilerplate_suggestors/boilerplate_utilities.dart';
import 'package:over_react_codemod/src/boilerplate_suggestors/simple_props_and_state_class_migrator.dart';
import 'package:test/test.dart';

import '../util.dart';

main() {
  group('SimplePropsAndStateClassMigrator', () {
    SuggestorTester testSuggestor;

    setUpAll(() async {
      final helper = SemverHelper(jsonDecode(
          await File('test/boilerplate_suggestors/report.json')
              .readAsString()));

      testSuggestor =
          getSuggestorTester(SimplePropsAndStateClassMigrator(helper));
    });

    tearDown(() {
      propsAndStateClassNamesConvertedToNewBoilerplate = {};
    });

    test('empty file', () {
      testSuggestor(expectedPatchCount: 0, input: '');

      expect(propsAndStateClassNamesConvertedToNewBoilerplate, isEmpty);
    });

    test('no matches', () {
      testSuggestor(
        expectedPatchCount: 0,
        input: '''
        library foo;
        var a = 'b';
        class Foo {}
      ''',
      );

      expect(propsAndStateClassNamesConvertedToNewBoilerplate, isEmpty);
    });

    test('and the component is not Component2', () {
      testSuggestor(
        expectedPatchCount: 0,
        input: '''
        @Factory()
        UiFactory<FooProps> Foo =
            // ignore: undefined_identifier
            \$Foo;

        @Props()
        class _\$FooProps extends UiProps {
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

      expect(propsAndStateClassNamesConvertedToNewBoilerplate, isEmpty);
    });

    // TODO add a test for when the class is publicly exported

    group('when the classes are not simple', () {
      test('and there are both a props and a state class', () {
        testSuggestor(
          expectedPatchCount: 0,
          input: '''
        @Factory()
        UiFactory<FooProps> Foo =
            // ignore: undefined_identifier
            \$Foo;

        @Props()
        class _\$FooProps extends ADifferentPropsClass {
          String foo;
          int bar;
        }

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

        expect(propsAndStateClassNamesConvertedToNewBoilerplate, isEmpty);
      });

      test('and there is just a props class', () {
        testSuggestor(
          expectedPatchCount: 0,
          input: '''
        @Factory()
        UiFactory<FooProps> Foo =
            // ignore: undefined_identifier
            \$Foo;

        @Props()
        class _\$FooProps extends ADifferentPropsClass {
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

        expect(propsAndStateClassNamesConvertedToNewBoilerplate, isEmpty);
      });
    });

    group('when the classes are simple', () {
      test('and there are both a props and a state class', () {
        testSuggestor(
          expectedPatchCount: 6,
          input: '''
          @Factory()
          UiFactory<FooProps> Foo =
              // ignore: undefined_identifier
              \$Foo;
    
          @Props()
          class _\$FooProps extends UiProps {
            String foo;
            int bar;
          }
    
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
          expectedOutput: '''
          @Factory()
          UiFactory<FooProps> Foo =
              // ignore: undefined_identifier
              \$Foo;
    
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

        expect(propsAndStateClassNamesConvertedToNewBoilerplate, {
          'FooProps': 'FooProps',
          'FooState': 'FooState',
        });
      });

      test('and there is only a props class', () {
        testSuggestor(
          expectedPatchCount: 3,
          input: '''
          @Factory()
          UiFactory<FooProps> Foo =
              // ignore: undefined_identifier
              \$Foo;
    
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
          expectedOutput: '''
          @Factory()
          UiFactory<FooProps> Foo =
              // ignore: undefined_identifier
              \$Foo;
    
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

        expect(propsAndStateClassNamesConvertedToNewBoilerplate, {
          'FooProps': 'FooProps',
        });
      });

      test('and are abstract', () {
        testSuggestor(
          expectedPatchCount: 8,
          input: '''
          @Factory()
          UiFactory<FooProps> Foo =
              // ignore: undefined_identifier
              \$Foo;
    
          @AbstractProps()
          abstract class _\$FooProps extends UiProps {
            String foo;
            int bar;
          }
    
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
          expectedOutput: '''
          @Factory()
          UiFactory<FooProps> Foo =
              // ignore: undefined_identifier
              \$Foo;
    
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

        expect(propsAndStateClassNamesConvertedToNewBoilerplate, {
          'FooProps': 'FooProps',
          'FooState': 'FooState',
        });
      });
    });
  });
}

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
import 'package:over_react_codemod/src/boilerplate_suggestors/stubbed_props_and_state_class_remover.dart';
import 'package:test/test.dart';

import '../util.dart';

main() {
  group('StubbedPropsAndStateClassRemover', () {
    final testSuggestor = getSuggestorTester(
      StubbedPropsAndStateClassRemover(),
    );

    setUpAll(() async {
      semverHelper = SemverHelper(jsonDecode(
          await File('test/boilerplate_suggestors/report.json')
              .readAsString()));
    });

    group('does not perform a migration', () {
      test('when it encounters an empty file', () {
        testSuggestor(expectedPatchCount: 0, input: '');
      });

      test('when there are no stubbed "companion" classes found', () {
        testSuggestor(
          expectedPatchCount: 0,
          input: '''
          library foo;
          var a = 'b';
          class Foo {}
        ''',
        );
      });

      test(
          'when the stubbed "companion" class(es) are not associated with a UiComponent2 instance',
          () {
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
          
          // AF-3369 This will be removed once the transition to Dart 2 is complete.
          // ignore: mixin_of_non_class, undefined_class
          class FooProps extends _\$FooProps with _\$FooPropsAccessorsMixin {
            // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
            static const PropsMeta meta = _\$metaForFooProps;
          }
        ''',
        );
      });

      test(
          'when the class inheritance is advanced and unable able to be migrated',
          () {
        // TODO add a test for when the class is advanced and unable to be migrated
      });

      test('when the stubbed "companion" class(es) are publicly exported', () {
        testSuggestor(
          expectedPatchCount: 0,
          input: '''
          @Factory()
          UiFactory<BarProps> Bar =
              // ignore: undefined_identifier
              \$Bar;
      
          @Props()
          class _\$_BarProps extends UiProps {
            String foo;
            int bar;
          }
      
          @Component2()
          class BarComponent extends UiComponent2<BarProps> {
            @override
            render() {
              return Dom.ul()(
                Dom.li()('Foo: ', props.foo),
                Dom.li()('Bar: ', props.bar),
              );
            }
          }
          
          // AF-3369 This will be removed once the transition to Dart 2 is complete.
          // ignore: mixin_of_non_class, undefined_class
          class BarProps extends _\$_BarProps with _\$_BarPropsAccessorsMixin {
            // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
            static const PropsMeta meta = _\$metaFor_BarProps;
          }
        ''',
        );
      });
    });

    group('performs a migration', () {
      test(
          'when the class inheritance is advanced, but still able to be migrated',
          () {
        // TODO add a test for when the class is advanced, but still able to be migrated
      });

      test('when the class inheritance is simple (private)', () {
        testSuggestor(
          expectedPatchCount: 2,
          input: '''
          @Factory()
          UiFactory<FooProps> Foo =
              // ignore: undefined_identifier
              \$Foo;
      
          @Props()
          class _\$_FooProps extends UiProps {
            String foo;
            int bar;
          }
      
          @State()
          class _\$_FooState extends UiState {
            String foo;
            int bar;
          }
      
          @Component2()
          class FooComponent extends UiStatefulComponent2<_FooProps, _FooState> {
            @override
            render() {
              return Dom.ul()(
                Dom.li()('Foo: ', props.foo),
                Dom.li()('Bar: ', props.bar),
              );
            }
          }
          
          // AF-3369 This will be removed once the transition to Dart 2 is complete.
          // ignore: mixin_of_non_class, undefined_class
          class _FooProps extends _\$_FooProps with _\$_FooPropsAccessorsMixin {
            // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
            static const PropsMeta meta = _\$metaFor_FooProps;
          }
          
          // AF-3369 This will be removed once the transition to Dart 2 is complete.
          // ignore: mixin_of_non_class, undefined_class
          class _FooState extends _\$_FooState with _\$_FooStateAccessorsMixin {
            // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
            static const StateMeta meta = _\$metaFor_FooState;
          }
        ''',
          expectedOutput: '''
          @Factory()
          UiFactory<FooProps> Foo =
              // ignore: undefined_identifier
              \$Foo;
      
          @Props()
          class _\$_FooProps extends UiProps {
            String foo;
            int bar;
          }
      
          @State()
          class _\$_FooState extends UiState {
            String foo;
            int bar;
          }
      
          @Component2()
          class FooComponent extends UiStatefulComponent2<_FooProps, _FooState> {
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
      });

      test('when the class inheritance is simple (public)', () {
        testSuggestor(
          expectedPatchCount: 2,
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
          
          // AF-3369 This will be removed once the transition to Dart 2 is complete.
          // ignore: mixin_of_non_class, undefined_class
          class FooProps extends _\$FooProps with _\$FooPropsAccessorsMixin {
            // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
            static const PropsMeta meta = _\$metaForFooProps;
          }
          
          // AF-3369 This will be removed once the transition to Dart 2 is complete.
          // ignore: mixin_of_non_class, undefined_class
          class FooState extends _\$FooState with _\$FooStateAccessorsMixin {
            // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
            static const StateMeta meta = _\$metaForFooState;
          }
        ''',
          expectedOutput: '''
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
        );
      });
    });
  });
}

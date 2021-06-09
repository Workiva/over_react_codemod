// @dart=2.7
// ^ Do not remove until migrated to null safety. More info at https://wiki.atl.workiva.net/pages/viewpage.action?pageId=189370832
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
import 'package:over_react_codemod/src/boilerplate_suggestors/stubbed_props_and_state_class_remover.dart';
import 'package:test/test.dart';

import '../util.dart';

main() {
  group('StubbedPropsAndStateClassRemover', () {
    final converter = ClassToMixinConverter();
    final testSuggestor = getSuggestorTester(
      StubbedPropsAndStateClassRemover(converter),
    );

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

      test('when the class was unable able to be migrated', () {
        // The empty value of converter.visitedClassNames
        // will signify that FooProps / FooState were not converted
        testSuggestor(
          expectedPatchCount: 0,
          input: r'''
          @Factory()
          UiFactory<FooProps> Foo =
              // ignore: undefined_identifier
              $Foo;
      
          @Props()
          class _$FooProps extends SomeCustomExternalPropsClass {
            String foo;
            int bar;
          }
      
          @State()
          class _$FooState extends SomeCustomExternalStateClass {
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
          class FooProps extends _$FooProps with _$FooPropsAccessorsMixin {
            // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
            static const PropsMeta meta = _$metaForFooProps;
          }
          
          // AF-3369 This will be removed once the transition to Dart 2 is complete.
          // ignore: mixin_of_non_class, undefined_class
          class FooState extends _$FooState with _$FooStateAccessorsMixin {
            // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
            static const StateMeta meta = _$metaForFooState;
          }
        ''',
        );
      });
    });

    group('performs a migration', () {
      test('when the analogous private class has been migrated (simple)', () {
        converter.setVisitedNames({
          'FooProps': 'FooProps',
          'FooState': 'FooState',
        });
        testSuggestor(
          expectedPatchCount: 2,
          input: r'''
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
          
          // AF-3369 This will be removed once the transition to Dart 2 is complete.
          // ignore: mixin_of_non_class, undefined_class
          class FooProps extends _$FooProps with _$FooPropsAccessorsMixin {
            // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
            static const PropsMeta meta = _$metaForFooProps;
          }
          
          // AF-3369 This will be removed once the transition to Dart 2 is complete.
          // ignore: mixin_of_non_class, undefined_class
          class FooState extends _$FooState with _$FooStateAccessorsMixin {
            // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
            static const StateMeta meta = _$metaForFooState;
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
      });

      test('when the analogous private class has been migrated (advanced)', () {
        converter.setVisitedNames({
          'FooProps': 'FooPropsMixin',
          'FooState': 'FooStateMixin',
        });
        testSuggestor(
          expectedPatchCount: 2,
          input: r'''
          @Factory()
          UiFactory<FooProps> Foo =
              // ignore: undefined_identifier
              $Foo;
      
          mixin FooPropsMixin on UiProps {
            String foo;
            int bar;
          }
      
          @Props()    
          class FooProps = UiProps with FooPropsMixin, SomeOtherPropsMixin;
      
          mixin FooStateMixin on UiState {
            String foo;
            int bar;
          }
      
          @State()    
          class FooState = UiProps with FooPropsMixin, SomeOtherStateMixin;
      
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
          class FooProps extends _$FooProps with _$FooPropsAccessorsMixin {
            // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
            static const PropsMeta meta = _$metaForFooProps;
          }
          
          // AF-3369 This will be removed once the transition to Dart 2 is complete.
          // ignore: mixin_of_non_class, undefined_class
          class FooState extends _$FooState with _$FooStateAccessorsMixin {
            // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
            static const StateMeta meta = _$metaForFooState;
          }
        ''',
          expectedOutput: r'''
          @Factory()
          UiFactory<FooProps> Foo =
              // ignore: undefined_identifier
              $Foo;
      
          mixin FooPropsMixin on UiProps {
            String foo;
            int bar;
          }
      
          @Props()    
          class FooProps = UiProps with FooPropsMixin, SomeOtherPropsMixin;
      
          mixin FooStateMixin on UiState {
            String foo;
            int bar;
          }
      
          @State()    
          class FooState = UiProps with FooPropsMixin, SomeOtherStateMixin;
      
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

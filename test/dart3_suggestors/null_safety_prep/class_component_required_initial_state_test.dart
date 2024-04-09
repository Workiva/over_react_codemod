// Copyright 2024 Workiva Inc.
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

import 'package:over_react_codemod/src/dart3_suggestors/null_safety_prep/class_component_required_initial_state.dart';
import 'package:test/test.dart';

import '../../resolved_file_context.dart';
import '../../util.dart';
import '../../util/component_usage_migrator_test.dart' show withOverReactImport;

void main() {
  final resolvedContext = SharedAnalysisContext.overReact;

  // Warm up analysis in a setUpAll so that if getting the resolved AST times out
  // (which is more common for the WSD context), it fails here instead of failing the first test.
  setUpAll(resolvedContext.warmUpAnalysis);

  group('ClassComponentRequiredInitialStateMigrator', () {
    late SuggestorTester testSuggestor;

    group('when sdkVersion is not set', () {
      setUp(() {
        testSuggestor = getSuggestorTester(
          ClassComponentRequiredInitialStateMigrator(),
          resolvedContext: resolvedContext,
        );
      });

      test('patches initialized state fields in mixins', () async {
        await testSuggestor(
          expectedPatchCount: 5,
          input: withOverReactImport(/*language=dart*/ r'''
            // ignore: undefined_identifier
            UiFactory<FooProps> Foo = castUiFactory(_$Foo);
            mixin FooProps on UiProps {}
            mixin FooStateMixin on UiState {
              String notInitialized;
              /*late*/ String/*!*/ alreadyPatched;
              String initializedNullable;
              num initializedNonNullable;
            }
            mixin SomeOtherStateMixin on UiState {
              num anotherInitializedNonNullable;
              Function initializedNonNullableFn;
              List<num> initializedNonNullableList;
            }
            class FooState = UiState with FooStateMixin, SomeOtherStateMixin;
            class FooComponent extends UiStatefulComponent2<FooProps, FooState> {
              @override
              get initialState => (newState()
                ..alreadyPatched = 'foo'
                ..initializedNullable = null
                ..initializedNonNullable = 2.1
                ..anotherInitializedNonNullable = 1.1
                ..initializedNonNullableFn = () {}
                ..initializedNonNullableList = []
              );
            
              @override
              render() => null;
            }
            
            @Factory()
            UiFactory<FooProps> FooLegacy = _$FooLegacy; // ignore: undefined_identifier
            @Component()
            class FooLegacyComponent extends UiStatefulComponent<FooProps, FooState> {
              @override
              getInitialState() => (newState()
                ..alreadyPatched = 'foo'
                ..initializedNullable = null
                ..initializedNonNullable = 2.1
                ..anotherInitializedNonNullable = 1.1
                ..initializedNonNullableFn = () {}
                ..initializedNonNullableList = []
              );
            
              @override
              render() => null;
            }
          '''),
          expectedOutput: withOverReactImport(/*language=dart*/ r'''
            // ignore: undefined_identifier
            UiFactory<FooProps> Foo = castUiFactory(_$Foo);
            mixin FooProps on UiProps {}
            mixin FooStateMixin on UiState {
              String notInitialized;
              /*late*/ String/*!*/ alreadyPatched;
              /*late*/ String/*?*/ initializedNullable;
              /*late*/ num/*!*/ initializedNonNullable;
            }
            mixin SomeOtherStateMixin on UiState {
              /*late*/ num/*!*/ anotherInitializedNonNullable;
              /*late*/ Function/*!*/ initializedNonNullableFn;
              /*late*/ List<num>/*!*/ initializedNonNullableList;
            }
            class FooState = UiState with FooStateMixin, SomeOtherStateMixin;
            class FooComponent extends UiStatefulComponent2<FooProps, FooState> {
              @override
              get initialState => (newState()
                ..alreadyPatched = 'foo'
                ..initializedNullable = null
                ..initializedNonNullable = 2.1
                ..anotherInitializedNonNullable = 1.1
                ..initializedNonNullableFn = () {}
                ..initializedNonNullableList = []
              );
            
              @override
              render() => null;
            }
            
            @Factory()
            UiFactory<FooProps> FooLegacy = _$FooLegacy; // ignore: undefined_identifier
            @Component()
            class FooLegacyComponent extends UiStatefulComponent<FooProps, FooState> {
              @override
              getInitialState() => (newState()
                ..alreadyPatched = 'foo'
                ..initializedNullable = null
                ..initializedNonNullable = 2.1
                ..anotherInitializedNonNullable = 1.1
                ..initializedNonNullableFn = () {}
                ..initializedNonNullableList = []
              );
            
              @override
              render() => null;
            }
          '''),
        );
      });

      test('patches initialized state in legacy classes', () async {
        await testSuggestor(
          expectedPatchCount: 3,
          input: withOverReactImport(/*language=dart*/ r'''
            @Factory()
            UiFactory<FooProps> Foo = _$Foo; // ignore: undefined_identifier
            @Props()
            class FooProps extends UiProps {}
            @StateMixin()
            mixin SomeOtherStateMixin on UiState {
              num anotherInitializedNonNullable;
            }
            @State()
            class FooState extends UiState with SomeOtherStateMixin {
              String notInitialized;
              String initializedNullable;
              num initializedNonNullable;
            }
            @Component()
            class FooComponent extends UiStatefulComponent<FooProps, FooState> {
              @override
              getInitialState() => (newState()
                ..initializedNullable = null
                ..initializedNonNullable = 2.1
                ..anotherInitializedNonNullable = 1.1
              );
            
              @override
              render() => null;
            }
          '''),
          expectedOutput: withOverReactImport(/*language=dart*/ r'''
            @Factory()
            UiFactory<FooProps> Foo = _$Foo; // ignore: undefined_identifier
            @Props()
            class FooProps extends UiProps {}
            @StateMixin()
            mixin SomeOtherStateMixin on UiState {
              /*late*/ num/*!*/ anotherInitializedNonNullable;
            }
            @State()
            class FooState extends UiState with SomeOtherStateMixin {
              String notInitialized;
              /*late*/ String/*?*/ initializedNullable;
              /*late*/ num/*!*/ initializedNonNullable;
            }
            @Component()
            class FooComponent extends UiStatefulComponent<FooProps, FooState> {
              @override
              getInitialState() => (newState()
                ..initializedNullable = null
                ..initializedNonNullable = 2.1
                ..anotherInitializedNonNullable = 1.1
              );
            
              @override
              render() => null;
            }
          '''),
        );
      });

      test('patches defaulted props in legacy classes using component1 boilerplate', () async {
        await testSuggestor(
          expectedPatchCount: 2,
          input: withOverReactImport(/*language=dart*/ r'''
            @Factory()
            UiFactory<FooProps> Foo = _$Foo; // ignore: undefined_identifier
            @Props()
            class _$FooProps extends UiProps {}
            @State()
            class _$FooState extends UiState {
              String notInitialized;
              String initializedNullable;
              num initializedNonNullable;
            }
            @Component()
            class FooComponent extends UiStatefulComponent<FooProps, FooState> {
              @override
              getInitialState() => (newState()
                ..initializedNullable = null
                ..initializedNonNullable = 2.1
              );
            
              @override
              render() => null;
            }
            class FooProps extends _$FooProps
                with
                    // ignore: mixin_of_non_class, undefined_class
                    _$FooPropsAccessorsMixin {
              // ignore: const_initialized_with_non_constant_value, undefined_class, undefined_identifier
              static const PropsMeta meta = _$metaForFooProps;
            }
            class FooState extends _$FooState
                with
                    // ignore: mixin_of_non_class, undefined_class
                    _$FooStateAccessorsMixin {
              // ignore: const_initialized_with_non_constant_value, undefined_class, undefined_identifier
              static const StateMeta meta = _$metaForFooState;
            }
            abstract class _$FooStateAccessorsMixin implements _$FooState {
              set initializedNullable(val) {}
              get initializedNullable => '';
              set initializedNonNullable(val) {}
              get initializedNonNullable => 1;
            }
          '''),
          expectedOutput: withOverReactImport(/*language=dart*/ r'''
            @Factory()
            UiFactory<FooProps> Foo = _$Foo; // ignore: undefined_identifier
            @Props()
            class _$FooProps extends UiProps {}
            @State()
            class _$FooState extends UiState {
              String notInitialized;
              /*late*/ String/*?*/ initializedNullable;
              /*late*/ num/*!*/ initializedNonNullable;
            }
            @Component()
            class FooComponent extends UiStatefulComponent<FooProps, FooState> {
              @override
              getInitialState() => (newState()
                ..initializedNullable = null
                ..initializedNonNullable = 2.1
              );
            
              @override
              render() => null;
            }
            class FooProps extends _$FooProps
                with
                    // ignore: mixin_of_non_class, undefined_class
                    _$FooPropsAccessorsMixin {
              // ignore: const_initialized_with_non_constant_value, undefined_class, undefined_identifier
              static const PropsMeta meta = _$metaForFooProps;
            }
            class FooState extends _$FooState
                with
                    // ignore: mixin_of_non_class, undefined_class
                    _$FooStateAccessorsMixin {
              // ignore: const_initialized_with_non_constant_value, undefined_class, undefined_identifier
              static const StateMeta meta = _$metaForFooState;
            }
            abstract class _$FooStateAccessorsMixin implements _$FooState {
              set initializedNullable(val) {}
              get initializedNullable => '';
              set initializedNonNullable(val) {}
              get initializedNonNullable => 1;
            }
          '''),
        );
      });
    });
  });
}

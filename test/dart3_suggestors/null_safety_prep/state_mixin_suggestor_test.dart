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

import 'package:over_react_codemod/src/dart3_suggestors/null_safety_prep/state_mixin_suggestor.dart';
import 'package:test/test.dart';

import '../../resolved_file_context.dart';
import '../../util.dart';
import '../../util/component_usage_migrator_test.dart' show withOverReactImport;

void main() {
  final resolvedContext = SharedAnalysisContext.overReact;

  // Warm up analysis in a setUpAll so that if getting the resolved AST times out
  // (which is more common for the WSD context), it fails here instead of failing the first test.
  setUpAll(resolvedContext.warmUpAnalysis);

  group('StateMixinSuggestor', () {
    late SuggestorTester testSuggestor;

    setUp(() {
      testSuggestor = getSuggestorTester(
        StateMixinSuggestor(),
        resolvedContext: resolvedContext,
      );
    });

    test('patches state fields in mixins', () async {
      await testSuggestor(
        expectedPatchCount: 3,
        input: withOverReactImport(/*language=dart*/ r'''
            // ignore: undefined_identifier
            UiFactory<FooProps> Foo = castUiFactory(_$Foo);
            mixin FooProps on UiProps {
              String prop1;
            }
            mixin FooStateMixin on UiState {
              String state1;
              num state2;
              /// This is a doc comment
              /*late*/ String/*!*/ alreadyPatched;
              /*late*/ String/*?*/ alreadyPatchedButNoDocComment;
              String/*?*/ alreadyPatchedOptional;
            }
            mixin SomeOtherStateMixin on UiState {
              String state3;
              String/*?*/ alreadyPatchedOptional2;
            }
            class FooState = UiState with FooStateMixin, SomeOtherStateMixin;
            class FooComponent extends UiStatefulComponent2<FooProps, FooState> {
              @override
              render() => null;
            }
          '''),
        expectedOutput: withOverReactImport(/*language=dart*/ r'''
            // ignore: undefined_identifier
            UiFactory<FooProps> Foo = castUiFactory(_$Foo);
            mixin FooProps on UiProps {
              String prop1;
            }
            mixin FooStateMixin on UiState {
              String/*?*/ state1;
              num/*?*/ state2;
              /// This is a doc comment
              /*late*/ String/*!*/ alreadyPatched;
              /*late*/ String/*?*/ alreadyPatchedButNoDocComment;
              String/*?*/ alreadyPatchedOptional;
            }
            mixin SomeOtherStateMixin on UiState {
              String/*?*/ state3;
              String/*?*/ alreadyPatchedOptional2;
            }
            class FooState = UiState with FooStateMixin, SomeOtherStateMixin;
            class FooComponent extends UiStatefulComponent2<FooProps, FooState> {
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
            class FooProps extends UiProps {
              String prop1;
            }
            @StateMixin()
            mixin SomeOtherStateMixin on UiState {
              num state1;
            }
            @State()
            class FooState extends UiState with SomeOtherStateMixin {
              String state2;
              num state3;
              /// This is a doc comment
              /*late*/ String/*!*/ alreadyPatched;
              /*late*/ String/*?*/ alreadyPatchedButNoDocComment;
              String/*?*/ alreadyPatchedOptional;
            }
            @Component()
            class FooComponent extends UiStatefulComponent<FooProps, FooState> {
              @override
              render() => null;
            }
          '''),
        expectedOutput: withOverReactImport(/*language=dart*/ r'''
            @Factory()
            UiFactory<FooProps> Foo = _$Foo; // ignore: undefined_identifier
            @Props()
            class FooProps extends UiProps {
              String prop1;
            }
            @StateMixin()
            mixin SomeOtherStateMixin on UiState {
              num/*?*/ state1;
            }
            @State()
            class FooState extends UiState with SomeOtherStateMixin {
              String/*?*/ state2;
              num/*?*/ state3;
              /// This is a doc comment
              /*late*/ String/*!*/ alreadyPatched;
              /*late*/ String/*?*/ alreadyPatchedButNoDocComment;
              String/*?*/ alreadyPatchedOptional;
            }
            @Component()
            class FooComponent extends UiStatefulComponent<FooProps, FooState> {
              @override
              render() => null;
            }
          '''),
      );
    });
  });
}

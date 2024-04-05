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

import 'package:over_react_codemod/src/dart3_suggestors/null_safety_prep/class_component_required_default_props.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import '../../mui_suggestors/components/shared.dart';
import '../../resolved_file_context.dart';
import '../../util.dart';
import '../../util/component_usage_migrator_test.dart' show withOverReactImport;

void main() {
  final resolvedContext = SharedAnalysisContext.overReact;

  // Warm up analysis in a setUpAll so that if getting the resolved AST times out
  // (which is more common for the WSD context), it fails here instead of failing the first test.
  setUpAll(resolvedContext.warmUpAnalysis);

  group('ClassComponentRequiredDefaultPropsMigrator', () {
    late SuggestorTester testSuggestor;

    group('when sdkVersion is not set', () {
      setUp(() {
        testSuggestor = getSuggestorTester(
          ClassComponentRequiredDefaultPropsMigrator(),
          resolvedContext: resolvedContext,
        );
      });

      test('patches defaulted props in mixins', () async {
        await testSuggestor(
          expectedPatchCount: 5,
          input: withOverReactImport(/*language=dart*/ r'''
            // ignore: undefined_identifier
            UiFactory<FooProps> Foo = castUiFactory(_$Foo);
            mixin FooPropsMixin on UiProps {
              String notDefaulted;
              String defaultedNullable;
              num defaultedNonNullable;
            }
            mixin SomeOtherPropsMixin on UiProps {
              num anotherDefaultedNonNullable;
              Function defaultedNonNullableFn;
              List<num> defaultedNonNullableList;
            }
            class FooProps = UiProps with FooPropsMixin, SomeOtherPropsMixin;
            class FooComponent extends UiComponent2<FooProps> {
              @override
              get defaultProps => (newProps()
                ..defaultedNullable = null
                ..defaultedNonNullable = 2.1
                ..anotherDefaultedNonNullable = 1.1
                ..defaultedNonNullableFn = () {}
                ..defaultedNonNullableList = []
              );
            
              @override
              render() => null;
            }
            
            @Factory()
            UiFactory<FooProps> FooLegacy = _$FooLegacy; // ignore: undefined_identifier
            @Component()
            class FooLegacyComponent extends UiComponent<FooProps> {
              @override
              getDefaultProps() => (newProps()
                ..defaultedNullable = null
                ..defaultedNonNullable = 2.1
                ..anotherDefaultedNonNullable = 1.1
                ..defaultedNonNullableFn = () {}
                ..defaultedNonNullableList = []
              );
            
              @override
              render() => null;
            }
          '''),
          expectedOutput: withOverReactImport(/*language=dart*/ r'''
            // ignore: undefined_identifier
            UiFactory<FooProps> Foo = castUiFactory(_$Foo);
            mixin FooPropsMixin on UiProps {
              String notDefaulted;
              /*late*/ String/*?*/ defaultedNullable;
              /*late*/ num/*!*/ defaultedNonNullable;
            }
            mixin SomeOtherPropsMixin on UiProps {
              /*late*/ num/*!*/ anotherDefaultedNonNullable;
              /*late*/ Function/*!*/ defaultedNonNullableFn;
              /*late*/ List<num>/*!*/ defaultedNonNullableList;
            }
            class FooProps = UiProps with FooPropsMixin, SomeOtherPropsMixin;
            class FooComponent extends UiComponent2<FooProps> {
              @override
              get defaultProps => (newProps()
                ..defaultedNullable = null
                ..defaultedNonNullable = 2.1
                ..anotherDefaultedNonNullable = 1.1
                ..defaultedNonNullableFn = () {}
                ..defaultedNonNullableList = []
              );
            
              @override
              render() => null;
            }
            
            @Factory()
            UiFactory<FooProps> FooLegacy = _$FooLegacy; // ignore: undefined_identifier
            @Component()
            class FooLegacyComponent extends UiComponent<FooProps> {
              @override
              getDefaultProps() => (newProps()
                ..defaultedNullable = null
                ..defaultedNonNullable = 2.1
                ..anotherDefaultedNonNullable = 1.1
                ..defaultedNonNullableFn = () {}
                ..defaultedNonNullableList = []
              );
            
              @override
              render() => null;
            }
          '''),
        );
      });

      test('patches defaulted props in legacy classes', () async {
        await testSuggestor(
          expectedPatchCount: 3,
          input: withOverReactImport(/*language=dart*/ r'''
            @Factory()
            UiFactory<FooProps> Foo = _$Foo; // ignore: undefined_identifier
            @PropsMixin()
            mixin SomeOtherPropsMixin on UiProps {
              num anotherDefaultedNonNullable;
            }
            @Props()
            class FooProps extends UiProps with SomeOtherPropsMixin {
              String notDefaulted;
              String defaultedNullable;
              num defaultedNonNullable;
            }
            @Component()
            class FooComponent extends UiComponent<FooProps> {
              @override
              getDefaultProps() => (newProps()
                ..defaultedNullable = null
                ..defaultedNonNullable = 2.1
                ..anotherDefaultedNonNullable = 1.1
              );
            
              @override
              render() => null;
            }
          '''),
          expectedOutput: withOverReactImport(/*language=dart*/ r'''
            @Factory()
            UiFactory<FooProps> Foo = _$Foo; // ignore: undefined_identifier
            @PropsMixin()
            mixin SomeOtherPropsMixin on UiProps {
              /*late*/ num/*!*/ anotherDefaultedNonNullable;
            }
            @Props()
            class FooProps extends UiProps with SomeOtherPropsMixin {
              String notDefaulted;
              /*late*/ String/*?*/ defaultedNullable;
              /*late*/ num/*!*/ defaultedNonNullable;
            }
            @Component()
            class FooComponent extends UiComponent<FooProps> {
              @override
              getDefaultProps() => (newProps()
                ..defaultedNullable = null
                ..defaultedNonNullable = 2.1
                ..anotherDefaultedNonNullable = 1.1
              );
            
              @override
              render() => null;
            }
          '''),
        );
      });
    });

    group('when sdkVersion is set to 2.19.6', () {
      setUp(() {
        testSuggestor = getSuggestorTester(
          ClassComponentRequiredDefaultPropsMigrator(Version.parse('2.19.6')),
          resolvedContext: resolvedContext,
        );
      });

      test('patches defaulted props in mixins', () async {
        await testSuggestor(
          expectedPatchCount: 3,
          input: withOverReactImport(/*language=dart*/ r'''
            // ignore: undefined_identifier
            UiFactory<FooProps> Foo = castUiFactory(_$Foo);
            mixin FooPropsMixin on UiProps {
              String notDefaulted;
              String defaultedNullable;
              num defaultedNonNullable;
            }
            mixin SomeOtherPropsMixin on UiProps {
              num anotherDefaultedNonNullable;
            }
            class FooProps = UiProps with FooPropsMixin, SomeOtherPropsMixin;
            class FooComponent extends UiComponent2<FooProps> {
              @override
              get defaultProps => (newProps()
                ..defaultedNullable = null
                ..defaultedNonNullable = 2.1
                ..anotherDefaultedNonNullable = 1.1
              );
            
              @override
              render() => null;
            }
            
            @Factory()
            UiFactory<FooProps> FooLegacy = _$FooLegacy; // ignore: undefined_identifier
            @Component()
            class FooLegacyComponent extends UiComponent<FooProps> {
              @override
              getDefaultProps() => (newProps()
                ..defaultedNullable = null
                ..defaultedNonNullable = 2.1
                ..anotherDefaultedNonNullable = 1.1
              );
            
              @override
              render() => null;
            }
          '''),
          expectedOutput: withOverReactImport(/*language=dart*/ r'''
            // ignore: undefined_identifier
            UiFactory<FooProps> Foo = castUiFactory(_$Foo);
            mixin FooPropsMixin on UiProps {
              String notDefaulted;
              late String? defaultedNullable;
              late num defaultedNonNullable;
            }
            mixin SomeOtherPropsMixin on UiProps {
              late num anotherDefaultedNonNullable;
            }
            class FooProps = UiProps with FooPropsMixin, SomeOtherPropsMixin;
            class FooComponent extends UiComponent2<FooProps> {
              @override
              get defaultProps => (newProps()
                ..defaultedNullable = null
                ..defaultedNonNullable = 2.1
                ..anotherDefaultedNonNullable = 1.1
              );
            
              @override
              render() => null;
            }
            
            @Factory()
            UiFactory<FooProps> FooLegacy = _$FooLegacy; // ignore: undefined_identifier
            @Component()
            class FooLegacyComponent extends UiComponent<FooProps> {
              @override
              getDefaultProps() => (newProps()
                ..defaultedNullable = null
                ..defaultedNonNullable = 2.1
                ..anotherDefaultedNonNullable = 1.1
              );
            
              @override
              render() => null;
            }
          '''),
        );
      });

      test('patches defaulted props in legacy classes', () async {
        await testSuggestor(
          expectedPatchCount: 3,
          input: withOverReactImport(/*language=dart*/ r'''
            @Factory()
            UiFactory<FooProps> Foo = _$Foo; // ignore: undefined_identifier
            @PropsMixin()
            mixin SomeOtherPropsMixin on UiProps {
              num anotherDefaultedNonNullable;
            }
            @Props()
            class FooProps extends UiProps with SomeOtherPropsMixin {
              String notDefaulted;
              String defaultedNullable;
              num defaultedNonNullable;
            }
            @Component()
            class FooComponent extends UiComponent<FooProps> {
              @override
              getDefaultProps() => (newProps()
                ..defaultedNullable = null
                ..defaultedNonNullable = 2.1
                ..anotherDefaultedNonNullable = 1.1
              );
            
              @override
              render() => null;
            }
          '''),
          expectedOutput: withOverReactImport(/*language=dart*/ r'''
            @Factory()
            UiFactory<FooProps> Foo = _$Foo; // ignore: undefined_identifier
            @PropsMixin()
            mixin SomeOtherPropsMixin on UiProps {
              late num anotherDefaultedNonNullable;
            }
            @Props()
            class FooProps extends UiProps with SomeOtherPropsMixin {
              String notDefaulted;
              late String? defaultedNullable;
              late num defaultedNonNullable;
            }
            @Component()
            class FooComponent extends UiComponent<FooProps> {
              @override
              getDefaultProps() => (newProps()
                ..defaultedNullable = null
                ..defaultedNonNullable = 2.1
                ..anotherDefaultedNonNullable = 1.1
              );
            
              @override
              render() => null;
            }
          '''),
        );
      });
    });
  });
}

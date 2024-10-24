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
          expectedPatchCount: 7,
          input: withOverReactImport(/*language=dart*/ r'''
            // ignore: undefined_identifier
            UiFactory<FooProps> Foo = castUiFactory(_$Foo);
            mixin FooPropsMixin on UiProps {
              String notDefaulted;
              /// This is a doc comment
              /*late*/ String/*!*/ alreadyPatched;
              /*late*/ String/*!*/ alreadyPatchedButNoDocComment;
              String defaultedNullable;
              num defaultedNonNullable;
              var untypedDefaultedNonNullable;
              var untypedDefaultedNullable;
              var untypedNotDefaulted;
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
                ..alreadyPatched = 'foo'
                ..untypedDefaultedNonNullable = 1
                ..untypedDefaultedNullable = null
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
              /// This is a doc comment
              /*late*/ String/*!*/ alreadyPatched;
              /*late*/ String/*!*/ alreadyPatchedButNoDocComment;
              /*late*/ String/*?*/ defaultedNullable;
              /*late*/ num/*!*/ defaultedNonNullable;
              /*late*/ dynamic/*!*/ untypedDefaultedNonNullable;
              /*late*/ dynamic/*?*/ untypedDefaultedNullable;
              var untypedNotDefaulted;
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
                ..alreadyPatched = 'foo'
                ..untypedDefaultedNonNullable = 1
                ..untypedDefaultedNullable = null
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

      test(
          'patches defaulted props in mixins when defaults are in the props mixin',
          () async {
        await testSuggestor(
          expectedPatchCount: 5,
          input: withOverReactImport(/*language=dart*/ r'''
            // ignore: undefined_identifier
            UiFactory<FooProps> Foo = castUiFactory(_$Foo);
            mixin FooPropsMixin on UiProps {
              static final defaultProps = Foo()
                ..alreadyPatched = 'foo'
                ..defaultedNullable = null
                ..defaultedNonNullable = 2.1
                ..anotherDefaultedNonNullable = 1.1
                ..defaultedNonNullableFn = () {}
                ..defaultedNonNullableList = [];
            
              String notDefaulted;
              /*late*/ String/*!*/ alreadyPatched;
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
              get defaultProps => FooPropsMixin.defaultProps;
            
              @override
              render() => null;
            }
            
            @Factory()
            UiFactory<FooProps> FooLegacy = _$FooLegacy; // ignore: undefined_identifier
            @Component()
            class FooLegacyComponent extends UiComponent<FooProps> {
              @override
              getDefaultProps() => FooPropsMixin.defaultProps;
            
              @override
              render() => null;
            }
          '''),
          expectedOutput: withOverReactImport(/*language=dart*/ r'''
            // ignore: undefined_identifier
            UiFactory<FooProps> Foo = castUiFactory(_$Foo);
            mixin FooPropsMixin on UiProps {
              static final defaultProps = Foo()
                ..alreadyPatched = 'foo'
                ..defaultedNullable = null
                ..defaultedNonNullable = 2.1
                ..anotherDefaultedNonNullable = 1.1
                ..defaultedNonNullableFn = () {}
                ..defaultedNonNullableList = [];
                
              String notDefaulted;
              /*late*/ String/*!*/ alreadyPatched;
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
              get defaultProps => FooPropsMixin.defaultProps;
            
              @override
              render() => null;
            }
            
            @Factory()
            UiFactory<FooProps> FooLegacy = _$FooLegacy; // ignore: undefined_identifier
            @Component()
            class FooLegacyComponent extends UiComponent<FooProps> {
              @override
              getDefaultProps() => FooPropsMixin.defaultProps;
            
              @override
              render() => null;
            }
          '''),
        );
      });

      test('patches defaulted props in abstract classes', () async {
        await testSuggestor(
          expectedPatchCount: 7,
          input: withOverReactImport(/*language=dart*/ r'''
            mixin FooPropsMixin on UiProps {
              String notDefaulted;
              /// This is a doc comment
              /*late*/ String/*!*/ alreadyPatched;
              /*late*/ String/*!*/ alreadyPatchedButNoDocComment;
              String defaultedNullable;
              num defaultedNonNullable;
              var untypedDefaultedNonNullable;
              var untypedDefaultedNullable;
              var untypedNotDefaulted;
            }
            mixin SomeOtherPropsMixin on UiProps {
              num anotherDefaultedNonNullable;
              Function defaultedNonNullableFn;
              List<num> defaultedNonNullableList;
            }
            class FooProps = UiProps with FooPropsMixin, SomeOtherPropsMixin;
            abstract class FooComponent<TProps extends FooProps> extends UiComponent2<TProps> {
              @override
              get defaultProps => (newProps()
                ..alreadyPatched = 'foo'
                ..untypedDefaultedNonNullable = 1
                ..untypedDefaultedNullable = null
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
            mixin FooPropsMixin on UiProps {
              String notDefaulted;
              /// This is a doc comment
              /*late*/ String/*!*/ alreadyPatched;
              /*late*/ String/*!*/ alreadyPatchedButNoDocComment;
              /*late*/ String/*?*/ defaultedNullable;
              /*late*/ num/*!*/ defaultedNonNullable;
              /*late*/ dynamic/*!*/ untypedDefaultedNonNullable;
              /*late*/ dynamic/*?*/ untypedDefaultedNullable;
              var untypedNotDefaulted;
            }
            mixin SomeOtherPropsMixin on UiProps {
              /*late*/ num/*!*/ anotherDefaultedNonNullable;
              /*late*/ Function/*!*/ defaultedNonNullableFn;
              /*late*/ List<num>/*!*/ defaultedNonNullableList;
            }
            class FooProps = UiProps with FooPropsMixin, SomeOtherPropsMixin;
            abstract class FooComponent<TProps extends FooProps> extends UiComponent2<TProps> {
              @override
              get defaultProps => (newProps()
                ..alreadyPatched = 'foo'
                ..untypedDefaultedNonNullable = 1
                ..untypedDefaultedNullable = null
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

      test(
          'patches defaulted props in legacy classes using component1 boilerplate',
          () async {
        await testSuggestor(
          expectedPatchCount: 2,
          input: withOverReactImport(/*language=dart*/ r'''
            @Factory()
            UiFactory<FooProps> Foo = _$Foo; // ignore: undefined_identifier
            @Props()
            class _$FooProps extends UiProps {
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
            abstract class _$FooPropsAccessorsMixin implements _$FooProps {
              set defaultedNullable(val) {}
              get defaultedNullable => '';
              set defaultedNonNullable(val) {}
              get defaultedNonNullable => 1;
            }
          '''),
          expectedOutput: withOverReactImport(/*language=dart*/ r'''
            @Factory()
            UiFactory<FooProps> Foo = _$Foo; // ignore: undefined_identifier
            @Props()
            class _$FooProps extends UiProps {
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
            abstract class _$FooPropsAccessorsMixin implements _$FooProps {
              set defaultedNullable(val) {}
              get defaultedNullable => '';
              set defaultedNonNullable(val) {}
              get defaultedNonNullable => 1;
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
          isExpectedError: (err) {
            return err.message.contains(RegExp(r"Unexpected text 'late'"));
          },
          expectedPatchCount: 3,
          input: withOverReactImport(/*language=dart*/ r'''
            // ignore: undefined_identifier
            UiFactory<FooProps> Foo = castUiFactory(_$Foo);
            mixin FooPropsMixin on UiProps {
              /// This is a doc comment
              late String alreadyPatched;
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
                ..alreadyPatched = 'foo'
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
                ..alreadyPatched = 'foo'
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
              /// This is a doc comment
              late String alreadyPatched;
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
                ..alreadyPatched = 'foo'
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
                ..alreadyPatched = 'foo'
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

    group('makes no update if file is already on a null safe Dart version', () {
      final resolvedContext = SharedAnalysisContext.overReactNullSafe;

      // Warm up analysis in a setUpAll so that if getting the resolved AST times out
      // (which is more common for the WSD context), it fails here instead of failing the first test.
      setUpAll(resolvedContext.warmUpAnalysis);

      late SuggestorTester nullSafeTestSuggestor;

      setUp(() {
        nullSafeTestSuggestor = getSuggestorTester(
          ClassComponentRequiredDefaultPropsMigrator(),
          resolvedContext: resolvedContext,
        );
      });

      test('', () async {
        await nullSafeTestSuggestor(
          expectedPatchCount: 0,
          input: withOverReactImport(/*language=dart*/ r'''
            // ignore: undefined_identifier
            UiFactory<FooProps> Foo = castUiFactory(_$Foo);
            mixin FooPropsMixin on UiProps {
              String? prop1;
              late String prop2;
              num? prop3;
            }
            mixin SomeOtherPropsMixin on UiProps {
              num? prop4;
            }
            class FooProps = UiProps with FooPropsMixin, SomeOtherPropsMixin;
            class FooComponent extends UiComponent2<FooProps> {
              @override
              get defaultProps => (newProps()
                ..prop2 = 'foo'
                ..prop3 = 1
                ..prop4 = null
              );
            
              @override
              render() => null;
            }
          '''),
        );
      });

      test('unless there is a lang version comment', () async {
        await nullSafeTestSuggestor(
          input: withOverReactImport(/*language=dart*/ r'''
            // ignore: undefined_identifier
            UiFactory<FooProps> Foo = castUiFactory(_$Foo);
            mixin FooPropsMixin on UiProps {
              String notDefaulted;
              /// This is a doc comment
              /*late*/ String/*!*/ alreadyPatched;
              /*late*/ String/*!*/ alreadyPatchedButNoDocComment;
              String defaultedNullable;
              num defaultedNonNullable;
              var untypedDefaultedNonNullable;
              var untypedDefaultedNullable;
              var untypedNotDefaulted;
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
                ..alreadyPatched = 'foo'
                ..untypedDefaultedNonNullable = 1
                ..untypedDefaultedNullable = null
                ..defaultedNullable = null
                ..defaultedNonNullable = 2.1
                ..anotherDefaultedNonNullable = 1.1
                ..defaultedNonNullableFn = () {}
                ..defaultedNonNullableList = []
              );
            
              @override
              render() => null;
            }
          ''', filePrefix: '// @dart=2.11\n'),
          expectedOutput: withOverReactImport(/*language=dart*/ r'''
            // ignore: undefined_identifier
            UiFactory<FooProps> Foo = castUiFactory(_$Foo);
            mixin FooPropsMixin on UiProps {
              String notDefaulted;
              /// This is a doc comment
              /*late*/ String/*!*/ alreadyPatched;
              /*late*/ String/*!*/ alreadyPatchedButNoDocComment;
              /*late*/ String/*?*/ defaultedNullable;
              /*late*/ num/*!*/ defaultedNonNullable;
              /*late*/ dynamic/*!*/ untypedDefaultedNonNullable;
              /*late*/ dynamic/*?*/ untypedDefaultedNullable;
              var untypedNotDefaulted;
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
                ..alreadyPatched = 'foo'
                ..untypedDefaultedNonNullable = 1
                ..untypedDefaultedNullable = null
                ..defaultedNullable = null
                ..defaultedNonNullable = 2.1
                ..anotherDefaultedNonNullable = 1.1
                ..defaultedNonNullableFn = () {}
                ..defaultedNonNullableList = []
              );
            
              @override
              render() => null;
            }
          ''', filePrefix: '// @dart=2.11\n'),
          // Ignore error on language version comment.
          isExpectedError: (error) =>
              error.errorCode.name.toLowerCase() ==
              'illegal_language_version_override',
        );
      });
    });
  });
}

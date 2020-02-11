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
import 'package:over_react_codemod/src/boilerplate_suggestors/props_meta_migrator.dart';
import 'package:test/test.dart';

import '../util.dart';

main() {
  group('PropsMetaMigrator', () {
    final converter = ClassToMixinConverter();
    final testSuggestor = getSuggestorTester(PropsMetaMigrator(converter));

    tearDown(() {
      converter.setConvertedClassNames({});
    });

    group('does not perform a migration', () {
      test('when it encounters an empty file', () {
        converter.setConvertedClassNames({
          'FooProps': 'FooProps',
        });

        testSuggestor(expectedPatchCount: 0, input: '');
      });

      test('when there are no `PropsClass.meta` identifiers', () {
        converter.setConvertedClassNames({
          'FooProps': 'FooProps',
        });

        testSuggestor(
          expectedPatchCount: 0,
          input: '''
          library foo;
          var a = 'b';
          class Foo {}
        ''',
        );
      });
    });

    group(
        'performs a migration when there are one or more `PropsClass.meta` identifiers',
        () {
      test('', () {
        converter.setConvertedClassNames({
          'FooProps': 'FooProps',
          'BarProps': 'BarPropsMixin',
        });

        testSuggestor(
          expectedPatchCount: 7,
          input: '''
          /// Some doc comment
          @PropsMixin()
          abstract class FooPropsMixin implements UiProps {
            // To ensure the codemod regression checking works properly, please keep this
            // field at the top of the class!
            // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
            static const PropsMeta meta = _\$metaForFooPropsMixin;
            
            String foo;
          }
              
          @Component2()
          class FooComponent extends UiComponent2<FooProps> {
            static const foo = FooProps.meta;
            static const bar = [FooProps.meta];
          
            @override
            get consumedProps => const [FooProps.meta, BarProps.meta];
        
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
        /// Some doc comment
        @PropsMixin()
        abstract class FooPropsMixin implements UiProps {
          // To ensure the codemod regression checking works properly, please keep this
          // field at the top of the class!
          // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
          static const PropsMeta meta = _\$metaForFooPropsMixin;
          
          String foo;
        }
            
        @Component2()
        class FooComponent extends UiComponent2<FooProps> {
          static final foo = propsMeta.forMixin(FooProps);
          static final bar = [propsMeta.forMixin(FooProps)];
        
          @override
          get consumedProps => [propsMeta.forMixin(FooProps), propsMeta.forMixin(BarPropsMixin)];
          
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

      test(
          'unless the props class is not found within `propsAndStateClassNamesConvertedToNewBoilerplate`',
          () {
        converter.setConvertedClassNames({
          'BarProps': 'BarProps',
        });

        testSuggestor(
          expectedPatchCount: 0,
          input: '''
          @Component2()
          class FooComponent extends UiComponent2<FooProps> {
            @override
            get consumedProps => const [
              FooProps.meta,
            ];
        
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

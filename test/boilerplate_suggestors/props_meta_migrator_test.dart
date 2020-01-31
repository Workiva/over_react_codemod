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
    final testSuggestor = getSuggestorTester(PropsMetaMigrator());

    tearDown(() {
      propsAndStateClassNamesConvertedToNewBoilerplate = {};
    });

    group('does not perform a migration', () {
      test('when it encounters an empty file', () {
        propsAndStateClassNamesConvertedToNewBoilerplate = {
          'FooProps': 'FooProps',
        };

        testSuggestor(expectedPatchCount: 0, input: '');
      });

      test('when there are no `PropsClass.meta` identifiers', () {
        propsAndStateClassNamesConvertedToNewBoilerplate = {
          'FooProps': 'FooProps',
        };

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
        propsAndStateClassNamesConvertedToNewBoilerplate = {
          'FooProps': 'FooProps',
        };

        testSuggestor(
          expectedPatchCount: 1,
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
          expectedOutput: '''
        @Component2()
        class FooComponent extends UiComponent2<FooProps> {
          @override
          get consumedProps => const [
            propsMeta.forMixin(FooProps),
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

      test(
          'unless the props class is not found within `propsAndStateClassNamesConvertedToNewBoilerplate`',
          () {
        propsAndStateClassNamesConvertedToNewBoilerplate = {
          'BarProps': 'BarProps',
        };

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

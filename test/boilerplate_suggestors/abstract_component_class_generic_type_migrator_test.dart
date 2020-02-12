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

import 'package:over_react_codemod/src/boilerplate_suggestors/abstract_component_class_generic_type_migrator.dart';
import 'package:over_react_codemod/src/boilerplate_suggestors/boilerplate_utilities.dart';
import 'package:test/test.dart';

import '../util.dart';

main() {
  group('AbstractComponentClassGenericTypeMigrator', () {
    final converter = ClassToMixinConverter();
    final testSuggestor = getSuggestorTester(
        AbstractComponentClassGenericTypeMigrator(converter));

    tearDown(() {
      converter.setConvertedClassNames({});
    });

    group('does not perform a migration', () {
      test('when it encounters an empty file', () {
        testSuggestor(expectedPatchCount: 0, input: '');
      });

      test('when the class is not abstract', () {
        converter.setConvertedClassNames({
          'SomeAbstractPropsClass': 'SomeAbstractPropsClassMixin',
        });

        testSuggestor(
          expectedPatchCount: 0,
          input: '''
          class SomeComponent extends UiComponent2<SomeAbstractPropsClass> {}
        ''',
        );
      });

      test('when the type in the parameter was not converted', () {
        testSuggestor(
          expectedPatchCount: 0,
          input: '''
          abstract class SomeAbstractComponent<T extends SomeAbstractPropsClassThatWasNotConverted> extends UiComponent2<T> {}
        ''',
        );
      });

      test(
          'when the type in the parameter was converted, but its name did not change',
          () {
        converter.setConvertedClassNames({
          'SomeAbstractPropsClass': 'SomeAbstractPropsClass',
        });

        testSuggestor(
          expectedPatchCount: 0,
          input: '''
          abstract class SomeAbstractComponent<T extends SomeAbstractPropsClass> extends UiComponent2<T> {}
        ''',
        );
      });
    });

    group(
        'performs a migration when there is an abstract class that has type annotations '
        'for classes that were converted to mixins', () {
      test('and is abstract', () {
        converter.setConvertedClassNames({
          'SomeAbstractPropsClass': 'SomeAbstractPropsClassMixin',
        });

        testSuggestor(
          expectedPatchCount: 1,
          input: r'''
          mixin SomeAbstractPropsClassMixin on UiProps {
            String foo;
            int bar;
          }
          
          abstract class SomeAbstractPropsClass = UiProps with SomeAbstractPropsClassMixin;
          
          @AbstractComponent2()
          abstract class SomeAbstractComponent<T extends SomeAbstractPropsClass, S extends SomethingIrrelevant> 
              extends UiComponent2<T> {}
        ''',
          expectedOutput: r'''
          mixin SomeAbstractPropsClassMixin on UiProps {
            String foo;
            int bar;
          }
          
          abstract class SomeAbstractPropsClass = UiProps with SomeAbstractPropsClassMixin;
          
          @AbstractComponent2()
          abstract class SomeAbstractComponent<T extends SomeAbstractPropsClassMixin, S extends SomethingIrrelevant> 
              extends UiComponent2<T> {}
        ''',
        );
      });
    });
  });
}

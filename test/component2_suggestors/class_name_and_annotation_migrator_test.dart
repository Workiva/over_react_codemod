// Copyright 2019 Workiva Inc.
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

import 'package:over_react_codemod/src/component2_suggestors/class_name_and_annotation_migrator.dart';
import 'package:test/test.dart';

import '../util.dart';

main() {
  group('ClassNameAndAnnotationMigrator', () {
    final testSuggestor = getSuggestorTester(ClassNameAndAnnotationMigrator());

    test('empty file', () {
      testSuggestor(expectedPatchCount: 0, input: '');
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
    });

    test('annotation with non-based extending class updates', () {
      testSuggestor(
        expectedPatchCount: 1,
        input: '''
          @Component()
          class FooComponent extends SomeOtherClass{}
        ''',
        expectedOutput: '''
          @Component2()
          class FooComponent extends SomeOtherClass{}
        ''',
      );
    });

    test('annotation and extending class updates', () {
      testSuggestor(
        expectedPatchCount: 2,
        input: '''
          @Component()
          class FooComponent extends UiComponent<FooProps>{}
        ''',
        expectedOutput: '''
          @Component2()
          class FooComponent extends UiComponent2<FooProps>{}
        ''',
      );
    });

    test('extending class only needs updating', () {
      testSuggestor(
        expectedPatchCount: 1,
        input: '''
          @Component2()
          class FooComponent extends UiStatefulComponent<FooProps, FooState>{}
        ''',
        expectedOutput: '''
          @Component2()
          class FooComponent extends UiStatefulComponent2<FooProps, FooState>{}
        ''',
      );
    });

    test('annotation with args and extending class updates', () {
      testSuggestor(
        expectedPatchCount: 2,
        input: '''
          @Component(isWrapper: true)
          class FooComponent extends UiComponent<FooProps>{}
        ''',
        expectedOutput: '''
          @Component2(isWrapper: true)
          class FooComponent extends UiComponent2<FooProps>{}
        ''',
      );
    });

    test('annotation with args and extending stateful class updates', () {
      testSuggestor(
        expectedPatchCount: 3,
        input: '''
          @Component(isWrapper: true)
          class FooComponent extends UiStatefulComponent<FooProps, FooState>{}
        ''',
        expectedOutput: '''
          @Component2(isWrapper: true)
          class FooComponent extends UiStatefulComponent2<FooProps, FooState>{}
        ''',
      );
    });

    test('AbstractComponent class annotation updates', () {
      testSuggestor(
        expectedPatchCount: 5,
        input: '''
          @AbstractComponent(isWrapper: true)
          abstract class FooComponent extends UiStatefulComponent<FooProps, FooState>{}
        ''',
        expectedOutput: '''
          @AbstractComponent2(isWrapper: true)
          abstract class FooComponent extends UiStatefulComponent2<FooProps, FooState>{}
        ''',
      );
    });
  });
}

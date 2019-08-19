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

import 'package:over_react_codemod/src/component2_suggestors/deprecated_lifecycle_suggestor.dart';
import 'package:test/test.dart';

import '../util.dart';
import 'package:over_react_codemod/src/component2_suggestors/component2_constants.dart';

main() {
  group('DeprecatedLifecycleSuggestor', () {
    final testSuggestor = getSuggestorTester(DeprecatedLifecycleSuggestor());

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

    test('adds a FIXME comment for componentWillUpdate with override', () {
      testSuggestor(
        expectedPatchCount: 1,
        input: '''
          @Component2()
          class FooComponent extends UiComponent2 {
            @override
            componentWillUpdate(){}
          }
        ''',
        expectedOutput: '''
          @Component2()
          class FooComponent extends UiComponent2 {
            ${getDeperecationMessage('componentWillUpdate')}
            @override
            componentWillUpdate(){}
          }
        ''',
      );
    });

    test('adds a FIXME comment for componentWillUpdate without override', () {
      testSuggestor(
        expectedPatchCount: 1,
        input: '''
          @Component2()
          class FooComponent extends UiComponent2 {
            componentWillUpdate(){}
          }
        ''',
        expectedOutput: '''
          @Component2()
          class FooComponent extends UiComponent2 {
            ${getDeperecationMessage('componentWillUpdate')}
            componentWillUpdate(){}
          }
        ''',
      );
    });

    test('adds a FIXME comment for componentWillReceiveProps with override',
        () {
      testSuggestor(
        expectedPatchCount: 1,
        input: '''
          @Component2()
          class FooComponent extends UiComponent2 {
            @override
            componentWillReceiveProps(){}
          }
        ''',
        expectedOutput: '''
          @Component2()
          class FooComponent extends UiComponent2 {
            ${getDeperecationMessage('componentWillReceiveProps')}
            @override
            componentWillReceiveProps(){}
          }
        ''',
      );
    });

    test('adds a FIXME comment for componentWillReceiveProps without override',
        () {
      testSuggestor(
        expectedPatchCount: 1,
        input: '''
          @Component2()
          class FooComponent extends UiComponent2 {
            componentWillReceiveProps(){}
          }
        ''',
        expectedOutput: '''
          @Component2()
          class FooComponent extends UiComponent2 {
            ${getDeperecationMessage('componentWillReceiveProps')}
            componentWillReceiveProps(){}
          }
        ''',
      );
    });

    test(
        'adds two FIXME comments when both componentWillUpdate and '
        'componentWillReceiveProps is present', () {
      testSuggestor(
        expectedPatchCount: 2,
        input: '''
          @Component2()
          class FooComponent extends UiComponent2 {
            @override
            componentWillUpdate(){}
            
            @override
            componentWillReceiveProps(){}
          }
        ''',
        expectedOutput: '''
          @Component2()
          class FooComponent extends UiComponent2 {
            ${getDeperecationMessage('componentWillUpdate')}
            @override
            componentWillUpdate(){}
        
            ${getDeperecationMessage('componentWillReceiveProps')}
            @override
            componentWillReceiveProps(){}
          }
        ''',
      );
    });
  });
}

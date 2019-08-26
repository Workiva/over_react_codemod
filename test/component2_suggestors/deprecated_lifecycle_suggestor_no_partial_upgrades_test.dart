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

main() {
  group('DeprecatedLifecycleSuggestor with --no-partial-upgrades flag', () {
    final testSuggestor = getSuggestorTester(
        DeprecatedLifecycleSuggestor(allowPartialUpgrades: false));

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

    group('does not add a FIXME comment', () {
      test('for componentWillUpdate with override', () {
        testSuggestor(
          expectedPatchCount: 0,
          input: '''
            @Component2()
            class FooComponent extends UiComponent2 {
              @override
              componentWillUpdate(){}
            }
          ''',
        );
      });

      test('componentWillUpdate without override', () {
        testSuggestor(
          expectedPatchCount: 0,
          input: '''
            @Component2()
            class FooComponent extends UiComponent2 {
              componentWillUpdate(){}
            }
          ''',
        );
      });

      test('componentWillReceiveProps with override', () {
        testSuggestor(
          expectedPatchCount: 0,
          input: '''
            @Component2()
            class FooComponent extends UiComponent2 {
              @override
              componentWillReceiveProps(){}
            }
          ''',
        );
      });

      test('componentWillReceiveProps without override', () {
        testSuggestor(
          expectedPatchCount: 0,
          input: '''
            @Component2()
            class FooComponent extends UiComponent2 {
              componentWillReceiveProps(){}
            }
          ''',
        );
      });

      test(
          'when both componentWillUpdate and componentWillReceiveProps is present',
          () {
        testSuggestor(
          expectedPatchCount: 0,
          input: '''
            @Component2()
            class FooComponent extends UiComponent2 {
              @override
              componentWillUpdate(){}
              
              @override
              componentWillReceiveProps(){}
            }
          ''',
        );
      });
    });
  });
}

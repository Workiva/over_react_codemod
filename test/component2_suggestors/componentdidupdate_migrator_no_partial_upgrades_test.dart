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

import 'package:over_react_codemod/src/component2_suggestors/componentdidupdate_migrator.dart';
import 'package:test/test.dart';

import '../util.dart';

main() {
  group('ComponentDidUpdateMigrator with --no-partial-upgrades flag', () {
    final testSuggestor =
        getSuggestorTester(ComponentDidUpdateMigrator(noPartialUpgrades: true));

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

    group('componentDidUpdate method', () {
      test('updates if containing class is fully upgradable', () {
        testSuggestor(
          expectedPatchCount: 1,
          input: '''
            @Component2()
            class FooComponent extends UiComponent2 {
              componentDidUpdate(Map prevProps, Map prevState) {
                // method body
              }
            }
          ''',
          expectedOutput: '''
            @Component2()
            class FooComponent extends UiComponent2 {
              componentDidUpdate(Map prevProps, Map prevState, [snapshot]) {
                // method body
              }
            }
          ''',
        );
      });

      group('does not update if containing class is not fully upgradable', () {
        test('-- extends from non-Component class', () {
          testSuggestor(
            expectedPatchCount: 0,
            input: '''
              @Component2()
              class FooComponent extends AbstractComponent {
                componentDidUpdate(Map prevProps, Map prevState) {
                  // method body
                }
              }
            ''',
          );
        });

        test('-- has lifecycle methods without codemods', () {
          testSuggestor(
            expectedPatchCount: 0,
            input: '''
              @Component2()
              class FooComponent extends UiComponent2 {
                componentDidUpdate(Map prevProps, Map prevState) {
                  // method body
                }
                
                @override
                componentWillUnmount() {
                  // method body
                }
              }
            ''',
          );
        });
      });
    });

    test('componentDidUpdate does not update if optional third argument exists',
        () {
      testSuggestor(
        expectedPatchCount: 0,
        input: '''
          @Component2()
          class FooComponent extends UiComponent2 {
            componentDidUpdate(Map prevProps, Map prevState, [_]) {
              // method body
            }
          }
        ''',
      );
    });

    test('does not change componentDidUpdate for non-component2 classes', () {
      testSuggestor(
        expectedPatchCount: 0,
        input: '''
          @Component()
          class FooComponent extends UiComponent {
            componentDidUpdate(Map prevProps, Map prevState) {
              // method body
            }
          }
        ''',
      );
    });
  });
}

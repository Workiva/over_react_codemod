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

import 'package:over_react_codemod/src/component2_suggestors/setstate_updater.dart';
import 'package:test/test.dart';

import '../util.dart';

main() {
  group('SetStateUpdater', () {
    final testSuggestor = getSuggestorTester(SetStateUpdater());

    group('updates correctly when there', () {
      test('is an empty file', () {
        testSuggestor(expectedPatchCount: 0, input: '');
      });

      test('are no matches', () {
        testSuggestor(
          expectedPatchCount: 0,
          input: '''
            library foo;
            var a = 'b';
            class Foo {}
          ''',
        );
      });

      group('is a function expression', () {
        test('', () {
          testSuggestor(
            expectedPatchCount: 1,
            input: '''
              @Component2()
              class FooComponent extends UiComponent2 {
                @override
                componentWillReceiveProps(Map newProps) {
                  super.componentWillReceiveProps(newProps);
                  
                  setState((prevState, props) {
                    // return ...;
                  });
                }
              }  
            ''',
            expectedOutput: '''
              @Component2()
              class FooComponent extends UiComponent2 {
                @override
                componentWillReceiveProps(Map newProps) {
                  super.componentWillReceiveProps(newProps);
                  
                  setStateWithUpdater((prevState, props) {
                    // return ...;
                  });
                }
              }
            ''',
          );
        });

        test('using arrow notation', () {
          testSuggestor(
            expectedPatchCount: 1,
            input: '''
              @Component2()
              class FooComponent extends AbstractComponent {
                someMethod() {
                  setState((prevState, props) => newState());
                }
              }
            ''',
            expectedOutput: '''
              @Component2()
              class FooComponent extends AbstractComponent {
                someMethod() {
                  setStateWithUpdater((prevState, props) => newState());
                }
              }
            ''',
          );
        });
      });
    });

    group('does not update', () {
      test('for non-component2 classes', () {
        testSuggestor(
          expectedPatchCount: 0,
          input: '''
            @Component()
            class FooComponent extends UiComponent {
              @override
              componentWillReceiveProps(Map newProps) {
                super.componentWillReceiveProps(newProps);
                
                setState((prevState, props) {
                  // return ...;
                });
              }
            }  
          ''',
        );
      });
    });
  });
}
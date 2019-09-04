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
    setStateTests(allowPartialUpgrades: true);
  });

  group('SetStateUpdater with --no-partial-upgrades flag', () {
    setStateTests(allowPartialUpgrades: false);
  });
}

setStateTests({bool allowPartialUpgrades}) {
  final testSuggestor = getSuggestorTester(
      SetStateUpdater(allowPartialUpgrades: allowPartialUpgrades));

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

  group('updates correctly when setState', () {
    group('is a function expression', () {
      test('in a class that is fully upgradable', () {
        testSuggestor(
          expectedPatchCount: 1,
          input: '''
            @Component2()
            class FooComponent extends UiComponent2 {
              someMethod() {
                setState((prevState, props) {
                  // return ...;
                });
              }
            }
          ''',
          expectedOutput: '''
            @Component2()
            class FooComponent extends UiComponent2 {
              someMethod() {
                setStateWithUpdater((prevState, props) {
                  // return ...;
                });
              }
            }
          ''',
        );
      });

      group('in a class that is not fully upgradable', () {
        test('--extends from a non-Component class', () {
          testSuggestor(
            expectedPatchCount: allowPartialUpgrades ? 1 : 0,
            input: '''
              @Component2()
              class FooComponent extends SomeOtherClass {
                someMethod() {
                  setState((prevState, props) {
                    // return ...;
                  });
                }
              }
            ''',
            expectedOutput: '''
              @Component2()
              class FooComponent extends SomeOtherClass {
                someMethod() {
                  ${allowPartialUpgrades ? 'setStateWithUpdater' : 'setState'}((prevState, props) {
                    // return ...;
                  });
                }
              }
            ''',
          );
        });

        test('-- has lifecycle methods without codemods', () {
          testSuggestor(
            expectedPatchCount: allowPartialUpgrades ? 1 : 0,
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

                  ${allowPartialUpgrades ? 'setStateWithUpdater' : 'setState'}((prevState, props) {
                    // return ...;
                  });
                }
              }
            ''',
          );
        });
      });

      group('using arrow notation', () {
        test('in a class that is fully upgradable', () {
          testSuggestor(
            expectedPatchCount: 1,
            input: '''
              @Component2()
              class FooComponent extends FluxUiStatefulComponent2 {
                someMethod() {
                  setState((prevState, props) => newState());
                }
              }
            ''',
            expectedOutput: '''
              @Component2()
              class FooComponent extends FluxUiStatefulComponent2 {
                someMethod() {
                  setStateWithUpdater((prevState, props) => newState());
                }
              }
            ''',
          );
        });

        group('in a class that is not fully upgradable', () {
          test('--extends from a non-Component class', () {
            testSuggestor(
              expectedPatchCount: allowPartialUpgrades ? 1 : 0,
              input: '''
                @Component2()
                class FooComponent extends SomeOtherClass {
                  someMethod() {
                    setState((prevState, props) => newState());
                  }
                }
              ''',
              expectedOutput: '''
                @Component2()
                class FooComponent extends SomeOtherClass {
                  someMethod() {
                    ${allowPartialUpgrades ? 'setStateWithUpdater' : 'setState'}((prevState, props) => newState());
                  }
                }
              ''',
            );
          });

          test('-- has lifecycle methods without codemods', () {
            testSuggestor(
              expectedPatchCount: allowPartialUpgrades ? 1 : 0,
              input: '''
                @Component2()
                class FooComponent extends UiComponent2 {
                  @override
                  componentWillReceiveProps(Map newProps) {
                    super.componentWillReceiveProps(newProps);
                    
                    setState((prevState, props) => newState());
                  }
                }
              ''',
              expectedOutput: '''
                @Component2()
                class FooComponent extends UiComponent2 {
                  @override
                  componentWillReceiveProps(Map newProps) {
                    super.componentWillReceiveProps(newProps);
                    
                    ${allowPartialUpgrades ? 'setStateWithUpdater' : 'setState'}((prevState, props) => newState());
                  }
                }
              ''',
            );
          });
        });
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
}

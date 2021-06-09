// @dart=2.7
// ^ Do not remove until migrated to null safety. More info at https://wiki.atl.workiva.net/pages/viewpage.action?pageId=189370832
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
  group('ComponentDidUpdateMigrator', () {
    componentDidUpdateTests();
  });

  group('ComponentDidUpdateMigrator with --no-partial-upgrades flag', () {
    componentDidUpdateTests(allowPartialUpgrades: false);
  });

  group('ComponentDidUpdateMigrator with --upgrade-abstract-components flag',
      () {
    componentDidUpdateTests(shouldUpgradeAbstractComponents: true);
  });

  group(
      'ComponentDidUpdateMigrator with --no-partial-upgrades and --upgrade-abstract-components flag',
      () {
    componentDidUpdateTests(
        allowPartialUpgrades: false, shouldUpgradeAbstractComponents: true);
  });
}

void componentDidUpdateTests({
  bool allowPartialUpgrades = true,
  bool shouldUpgradeAbstractComponents = false,
}) {
  final testSuggestor = getSuggestorTester(ComponentDidUpdateMigrator(
    allowPartialUpgrades: allowPartialUpgrades,
    shouldUpgradeAbstractComponents: shouldUpgradeAbstractComponents,
  ));

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

    group(
        '${allowPartialUpgrades ? 'updates' : 'does not update'} if '
        'containing class is not fully upgradable', () {
      test('-- extends from non-Component class', () {
        testSuggestor(
          expectedPatchCount: allowPartialUpgrades ? 1 : 0,
          input: '''
            @Component2()
            class FooComponent extends SomeOtherClass {
              componentDidUpdate(Map prevProps, Map prevState) {
                // method body
              }
            }
          ''',
          expectedOutput: '''
            @Component2()
            class FooComponent extends SomeOtherClass {
              componentDidUpdate(Map prevProps, Map prevState${allowPartialUpgrades ? ', [snapshot]' : ''}) {
                // method body
              }
            }
          ''',
        );
      });

      test('-- has deprecated lifecycle methods without codemods', () {
        testSuggestor(
          expectedPatchCount: allowPartialUpgrades ? 1 : 0,
          input: '''
            @Component2()
            class FooComponent extends UiComponent2 {
              componentDidUpdate(Map prevProps, Map prevState) {
                // method body
              }
              
              @override
              componentWillReceiveProps() {}
            }
          ''',
          expectedOutput: '''
            @Component2()
            class FooComponent extends UiComponent2 {
              componentDidUpdate(Map prevProps, Map prevState${allowPartialUpgrades ? ', [snapshot]' : ''}) {
                // method body
              }
              
              @override
              componentWillReceiveProps() {}
            }
          ''',
        );
      });
    });

    group('in an abstract class', () {
      test(
          'that is fully upgradable ${shouldUpgradeAbstractComponents ? 'updates' : 'does not update'}',
          () {
        testSuggestor(
          expectedPatchCount: shouldUpgradeAbstractComponents ? 1 : 0,
          input: '''
          @AbstractComponent2()
          abstract class FooComponent extends UiComponent2 {
            componentDidUpdate(Map prevProps, Map prevState) {
              // method body
            }
          }
        ''',
          expectedOutput: '''
          @AbstractComponent2()
          abstract class FooComponent extends UiComponent2 {
            componentDidUpdate(Map prevProps, Map prevState${shouldUpgradeAbstractComponents ? ', [snapshot]' : ''}) {
              // method body
            }
          }
        ''',
        );
      });

      group(
          'that is not fully upgradable ${allowPartialUpgrades && shouldUpgradeAbstractComponents ? 'updates' : 'does not update'}',
          () {
        test('-- extends from non-Component class', () {
          testSuggestor(
            expectedPatchCount:
                allowPartialUpgrades && shouldUpgradeAbstractComponents ? 1 : 0,
            input: '''
              @AbstractProps()
              class AbstractFooProps extends UiProps {}
            
              @AbstractComponent2()
              class FooComponent extends SomeOtherClass {
                componentDidUpdate(Map prevProps, Map prevState) {
                  // method body
                }
              }
            ''',
            expectedOutput: '''
              @AbstractProps()
              class AbstractFooProps extends UiProps {}
              
              @AbstractComponent2()
              class FooComponent extends SomeOtherClass {
                componentDidUpdate(Map prevProps, Map prevState${allowPartialUpgrades && shouldUpgradeAbstractComponents ? ', [snapshot]' : ''}) {
                  // method body
                }
              }
            ''',
          );
        });

        test('-- has deprecated lifecycle methods without codemods', () {
          testSuggestor(
            expectedPatchCount:
                allowPartialUpgrades && shouldUpgradeAbstractComponents ? 1 : 0,
            input: '''
              @Component2
              class FooComponent<BarProps> extends UiComponent2<FooProps> {
                componentDidUpdate(Map prevProps, Map prevState) {
                  // method body
                }
                
                @override
                componentWillUpdate() {}
              }
            ''',
            expectedOutput: '''
              @Component2
              class FooComponent<BarProps> extends UiComponent2<FooProps> {
                componentDidUpdate(Map prevProps, Map prevState${allowPartialUpgrades && shouldUpgradeAbstractComponents ? ', [snapshot]' : ''}) {
                  // method body
                }
                
                @override
                componentWillUpdate() {}
              }
            ''',
          );
        });
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
}

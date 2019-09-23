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

import 'package:over_react_codemod/src/component2_suggestors/defaultprops_initialstate_migrator.dart';
import 'package:test/test.dart';

import '../util.dart';

main() {
  migratorTests(
      migratorName: 'GetDefaultPropsMigrator',
      methodToMigrate: 'getDefaultProps');
  migratorTests(
      migratorName: 'GetInitialStateMigrator',
      methodToMigrate: 'getInitialState');
}

void migratorTests({String migratorName, String methodToMigrate}) {
  group('$migratorName', () {
    componentDidUpdateTests(
      methodToMigrate: methodToMigrate,
    );
  });

  group('$migratorName with --no-partial-upgrades flag', () {
    componentDidUpdateTests(
      methodToMigrate: methodToMigrate,
      allowPartialUpgrades: false,
    );
  });

  group('$migratorName with --upgrade-abstract-components flag', () {
    componentDidUpdateTests(
      methodToMigrate: methodToMigrate,
      shouldUpgradeAbstractComponents: true,
    );
  });

  group(
      '$migratorName with --no-partial-upgrades and --upgrade-abstract-components flag',
      () {
    componentDidUpdateTests(
      methodToMigrate: methodToMigrate,
      allowPartialUpgrades: false,
      shouldUpgradeAbstractComponents: true,
    );
  });
}

void componentDidUpdateTests({
  bool allowPartialUpgrades = true,
  bool shouldUpgradeAbstractComponents = false,
  methodToMigrate,
}) {
  SuggestorTester testSuggestor;
  if (methodToMigrate == 'getDefaultProps') {
    testSuggestor = getSuggestorTester(GetDefaultPropsMigrator(
      allowPartialUpgrades: allowPartialUpgrades,
      shouldUpgradeAbstractComponents: shouldUpgradeAbstractComponents,
    ));
  } else {
    testSuggestor = getSuggestorTester(GetInitialStateMigrator(
      allowPartialUpgrades: allowPartialUpgrades,
      shouldUpgradeAbstractComponents: shouldUpgradeAbstractComponents,
    ));
  }

  String migrateTo;
  String subMethod;
  if (methodToMigrate == 'getDefaultProps') {
    migrateTo = 'defaultProps';
    subMethod = 'newProps';
  } else {
    migrateTo = 'initialState';
    subMethod = 'newState';
  }

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

  test('$methodToMigrate method', () {
    testSuggestor(
      expectedPatchCount: 4,
      input: '''
        @Component2()
        class FooComponent extends UiStatefulComponent2 {
          @override
          Map $methodToMigrate() => $subMethod()..value = true;
        }
      ''',
      expectedOutput: '''
        @Component2()
        class FooComponent extends UiStatefulComponent2 {
          @override
          get $migrateTo => ($subMethod()..value = true);
        }
      ''',
    );
  });

  test('$methodToMigrate method without return type', () {
    testSuggestor(
      expectedPatchCount: 3,
      input: '''
        @Component2()
        class FooComponent extends UiStatefulComponent2 {
          @override
          $methodToMigrate() => $subMethod()..value = true;
        }
      ''',
      expectedOutput: '''
        @Component2()
        class FooComponent extends UiStatefulComponent2 {
          @override
          get $migrateTo => ($subMethod()..value = true);
        }
      ''',
    );
  });

  test('$methodToMigrate method with super call', () {
    testSuggestor(
      expectedPatchCount: 5,
      input: '''
        @Component2()
        class FooComponent extends UiStatefulComponent2 {
          @override
          Map $methodToMigrate() => $subMethod()..addAll(super.$methodToMigrate());
        }
      ''',
      expectedOutput: '''
        @Component2()
        class FooComponent extends UiStatefulComponent2 {
          @override
          get $migrateTo => ($subMethod()..addAll(super.$migrateTo));
        }
      ''',
    );
  });

  test('$methodToMigrate method with block body', () {
    testSuggestor(
      expectedPatchCount: 2,
      input: '''
        @Component2()
        class FooComponent extends UiStatefulComponent2 {
          @override
          Map $methodToMigrate() {
            var a = 1;
            return $subMethod()
              ..sub1 = '<value>'
              ..sub2 = '<value>';
          }
        }
      ''',
      expectedOutput: '''
        @Component2()
        class FooComponent extends UiStatefulComponent2 {
          @override
          get $migrateTo {
            var a = 1;
            return $subMethod()
              ..sub1 = '<value>'
              ..sub2 = '<value>';
          }
        }
      ''',
    );
  });

  test('$methodToMigrate method with just return statement method body', () {
    testSuggestor(
      expectedPatchCount: 6,
      input: '''
        @Component2()
        class FooComponent extends UiStatefulComponent2 {
          @override
          Map $methodToMigrate() {
            return $subMethod()
              ..addAll(super.$methodToMigrate())
              ..sub1 = '<value>'
              ..sub2 = '<value>';
          }
        }
      ''',
      expectedOutput: '''
        @Component2()
        class FooComponent extends UiStatefulComponent2 {
          @override
          get $migrateTo => ($subMethod()
            ..addAll(super.$migrateTo)
            ..sub1 = '<value>'
            ..sub2 = '<value>'
          );
        }
      ''',
    );
  });

  test('$methodToMigrate with existing parenthesis', () {
    testSuggestor(
      expectedPatchCount: 3,
      input: '''
        @Component2()
        class FooComponent extends FluxUiStatefulComponent2 {
          @override
          Map $methodToMigrate() => ($subMethod()..addAll(super.$methodToMigrate()));
        }
      ''',
      expectedOutput: '''
        @Component2()
        class FooComponent extends FluxUiStatefulComponent2 {
          @override
          get $migrateTo => ($subMethod()..addAll(super.$migrateTo));
        }
      ''',
    );
  });

  group(
      '$methodToMigrate method ${allowPartialUpgrades ? 'updates' : 'does not update'} if '
      'containing class is not fully upgradable', () {
    test('-- extends from non-Component class', () {
      testSuggestor(
        expectedPatchCount: allowPartialUpgrades ? 4 : 0,
        input: '''
          @Component2()
          class FooComponent extends SomeOtherClass {
            @override
            Map $methodToMigrate() => $subMethod()..value = true;
          }
        ''',
        expectedOutput: '''
          @Component2()
          class FooComponent extends SomeOtherClass {
            @override
            ${allowPartialUpgrades ? 'get $migrateTo => ($subMethod()..value = true);' : 'Map $methodToMigrate() => $subMethod()..value = true;'}
          }
        ''',
      );
    });

    test('-- has lifecycle methods without codemods', () {
      testSuggestor(
        expectedPatchCount: allowPartialUpgrades ? 5 : 0,
        input: '''
          @Component2()
          class FooComponent extends UiStatefulComponent2 {
            @override
            Map $methodToMigrate() => $subMethod()..addProps(super.$methodToMigrate());
            
            @override
            componentWillUpdate() {}
          }
        ''',
        expectedOutput: '''
          @Component2()
          class FooComponent extends UiStatefulComponent2 {
            @override
            ${allowPartialUpgrades ? 'get $migrateTo => ($subMethod()..addProps(super.$migrateTo));' : 'Map $methodToMigrate() => $subMethod()..addProps(super.$methodToMigrate());'}
            
            @override
            componentWillUpdate() {}
          }
        ''',
      );
    });
  });

  group('$methodToMigrate method in an abstract class', () {
    test('that is fully upgradable', () {
      testSuggestor(
        expectedPatchCount: shouldUpgradeAbstractComponents ? 4 : 0,
        input: '''
          @AbstractComponent2()
          abstract class FooComponent extends UiStatefulComponent2 {
            @override
            Map $methodToMigrate() => $subMethod()..value = true;
          }
        ''',
        expectedOutput: '''
          @AbstractComponent2()
          abstract class FooComponent extends UiStatefulComponent2 {
            @override
            ${shouldUpgradeAbstractComponents ? 'get $migrateTo => ($subMethod()..value = true);' : 'Map $methodToMigrate() => $subMethod()..value = true;'} 
          }
        ''',
      );
    });

    group('that is not fully upgradable', () {
      test('--extends from a non-Component class', () {
        testSuggestor(
          expectedPatchCount:
              allowPartialUpgrades && shouldUpgradeAbstractComponents ? 5 : 0,
          input: '''
            @Component2
            class FooComponent<BarProps> extends SomeOtherClass<FooProps> {
              @override
              Map $methodToMigrate() {
                return $subMethod()
                  ..sub1 = '<value>'
                  ..sub2 = '<value>';
              }
            }
          ''',
          expectedOutput:
              allowPartialUpgrades && shouldUpgradeAbstractComponents
                  ? '''
            @Component2
            class FooComponent<BarProps> extends SomeOtherClass<FooProps> {
              @override
              get $migrateTo => ($subMethod()
                ..sub1 = '<value>'
                ..sub2 = '<value>'
              );
            }
          '''
                  : '''
            @Component2
            class FooComponent<BarProps> extends SomeOtherClass<FooProps> {
              @override
              Map $methodToMigrate() {
                return $subMethod()
                  ..sub1 = '<value>'
                  ..sub2 = '<value>';
              }
            }
          ''',
        );
      });

      test('-- has lifecycle methods without codemods', () {
        testSuggestor(
          expectedPatchCount:
              allowPartialUpgrades && shouldUpgradeAbstractComponents ? 4 : 0,
          input: '''
            @AbstractProps()
            class AbstractFooProps extends UiProps {}
            
            @AbstractComponent2()
            class FooComponent extends UiStatefulComponent2 {
              @override
              Map $methodToMigrate() => $subMethod()..value = true;
              
              @override
              componentWillUpdate() {}
            }
          ''',
          expectedOutput: '''
            @AbstractProps()
            class AbstractFooProps extends UiProps {}
            
            @AbstractComponent2()
            class FooComponent extends UiStatefulComponent2 {
              @override
              ${shouldUpgradeAbstractComponents && allowPartialUpgrades ? 'get $migrateTo => ($subMethod()..value = true);' : 'Map $methodToMigrate() => $subMethod()..value = true;'} 
                
              @override
              componentWillUpdate() {}
            }
          ''',
        );
      });
    });
  });

  test('$methodToMigrate method that does not use $subMethod', () {
    testSuggestor(
      expectedPatchCount: 2,
      input: '''
        @Component2()
        class FooComponent extends UiStatefulComponent2 {
          @override
          Map $methodToMigrate() => {};
        }
      ''',
      expectedOutput: '''
        @Component2()
        class FooComponent extends UiStatefulComponent2 {
          @override
          get $migrateTo => {};
        }
      ''',
    );
  });

  test('$migrateTo method does not change if already updated', () {
    testSuggestor(
      expectedPatchCount: 0,
      input: '''
        @Component2()
        class FooComponent extends UiStatefulComponent2 {
          @override
          get $migrateTo => $subMethod()..value = true;
        }
      ''',
    );
  });

  test('does not change $methodToMigrate method for non-component2 classes',
      () {
    testSuggestor(
      expectedPatchCount: 0,
      input: '''
        @Component()
        class FooComponent extends UiStatefulComponent {
          @override
          Map $methodToMigrate() => $subMethod()..value = true;
        }
      ''',
    );
  });
}

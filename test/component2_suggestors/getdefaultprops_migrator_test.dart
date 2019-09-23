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

import 'package:over_react_codemod/src/component2_suggestors/getdefaultprops_migrator.dart';
import 'package:test/test.dart';

import '../util.dart';

main() {
  group('GetDefaultPropsMigrator', () {
    componentDidUpdateTests();
  });

  group('GetDefaultPropsMigrator with --no-partial-upgrades flag', () {
    componentDidUpdateTests(allowPartialUpgrades: false);
  });

  group('GetDefaultPropsMigrator with --upgrade-abstract-components flag', () {
    componentDidUpdateTests(shouldUpgradeAbstractComponents: true);
  });

  group(
      'GetDefaultPropsMigrator with --no-partial-upgrades and --upgrade-abstract-components flag',
      () {
    componentDidUpdateTests(
        allowPartialUpgrades: false, shouldUpgradeAbstractComponents: true);
  });
}

void componentDidUpdateTests({
  bool allowPartialUpgrades = true,
  bool shouldUpgradeAbstractComponents = false,
}) {
  final testSuggestor = getSuggestorTester(GetDefaultPropsMigrator(
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

  test('getDefaultProps method', () {
    testSuggestor(
      expectedPatchCount: 4,
      input: '''
        @Component2()
        class FooComponent extends UiComponent2 {
          @override
          Map getDefaultProps() => newProps()..prop1 = true;
        }
      ''',
      expectedOutput: '''
        @Component2()
        class FooComponent extends UiComponent2 {
          @override
          get defaultProps => (newProps()..prop1 = true);
        }
      ''',
    );
  });

  test('getDefaultProps method without return type', () {
    testSuggestor(
      expectedPatchCount: 3,
      input: '''
        @Component2()
        class FooComponent extends UiComponent2 {
          @override
          getDefaultProps() => newProps()..prop1 = true;
        }
      ''',
      expectedOutput: '''
        @Component2()
        class FooComponent extends UiComponent2 {
          @override
          get defaultProps => (newProps()..prop1 = true);
        }
      ''',
    );
  });

  test('getDefaultProps method with super call', () {
    testSuggestor(
      expectedPatchCount: 5,
      input: '''
        @Component2()
        class FooComponent extends UiComponent2 {
          @override
          Map getDefaultProps() => newProps()..addProps(super.getDefaultProps());
        }
      ''',
      expectedOutput: '''
        @Component2()
        class FooComponent extends UiComponent2 {
          @override
          get defaultProps => (newProps()..addProps(super.defaultProps));
        }
      ''',
    );
  });

  test('getDefaultProps method with block body', () {
    testSuggestor(
      expectedPatchCount: 2,
      input: '''
        @Component2()
        class FooComponent extends UiComponent2 {
          @override
          Map getDefaultProps() {
            var a = 1;
            return newProps()
              ..superProp = '<the super prop value>'
              ..subProp = '<the sub prop value>';
          }
        }
      ''',
      expectedOutput: '''
        @Component2()
        class FooComponent extends UiComponent2 {
          @override
          get defaultProps {
            var a = 1;
            return newProps()
              ..superProp = '<the super prop value>'
              ..subProp = '<the sub prop value>';
          }
        }
      ''',
    );
  });

  test('getDefaultProps method with just return statement method body', () {
    testSuggestor(
      expectedPatchCount: 6,
      input: '''
        @Component2()
        class FooComponent extends UiStatefulComponent2 {
          @override
          Map getDefaultProps() {
            return newProps()
              ..addProps(super.getDefaultProps())
              ..superProp = '<the super prop value>'
              ..subProp = '<the sub prop value>';
          }
        }
      ''',
      expectedOutput: '''
        @Component2()
        class FooComponent extends UiStatefulComponent2 {
          @override
          get defaultProps => (newProps()
            ..addProps(super.defaultProps)
            ..superProp = '<the super prop value>'
            ..subProp = '<the sub prop value>'
          );
        }
      ''',
    );
  });

  test('getDefaultProps with existing parenthesis', () {
    testSuggestor(
      expectedPatchCount: 3,
      input: '''
        @Component2()
        class FooComponent extends FluxUiComponent2 {
          @override
          Map getDefaultProps() => (newProps()..addAll(super.getDefaultProps()));
        }
      ''',
      expectedOutput: '''
        @Component2()
        class FooComponent extends FluxUiComponent2 {
          @override
          get defaultProps => (newProps()..addAll(super.defaultProps));
        }
      ''',
    );
  });

  group(
      'getDefaultProps method ${allowPartialUpgrades ? 'updates' : 'does not update'} if '
      'containing class is not fully upgradable', () {
    test('-- extends from non-Component class', () {
      testSuggestor(
        expectedPatchCount: allowPartialUpgrades ? 4 : 0,
        input: '''
          @Component2()
          class FooComponent extends SomeOtherClass {
            @override
            Map getDefaultProps() => newProps()..prop1 = true;
          }
        ''',
        expectedOutput: '''
          @Component2()
          class FooComponent extends SomeOtherClass {
            @override
            ${allowPartialUpgrades ? 'get defaultProps => (newProps()..prop1 = true);' : 'Map getDefaultProps() => newProps()..prop1 = true;'}
          }
        ''',
      );
    });

    test('-- has lifecycle methods without codemods', () {
      testSuggestor(
        expectedPatchCount: allowPartialUpgrades ? 5 : 0,
        input: '''
          @Component2()
          class FooComponent extends UiComponent2 {
            @override
            Map getDefaultProps() => newProps()..addProps(super.getDefaultProps());
            
            @override
            componentWillUpdate() {}
          }
        ''',
        expectedOutput: '''
          @Component2()
          class FooComponent extends UiComponent2 {
            @override
            ${allowPartialUpgrades ? 'get defaultProps => (newProps()..addProps(super.defaultProps));' : 'Map getDefaultProps() => newProps()..addProps(super.getDefaultProps());'}
            
            @override
            componentWillUpdate() {}
          }
        ''',
      );
    });
  });

  group('getDefaultProps method in an abstract class', () {
    test('that is fully upgradable', () {
      testSuggestor(
        expectedPatchCount: shouldUpgradeAbstractComponents ? 4 : 0,
        input: '''
          @AbstractComponent2()
          abstract class FooComponent extends UiComponent2 {
            @override
            Map getDefaultProps() => newProps()..prop1 = true;
          }
        ''',
        expectedOutput: '''
          @AbstractComponent2()
          abstract class FooComponent extends UiComponent2 {
            @override
            ${shouldUpgradeAbstractComponents ? 'get defaultProps => (newProps()..prop1 = true);' : 'Map getDefaultProps() => newProps()..prop1 = true;'} 
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
              Map getDefaultProps() {
                return newProps()
                  ..superProp = '<the super prop value>'
                  ..subProp = '<the sub prop value>';
              }
            }
          ''',
          expectedOutput:
              allowPartialUpgrades && shouldUpgradeAbstractComponents
                  ? '''
            @Component2
            class FooComponent<BarProps> extends SomeOtherClass<FooProps> {
              @override
              get defaultProps => (newProps()
                ..superProp = '<the super prop value>'
                ..subProp = '<the sub prop value>'
              );
            }
          '''
                  : '''
            @Component2
            class FooComponent<BarProps> extends SomeOtherClass<FooProps> {
              @override
              Map getDefaultProps() {
                return newProps()
                  ..superProp = '<the super prop value>'
                  ..subProp = '<the sub prop value>';
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
            class FooComponent extends UiComponent2 {
              @override
              Map getDefaultProps() => newProps()..prop1 = true;
              
              @override
              componentWillUpdate() {}
            }
          ''',
          expectedOutput: '''
            @AbstractProps()
            class AbstractFooProps extends UiProps {}
            
            @AbstractComponent2()
            class FooComponent extends UiComponent2 {
              @override
              ${shouldUpgradeAbstractComponents && allowPartialUpgrades ? 'get defaultProps => (newProps()..prop1 = true);' : 'Map getDefaultProps() => newProps()..prop1 = true;'} 
                
              @override
              componentWillUpdate() {}
            }
          ''',
        );
      });
    });
  });

  test('getDefaultProps method that does not use newProps', () {
    testSuggestor(
      expectedPatchCount: 2,
      input: '''
        @Component2()
        class FooComponent extends UiComponent2 {
          @override
          Map getDefaultProps() => {};
        }
      ''',
      expectedOutput: '''
        @Component2()
        class FooComponent extends UiComponent2 {
          @override
          get defaultProps => {};
        }
      ''',
    );
  });

  test('getDefaultProps method does not change if already updated', () {
    testSuggestor(
      expectedPatchCount: 0,
      input: '''
        @Component2()
        class FooComponent extends UiComponent2 {
          @override
          get defaultProps => newProps()..prop1 = true;
        }
      ''',
    );
  });

  test('does not change getDefaultProps method for non-component2 classes', () {
    testSuggestor(
      expectedPatchCount: 0,
      input: '''
        @Component()
        class FooComponent extends UiComponent {
          @override
          Map getDefaultProps() => newProps()..prop1 = true;
        }
      ''',
    );
  });
}

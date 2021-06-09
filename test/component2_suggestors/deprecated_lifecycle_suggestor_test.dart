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

import 'package:over_react_codemod/src/component2_suggestors/component2_constants.dart';
import 'package:over_react_codemod/src/component2_suggestors/deprecated_lifecycle_suggestor.dart';
import 'package:test/test.dart';

import '../util.dart';

main() {
  group('DeprecatedLifecycleSuggestor', () {
    deprecatedLifecycleTests();
  });

  group('DeprecatedLifecycleSuggestor with --no-partial-upgrades flag', () {
    deprecatedLifecycleTests(allowPartialUpgrades: false);
  });

  group('DeprecatedLifecycleSuggestor with --upgrade-abstract-components flag',
      () {
    deprecatedLifecycleTests(shouldUpgradeAbstractComponents: true);
  });

  group(
      'DeprecatedLifecycleSuggestor with --no-partial-upgrades and --upgrade-abstract-components flag',
      () {
    deprecatedLifecycleTests(
        allowPartialUpgrades: false, shouldUpgradeAbstractComponents: true);
  });
}

deprecatedLifecycleTests({
  bool allowPartialUpgrades = true,
  bool shouldUpgradeAbstractComponents = false,
}) {
  final testSuggestor = getSuggestorTester(DeprecatedLifecycleSuggestor(
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

  group('${allowPartialUpgrades ? 'adds' : 'does not add'} a FIXME comment',
      () {
    test('for componentWillUpdate with override', () {
      testSuggestor(
        expectedPatchCount: allowPartialUpgrades ? 1 : 0,
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
            ${allowPartialUpgrades ? getDeperecationMessage('componentWillUpdate') : ''}
            @override
            componentWillUpdate(){}
          }
        ''',
      );
    });

    test('componentWillUpdate without override', () {
      testSuggestor(
        expectedPatchCount: allowPartialUpgrades ? 1 : 0,
        input: '''
          @Component2()
          class FooComponent extends FluxUiComponent2 {
            componentWillUpdate(){}
          }
        ''',
        expectedOutput: '''
          @Component2()
          class FooComponent extends FluxUiComponent2 {
            ${allowPartialUpgrades ? getDeperecationMessage('componentWillUpdate') : ''}
            componentWillUpdate(){}
          }
        ''',
      );
    });

    test('componentWillUpdate in an abstract class', () {
      testSuggestor(
        expectedPatchCount:
            allowPartialUpgrades && shouldUpgradeAbstractComponents ? 1 : 0,
        input: '''
          @Component2
          class FooComponent<BarProps> extends FluxUiComponent2<FooProps> {
            @override
            componentWillUpdate(){}
          }
        ''',
        expectedOutput: '''
          @Component2
          class FooComponent<BarProps> extends FluxUiComponent2<FooProps> {
            ${allowPartialUpgrades && shouldUpgradeAbstractComponents ? getDeperecationMessage('componentWillUpdate') : ''}
            @override
            componentWillUpdate(){}
          }
        ''',
      );
    });

    test('componentWillReceiveProps with override', () {
      testSuggestor(
        expectedPatchCount: allowPartialUpgrades ? 1 : 0,
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
            ${allowPartialUpgrades ? getDeperecationMessage('componentWillReceiveProps') : ''}
            @override
            componentWillReceiveProps(){}
          }
        ''',
      );
    });

    test('componentWillReceiveProps without override', () {
      testSuggestor(
        expectedPatchCount: allowPartialUpgrades ? 1 : 0,
        input: '''
          @Component2()
          class FooComponent extends FluxUiStatefulComponent2 {
            componentWillReceiveProps(){}
          }
        ''',
        expectedOutput: '''
          @Component2()
          class FooComponent extends FluxUiStatefulComponent2 {
            ${allowPartialUpgrades ? getDeperecationMessage('componentWillReceiveProps') : ''}
            componentWillReceiveProps(){}
          }
        ''',
      );
    });

    test('componentWillReceiveProps in an abstract class', () {
      testSuggestor(
        expectedPatchCount:
            allowPartialUpgrades && shouldUpgradeAbstractComponents ? 1 : 0,
        input: '''
          @AbstractComponent2()
          abstract class FooComponent extends FluxUiStatefulComponent2 {
            @override
            componentWillReceiveProps(){}
          }
        ''',
        expectedOutput: '''
          @AbstractComponent2()
          abstract class FooComponent extends FluxUiStatefulComponent2 {
            ${allowPartialUpgrades && shouldUpgradeAbstractComponents ? getDeperecationMessage('componentWillReceiveProps') : ''}
            @override
            componentWillReceiveProps(){}
          }
        ''',
      );
    });

    test(
        'when both componentWillUpdate and componentWillReceiveProps is present',
        () {
      testSuggestor(
        expectedPatchCount: allowPartialUpgrades ? 2 : 0,
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
            ${allowPartialUpgrades ? getDeperecationMessage('componentWillUpdate') : ''}
            @override
            componentWillUpdate(){}
        
            ${allowPartialUpgrades ? getDeperecationMessage('componentWillReceiveProps') : ''}
            @override
            componentWillReceiveProps(){}
          }
        ''',
      );
    });
  });
}

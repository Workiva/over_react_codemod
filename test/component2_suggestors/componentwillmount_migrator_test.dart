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

import 'package:over_react_codemod/src/component2_suggestors/componentwillmount_migrator.dart';
import 'package:test/test.dart';

import '../util.dart';

main() {
  group('ComponentWillMountMigrator', () {
    componentWillMountTests(allowPartialUpgrades: true);
  });

  group('ComponentWillMountMigrator with --no-partial-upgrades flag', () {
    componentWillMountTests(allowPartialUpgrades: false);
  });
}

componentWillMountTests({bool allowPartialUpgrades}) {
  final testSuggestor = getSuggestorTester(
      ComponentWillMountMigrator(allowPartialUpgrades: allowPartialUpgrades));

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

  group('componentWillMount method', () {
    test('updates if containing class is fully upgradable', () {
      testSuggestor(
        expectedPatchCount: 1,
        input: '''
          @Component2()
          class FooComponent extends UiComponent2 {
            componentWillMount(){
              // method body
            }
          }
        ''',
        expectedOutput: '''
          @Component2()
          class FooComponent extends UiComponent2 {
            init(){
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
            class FooComponent extends AbstractComponent {
              componentWillMount(){
                // method body
              }
            }
          ''',
          expectedOutput: '''
            @Component2()
            class FooComponent extends AbstractComponent {
              ${allowPartialUpgrades ? 'init' : 'componentWillMount'}(){
                // method body
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
              componentWillMount(){
                // method body
              }
              
              @override
              componentWillUnmount() {}
            }
          ''',
          expectedOutput: '''
            @Component2()
            class FooComponent extends UiComponent2 {
              ${allowPartialUpgrades ? 'init' : 'componentWillMount'}(){
                // method body
              }
              
              @override
              componentWillUnmount() {}
            }
          ''',
        );
      });
    });
  });

  test('componentWillMount method with return type updates', () {
    testSuggestor(
      expectedPatchCount: 1,
      input: '''
        import 'package:react/react.dart' as react;

        @Component2()
        class FooComponent extends react.Component2 {
          void componentWillMount(){
            // method body
          }
        }
      ''',
      expectedOutput: '''
        import 'package:react/react.dart' as react;

        @Component2()
        class FooComponent extends react.Component2 {
          void init(){
            // method body
          }
        }
      ''',
    );
  });

  group('super calls to componentWillMount', () {
    test('are removed if containing class is fully upgradable', () {
      testSuggestor(
        expectedPatchCount: 2,
        input: '''
          @Component2()
          class FooComponent extends UiComponent2 {
            void componentWillMount(){
              super.componentWillMount();
              // method body
            }
          }
        ''',
        expectedOutput: '''
          @Component2()
          class FooComponent extends UiComponent2 {
            void init(){
              // method body
            }
          }
        ''',
      );
    });

    group(
        'are ${allowPartialUpgrades ? '' : 'not '}removed if containing class'
        ' is not fully upgradable', () {
      test('-- extends from non-Component class', () {
        testSuggestor(
          expectedPatchCount: allowPartialUpgrades ? 2 : 0,
          input: '''
            @Component2()
            class FooComponent extends AbstractComponent {
              void componentWillMount(){
                super.componentWillMount();
                // method body
              }
            }
          ''',
          expectedOutput: '''
            @Component2()
            class FooComponent extends AbstractComponent {
              void ${allowPartialUpgrades ? 'init' : 'componentWillMount'}(){
                ${allowPartialUpgrades ? '' : 'super.componentWillMount();'}
                // method body
              }
            }
          ''',
        );
      });

      test('-- has lifecycle methods without codemods', () {
        testSuggestor(
          expectedPatchCount: allowPartialUpgrades ? 2 : 0,
          input: '''
            @Component2()
            class FooComponent extends UiComponent2 {
              void componentWillMount(){
                super.componentWillMount();
                // method body
              }
              
              @override
              componentWillUnmount() {}
            }
          ''',
          expectedOutput: '''
            @Component2()
            class FooComponent extends UiComponent2 {
              void ${allowPartialUpgrades ? 'init' : 'componentWillMount'}(){
                ${allowPartialUpgrades ? '' : 'super.componentWillMount();'}
                // method body
              }
              
              @override
              componentWillUnmount() {}
            }
          ''',
        );
      });
    });
  });

  test('does not change componentWillMount for non-component2 classes', () {
    testSuggestor(
      expectedPatchCount: 0,
      input: '''
        @Component()
        class FooComponent extends UiComponent {
          void componentWillMount(){
            // method body
          }
        }
      ''',
    );
  });
}

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
import 'package:over_react_codemod/src/component2_suggestors/componentwillmount_migrator.dart';
import 'package:test/test.dart';

import '../util.dart';

main() {
  group('ComponentWillMountMigrator', () {
    componentWillMountTests();
  });

  group('ComponentWillMountMigrator with --no-partial-upgrades flag', () {
    componentWillMountTests(allowPartialUpgrades: false);
  });

  group('ComponentWillMountMigrator with --upgrade-abstract-components flag',
      () {
    componentWillMountTests(shouldUpgradeAbstractComponents: true);
  });

  group(
      'ComponentWillMountMigrator with --no-partial-upgrades and --upgrade-abstract-components flag',
      () {
    componentWillMountTests(
        allowPartialUpgrades: false, shouldUpgradeAbstractComponents: true);
  });
}

componentWillMountTests({
  bool allowPartialUpgrades = true,
  bool shouldUpgradeAbstractComponents = false,
}) {
  final testSuggestor = getSuggestorTester(ComponentWillMountMigrator(
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

  group('when componentDidMount does not exist in containing class', () {
    group('componentWillMount method', () {
      test('updates if containing class is fully upgradable', () {
        testSuggestor(
          expectedPatchCount: 2,
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
              $componentWillMountMessage
              componentDidMount(){
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
            expectedPatchCount: allowPartialUpgrades ? 2 : 0,
            input: '''
              @Component2()
              class FooComponent extends SomeOtherClass {
                componentWillMount(){
                  // method body
                }
              }
            ''',
            expectedOutput: '''
              @Component2()
              class FooComponent extends SomeOtherClass {
                ${allowPartialUpgrades ? '$componentWillMountMessage\ncomponentDidMount' : 'componentWillMount'}(){
                  // method body
                }
              }
            ''',
          );
        });

        test('-- has deprecated lifecycle methods without codemods', () {
          testSuggestor(
            expectedPatchCount: allowPartialUpgrades ? 2 : 0,
            input: '''
            @Component2()
            class FooComponent extends UiComponent2 {
              componentWillMount(){
                // method body
              }
              
              @override
              componentWillReceiveProps() {}
            }
          ''',
            expectedOutput: '''
            @Component2()
            class FooComponent extends UiComponent2 {
              ${allowPartialUpgrades ? '$componentWillMountMessage\ncomponentDidMount' : 'componentWillMount'}(){
                // method body
              }
              
              @override
              componentWillReceiveProps() {}
            }
          ''',
          );
        });
      });

      test('componentWillMount method with return type', () {
        testSuggestor(
          expectedPatchCount: 2,
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
            $componentWillMountMessage
            void componentDidMount(){
              // method body
            }
          }
        ''',
        );
      });

      test('update super calls', () {
        testSuggestor(
          expectedPatchCount: 3,
          input: '''
          @Component2()
          class FooComponent extends FluxUiComponent2 {
            void componentWillMount(){
              super.componentWillMount();
              // method body
            }
          }
        ''',
          expectedOutput: '''
          @Component2()
          class FooComponent extends FluxUiComponent2 {
            $componentWillMountMessage
            void componentDidMount(){
              super.componentDidMount();
              // method body
            }
          }
        ''',
        );
      });
    });
  });

  group('when componentDidMount exists in containing class', () {
    group('componentWillMount method', () {
      test('updates if containing class is fully upgradable', () {
        testSuggestor(
          expectedPatchCount: 2,
          input: '''
            @Component2()
            class FooComponent extends UiComponent2 {
              @override
              componentWillMount() {
                var a = 1;
                var b = 2;
              }
              
              @override
              componentDidMount() {
                var c = 3;
                var d = 4;
              }
            }
          ''',
          expectedOutput: '''
            @Component2()
            class FooComponent extends UiComponent2 {
              @override
              componentDidMount() {
                var a = 1;
                var b = 2;
                
                var c = 3;
                var d = 4;
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
            expectedPatchCount: allowPartialUpgrades ? 2 : 0,
            input: '''
              @Component2()
              class FooComponent extends SomeOtherClass {
                @override
                componentWillMount() {
                  var a = 1;
                  var b = 2;
                }
                
                @override
                componentDidMount() {
                  var c = 3;
                  var d = 4;
                }
              }
            ''',
            expectedOutput: allowPartialUpgrades
                ? '''
              @Component2()
              class FooComponent extends SomeOtherClass {
                @override
                componentDidMount() {
                  var a = 1;
                  var b = 2;
                  
                  var c = 3;
                  var d = 4;
                }
              }
            '''
                : '''
              @Component2()
              class FooComponent extends SomeOtherClass {
                @override
                componentWillMount() {
                  var a = 1;
                  var b = 2;
                }
                
                @override
                componentDidMount() {
                  var c = 3;
                  var d = 4;
                }
              }
            ''',
          );
        });

        test('-- has deprecated lifecycle methods without codemods', () {
          testSuggestor(
            expectedPatchCount: allowPartialUpgrades ? 2 : 0,
            input: '''
              @Component2()
              class FooComponent extends UiComponent2 {
                @override
                componentWillMount() {
                  var a = 1;
                  var b = 2;
                }
                
                @override
                componentDidMount() {
                  var c = 3;
                  var d = 4;
                }
                
                @override
                componentWillUpdate() {}
              }
            ''',
            expectedOutput: allowPartialUpgrades
                ? '''
              @Component2()
              class FooComponent extends UiComponent2 {
                @override
                componentDidMount() {
                  var a = 1;
                  var b = 2;
                  
                  var c = 3;
                  var d = 4;
                }
                
                @override
                componentWillUpdate() {}
              }
            '''
                : '''
              @Component2()
              class FooComponent extends UiComponent2 {
                @override
                componentWillMount() {
                  var a = 1;
                  var b = 2;
                }
                
                @override
                componentDidMount() {
                  var c = 3;
                  var d = 4;
                }
                
                @override
                componentWillUpdate() {}
              }
            ''',
          );
        });
      });

      test('update super call to componentWillMount if not already existing',
          () {
        testSuggestor(
          expectedPatchCount: 3,
          input: '''
            @Component2()
            class FooComponent extends FluxUiComponent2 {
              @override
              void componentDidMount() {
                var c = 3;
                var d = 4;
              }
              
              @override
              void componentWillMount() {
                super.componentWillMount();
                var a = 1;
                var b = 2;
              }
            }
          ''',
          expectedOutput: '''
            @Component2()
            class FooComponent extends FluxUiComponent2 {
              $componentWillMountMessage
              @override
              void componentDidMount() {
                super.componentDidMount();
                var a = 1;
                var b = 2;
                
                var c = 3;
                var d = 4;
              }
            }
          ''',
        );
      });

      test('remove super call if it already exists in componentDidMount', () {
        testSuggestor(
          expectedPatchCount: 2,
          input: '''
            @Component2()
            class FooComponent extends FluxUiComponent2 {
              @override
              @mustCallSuper
              componentDidMount() {
                super.componentDidMount();
                var c = 3;
                var d = 4;
              }
              
              @override
              componentWillMount() {
                super.componentWillMount();
                var a = 1;
                var b = 2;
              }
            }
          ''',
          expectedOutput: '''
            @Component2()
            class FooComponent extends FluxUiComponent2 {
              @override
              @mustCallSuper
              componentDidMount() {
                var a = 1;
                var b = 2;
                
                super.componentDidMount();
                var c = 3;
                var d = 4;
              }
            }
          ''',
        );
      });

      test('copy any annotations not already present to componentDidMount', () {
        testSuggestor(
          expectedPatchCount: 3,
          input: '''
            @Component2()
            class FooComponent extends FluxUiComponent2 {
              @override
              componentDidMount() {
                // `componentDidMount` method body
              }
              
              @override
              @mustCallSuper
              componentWillMount() {
                // `componentWillMount` method body
              }
            }
          ''',
          expectedOutput: '''
            @Component2()
            class FooComponent extends FluxUiComponent2 {
              @mustCallSuper
              @override
              componentDidMount() {
                // `componentWillMount` method body
                
                // `componentDidMount` method body
              }
            }
          ''',
        );
      });

      test('copy any annotations to annotationless componentDidMount', () {
        testSuggestor(
          expectedPatchCount: 3,
          input: '''
            @Component2()
            class FooComponent extends FluxUiComponent2 {
              componentDidMount() {
                var c = 3;
              }
              
              @override
              @mustCallSuper
              componentWillMount() {
                var a = 1;
              }
            }
          ''',
          expectedOutput: '''
            @Component2()
            class FooComponent extends FluxUiComponent2 {
              @override
              @mustCallSuper
              componentDidMount() {
                var a = 1;
                
                var c = 3;
              }
            }
          ''',
        );
      });
    });
  });

  group('componentWillMount method in an abstract class', () {
    test(
        'that is fully upgradable ${shouldUpgradeAbstractComponents ? 'updates' : 'does not update'}',
        () {
      testSuggestor(
        expectedPatchCount:
            allowPartialUpgrades && shouldUpgradeAbstractComponents ? 2 : 0,
        input: '''
          @AbstractComponent2()
          abstract class FooComponent extends SomeOtherClass {
            @override
            componentWillMount() {
              var a = 1;
              var b = 2;
            }
            
            @override
            componentDidMount() {
              var c = 3;
              var d = 4;
            }
          }
        ''',
        expectedOutput: allowPartialUpgrades && shouldUpgradeAbstractComponents
            ? '''
          @AbstractComponent2()
          abstract class FooComponent extends SomeOtherClass {
            @override
            componentDidMount() {
              var a = 1;
              var b = 2;
              
              var c = 3;
              var d = 4;
            }
          }
        '''
            : '''
          @AbstractComponent2()
          abstract class FooComponent extends SomeOtherClass {
            @override
            componentWillMount() {
              var a = 1;
              var b = 2;
            }
            
            @override
            componentDidMount() {
              var c = 3;
              var d = 4;
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
              allowPartialUpgrades && shouldUpgradeAbstractComponents ? 2 : 0,
          input: '''
          @Component2
          class FooComponent<BarProps> extends SomeOtherClass<FooProps> {
            componentWillMount(){
              // method body
            }
          }
        ''',
          expectedOutput: '''
          @Component2
          class FooComponent<BarProps> extends SomeOtherClass<FooProps> {
            ${allowPartialUpgrades && shouldUpgradeAbstractComponents ? '$componentWillMountMessage\ncomponentDidMount' : 'componentWillMount'}(){
              // method body
            }
          }
        ''',
        );
      });

      test('-- has lifecycle methods without codemods', () {
        testSuggestor(
          expectedPatchCount:
              allowPartialUpgrades && shouldUpgradeAbstractComponents ? 2 : 0,
          input: '''
            @AbstractComponent2()
            abstract class FooComponent extends UiComponent2 {
              componentWillMount(){
                // method body
              }
              
              @override
              componentWillReceiveProps() {}
            }
          ''',
          expectedOutput: '''
            @AbstractComponent2()
            abstract class FooComponent extends UiComponent2 {
              ${allowPartialUpgrades && shouldUpgradeAbstractComponents ? '$componentWillMountMessage\ncomponentDidMount' : 'componentWillMount'}(){
                // method body
              }
              
              @override
              componentWillReceiveProps() {}
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
          class FooComponent extends FluxUiComponent {
            @override
            componentDidMount() {
              super.componentDidMount();
              var c = 3;
              var d = 4;
            }
            
            @override
            componentWillMount() {
              super.componentWillMount();
              var a = 1;
              var b = 2;
            }
          }
      ''',
    );
  });
}

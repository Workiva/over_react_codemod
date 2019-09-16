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
            class FooComponent extends SomeOtherClass {
              componentWillMount(){
                // method body
              }
            }
          ''',
          expectedOutput: '''
            @Component2()
            class FooComponent extends SomeOtherClass {
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
    group('are removed if containing class is fully upgradable', () {
      test('and extends UiComponent2', () {
        testSuggestor(
          expectedPatchCount: 2,
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
              void init(){
                // method body
              }
            }
          ''',
        );
      });

      test('and extends UiStatefulComponent2', () {
        testSuggestor(
          expectedPatchCount: 2,
          input: '''
            @Component2()
            class FooComponent extends UiStatefulComponent2 {
              void componentWillMount(){
                super.componentWillMount();
                // method body
              }
            }
          ''',
          expectedOutput: '''
            @Component2()
            class FooComponent extends UiStatefulComponent2 {
              void init(){
                // method body
              }
            }
          ''',
        );
      });

      test('and extends react.Component2', () {
        testSuggestor(
          expectedPatchCount: 2,
          input: '''
            import 'package:react/react.dart' as react;
            
            @Component2()
            class FooComponent extends react.Component2 {
              void componentWillMount(){
                super.componentWillMount();
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
    });

    test(
        'does not remove super calls to componentWillMount for non-base extending classes',
        () {
      testSuggestor(
        expectedPatchCount: allowPartialUpgrades ? 1 : 0,
        input: '''
          @Component2()
          class FooComponent extends SomeOtherClass {
            void componentWillMount(){
              super.componentWillMount();
              // method body
            }
          }
        ''',
        expectedOutput: '''
          @Component2()
          class FooComponent extends SomeOtherClass {
            void ${allowPartialUpgrades ? 'init' : 'componentWillMount'}(){
              super.componentWillMount();
              // method body
            }
          }
        ''',
      );
    });

    test(
        'are ${allowPartialUpgrades ? '' : 'not '}removed if containing class'
        ' has lifecycle methods without codemods', () {
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

  group('ComponentWillMountMigrator', () {
    final testSuggestor = getSuggestorTester(ComponentWillMountMigrator());

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
      test('componentWillMount method updates', () {
        testSuggestor(
          expectedPatchCount: 2,
          input: '''
            @Component2()
            class FooComponent extends UiComponent2 {
              @override
              componentWillMount(){
                // method body
              }
            }
          ''',
          expectedOutput: '''
            @Component2()
            class FooComponent extends UiComponent2 {
              $componentWillMountMessage
              @override
              componentDidMount(){
                // method body
              }
            }
          ''',
        );
      });

      test('componentWillMount method with return type updates', () {
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

      test('update super calls to componentDidMount', () {
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
    });

    group('when componentDidMount exists in containing class', () {
      test('componentWillMount method updates', () {
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
                var c = 3;
                var d = 4;
                var a = 1;
                var b = 2;
              }
            }
          ''',
        );
      });

      test('componentWillMount method with return type updates', () {
        testSuggestor(
          expectedPatchCount: 2,
          input: '''
            import 'package:react/react.dart' as react;
            
            @Component2()
            class FooComponent extends react.Component2 {
              void componentWillMount() {
                var a = 1;
                var b = 2;
              }
              
              void componentDidMount() {
                var c = 3;
                var d = 4;
              }
            }
          ''',
          expectedOutput: '''
            import 'package:react/react.dart' as react;
            
            @Component2()
            class FooComponent extends react.Component2 {
              void componentDidMount() {
                var c = 3;
                var d = 4;
                var a = 1;
                var b = 2;
              }
            }
          ''',
        );
      });

      test('update super call to componentWillMount if not already existing',
              () {
            testSuggestor(
              expectedPatchCount: 2,
              input: '''
            @Component2()
            class FooComponent extends FluxUiComponent2 {
              @override
              componentDidMount() {
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
              componentDidMount() {
                var c = 3;
                var d = 4;
                super.componentDidMount();
                var a = 1;
                var b = 2;
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
                super.componentDidMount();
                var c = 3;
                var d = 4;
                var a = 1;
                var b = 2;
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
                var c = 3;
                var a = 1;
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
                var c = 3;
                var a = 1;
              }
            }
          ''',
        );
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
    });
  });
}

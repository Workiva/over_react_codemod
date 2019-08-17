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

import 'package:over_react_codemod/src/component2_suggestors/class_name_and_annotation_migrator.dart';
import 'package:test/test.dart';

import '../util.dart';

main() {
  group('ClassNameAndAnnotationMigrator with --no-partial-upgrades flag', () {
    final testSuggestor = getSuggestorTester(
        ClassNameAndAnnotationMigrator(noPartialUpgrades: true));

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

    test('annotation with non-based extending class does not update', () {
      testSuggestor(
        expectedPatchCount: 0,
        input: '''
          @Component()
          class FooComponent extends AbstractComponent {}
        ''',
      );
    });

    group('annotation and extending class', () {
      test('updates when all lifecycle methods have codemods', () {
        testSuggestor(
          expectedPatchCount: 2,
          input: '''
            @Component()
            class FooComponent extends UiComponent<FooProps> {
              eventHandler() {
                // method body
              }

              @override
              componentWillMount() {
                // method body
              }

              @override
              render() {
                // method body
              }

              @override
              componentDidUpdate(Map prevProps, Map prevState) {
                // method body
              }
            }
          ''',
          expectedOutput: '''
            @Component2()
            class FooComponent extends UiComponent2<FooProps> {
              eventHandler() {
                // method body
              }

              @override
              componentWillMount() {
                // method body
              }

              @override
              render() {
                // method body
              }

              @override
              componentDidUpdate(Map prevProps, Map prevState) {
                // method body
              }
            }
          ''',
        );
      });

      test('updates with no lifecycle methods', () {
        testSuggestor(
          expectedPatchCount: 2,
          input: '''
            @Component()
            class FooComponent extends UiComponent<FooProps> {}
          ''',
          expectedOutput: '''
            @Component2()
            class FooComponent extends UiComponent2<FooProps> {}
          ''',
        );
      });

      test('does not update when one or more lifecycle method has no codemod',
          () {
        testSuggestor(
          expectedPatchCount: 0,
          input: '''
            @Component()
            class FooComponent extends UiComponent<FooProps> {
              eventHandler() {
                // method body
              }

              @override
              componentWillMount() {
                // method body
              }

              @override
              render() {
                // method body
              }

              @override
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

    group('extending class only needs updating', () {
      test('updates when all lifecycle methods have codemods', () {
        testSuggestor(
          expectedPatchCount: 1,
          input: '''
            @Component2()
            class FooComponent extends UiStatefulComponent<FooProps, FooState> {
              @override
              void render() {
                // method body
              }
            }
          ''',
          expectedOutput: '''
            @Component2()
            class FooComponent extends UiStatefulComponent2<FooProps, FooState> {
              @override
              void render() {
                // method body
              }
            }
          ''',
        );
      });

      test('does not update when one or more lifecycle method has no codemod',
          () {
        testSuggestor(
          expectedPatchCount: 0,
          input: '''
            @Component2()
            class FooComponent extends UiStatefulComponent<FooProps, FooState> {
              @override
              shouldComponentUpdate() {
                // method body
              }
            
              @override
              void render() {
                // method body
              }
            }
          ''',
        );
      });
    });

    group('annotation with args and extending class', () {
      test('updates when all lifecycle methods have codemods', () {
        testSuggestor(
          expectedPatchCount: 2,
          input: '''
            @Component(isWrapper: true)
            class FooComponent extends UiComponent<FooProps> {
              eventHandler() {
                // method body
              }

              @override
              render() {
                // method body
              }
            }
          ''',
          expectedOutput: '''
            @Component2(isWrapper: true)
            class FooComponent extends UiComponent2<FooProps> {
              eventHandler() {
                // method body
              }

              @override
              render() {
                // method body
              }
            }
          ''',
        );
      });

      test('does not update when one or more lifecycle method has no codemod',
          () {
        testSuggestor(
          expectedPatchCount: 0,
          input: '''
            @Component(isWrapper: true)
            class FooComponent extends UiComponent<FooProps> {
              @override
              componentWillMount() {
                // method body
              }

              @override
              componentDidMount() {
                // method body
              }
            }
          ''',
        );
      });

      test('is non-Component does not update', () {
        testSuggestor(
          expectedPatchCount: 0,
          input: '''
            @Component(isWrapper: true)
            class FooComponent extends AbstractComponent<FooProps> {
              @override
              render() {
                // method body
              }
            }
          ''',
        );
      });
    });

    group('AbstractComponent annotation and extending stateful class', () {
      test('updates when all lifecycle methods have codemods', () {
        testSuggestor(
          expectedPatchCount: 2,
          input: '''
            @AbstractComponent(isWrapper: true)
            abstract class FooComponent extends UiStatefulComponent<FooProps, FooState> {
              @override
              componentWillMount() {
                // method body
              }
            }
          ''',
          expectedOutput: '''
            @AbstractComponent2(isWrapper: true)
            abstract class FooComponent extends UiStatefulComponent2<FooProps, FooState> {
              @override
              componentWillMount() {
                // method body
              }
            }
          ''',
        );
      });

      test('does not update when one or more lifecycle method has no codemod',
          () {
        testSuggestor(
          expectedPatchCount: 0,
          input: '''
            @AbstractComponent(isWrapper: true)
            abstract class FooComponent extends UiStatefulComponent<FooProps, FooState> {
              @override
              componentWillMount() {
                // method body
              }

              @override
              shouldComponentUpdate() {
                // method body
              }
            }
          ''',
        );
      });

      test('is non-Component does not update', () {
        testSuggestor(
          expectedPatchCount: 0,
          input: '''
            @AbstractComponent(isWrapper: true)
            abstract class FooComponent extends AbstractStatefulComponent<FooProps, FooState> {}
          ''',
        );
      });
    });

    group('extending class imported from react.dart', () {
      test('updates when all lifecycle methods have codemods', () {
        testSuggestor(
          expectedPatchCount: 2,
          input: '''
            import 'package:react/react.dart' as react show Component;
            import 'package:react/react_dom.dart' as react_dom;
          
            class FooComponent extends react.Component {
              @override
              void componentDidUpdate(Map prevProps, Map prevState) {
                // method body
              }
            }
          ''',
          expectedOutput: '''
            import 'package:react/react.dart' as react show Component, Component2;
            import 'package:react/react_dom.dart' as react_dom;
  
            class FooComponent extends react.Component2 {
              @override
              void componentDidUpdate(Map prevProps, Map prevState) {
                // method body
              }
            }
          ''',
        );
      });

      test('does not update when one or more lifecycle method has no codemod',
          () {
        testSuggestor(
          expectedPatchCount: 0,
          input: '''
            import 'package:react/react.dart' as react show Component;
            import 'package:react/react_dom.dart' as react_dom;
          
            class FooComponent extends react.Component {
              @override
              componentDidUpdate(Map prevProps, Map prevState) {
                // method body
              }
              
              @override
              componentWillReceiveProps() {
                // method body
              }
            }
          ''',
        );
      });

      test(
          'with different import name updates when all lifecycle methods have codemods',
          () {
        testSuggestor(
          expectedPatchCount: 1,
          input: '''
            import "package:react/react_dom.dart" as react_dom;
            import "package:react/react.dart" as foo;
          
            class FooComponent extends foo.Component {}
          ''',
          expectedOutput: '''
            import "package:react/react_dom.dart" as react_dom;
            import "package:react/react.dart" as foo;
  
            class FooComponent extends foo.Component2 {}
          ''',
        );
      });
    });

    group('react.dart import show Component', () {
      test('updates if one or more component in the file updates', () {
        testSuggestor(
          expectedPatchCount: 3,
          input: '''
            import "package:react/react_dom.dart" as react_dom;
            import "package:react/react.dart" as react show Component;
          
            class FooComponent extends react.Component {
              @override
              componentWillReceiveProps() {
                // method body
              }
            }
            
            class FooComponent extends react.Component {
              @override
              componentDidUpdate(Map prevProps, Map prevState) {
                // method body
              }
            }
            
            class FooComponent extends react.Component {}
            
            class FooComponent extends react.Component {
              @override
              shouldComponentUpdate() {
                // method body
              }
              
              @override
              render() {
                // method body
              }
            }
          ''',
          expectedOutput: '''
            import "package:react/react_dom.dart" as react_dom;
            import "package:react/react.dart" as react show Component, Component2;
          
            class FooComponent extends react.Component {
              @override
              componentWillReceiveProps() {
                // method body
              }
            }
            
            class FooComponent extends react.Component2 {
              @override
              componentDidUpdate(Map prevProps, Map prevState) {
                // method body
              }
            }
            
            class FooComponent extends react.Component2 {}
            
            class FooComponent extends react.Component {
              @override
              shouldComponentUpdate() {
                // method body
              }
              
              @override
              render() {
                // method body
              }
            }
          ''',
        );
      });

      test('does not update if all components in the file do not update', () {
        testSuggestor(
          expectedPatchCount: 0,
          input: '''
            import "package:react/react_dom.dart" as react_dom;
            import "package:react/react.dart" as react show Component;
          
            class FooComponent extends react.Component {
              @override
              componentWillReceiveProps() {
                // method body
              }
            }
            
            class FooComponent extends react.Component {
              @override
              shouldComponentUpdate() {
                // method body
              }
              
              @override
              render() {
                // method body
              }
            }
          ''',
        );
      });
    });

    test('already updated annotation and extending class does not update', () {
      testSuggestor(
        expectedPatchCount: 0,
        input: '''
          @Component2
          class FooComponent extends UiComponent2 {
            eventHandler() {
              // method body
            }
            
            @override
            init() {
              // method body
            }
            
            @override
            render() {
              // method body
            }
            
            @override
            componentDidUpdate(Map prevProps, Map prevState, [snapshot]) {
              // method body
            }
          }
        ''',
      );
    });
  });
}

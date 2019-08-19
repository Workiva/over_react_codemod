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
  group('ClassNameAndAnnotationMigrator', () {
    final testSuggestor = getSuggestorTester(ClassNameAndAnnotationMigrator());

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

    test('annotation with non-based extending class updates', () {
      testSuggestor(
        expectedPatchCount: 1,
        input: '''
          @Component()
          class FooComponent extends AbstractComponent {}
        ''',
        expectedOutput: '''
          @Component2()
          class FooComponent extends AbstractComponent {}
        ''',
      );
    });

    test('annotation and extending class updates', () {
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
            
            @override
            componentWillUnmount() {
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
            
            @override
            componentWillUnmount() {
              // method body
            }
          }
        ''',
      );
    });

    test('extending class only needs updating', () {
      testSuggestor(
        expectedPatchCount: 1,
        input: '''
          @Component2()
          class FooComponent extends UiStatefulComponent<FooProps, FooState> {
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
          @Component2()
          class FooComponent extends UiStatefulComponent2<FooProps, FooState> {
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

    test('annotation with args and extending class updates', () {
      testSuggestor(
        expectedPatchCount: 2,
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
        expectedOutput: '''
          @Component2(isWrapper: true)
          class FooComponent extends UiComponent2<FooProps> {
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

    test('AbstractComponent annotation and extending stateful class updates',
        () {
      testSuggestor(
        expectedPatchCount: 2,
        input: '''
          @AbstractComponent(isWrapper: true)
          abstract class AbstractFooComponent extends UiStatefulComponent {
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
        expectedOutput: '''
          @AbstractComponent2(isWrapper: true)
          abstract class AbstractFooComponent extends UiStatefulComponent2 {
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

    test('extending class imported from react.dart updates', () {
      testSuggestor(
        expectedPatchCount: 2,
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
        expectedOutput: '''
          import 'package:react/react.dart' as react show Component, Component2;
          import 'package:react/react_dom.dart' as react_dom;

          class FooComponent extends react.Component2 {
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
        'extending class imported from react.dart with different import name updates',
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

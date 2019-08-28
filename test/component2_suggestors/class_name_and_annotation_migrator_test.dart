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
    classNameAndAnnotationTests(allowPartialUpgrades: true);
  });

  group('ClassNameAndAnnotationMigrator with --no-partial-upgrades flag', () {
    classNameAndAnnotationTests(allowPartialUpgrades: false);
  });
}

void classNameAndAnnotationTests({bool allowPartialUpgrades}) {
  final testSuggestor = getSuggestorTester(ClassNameAndAnnotationMigrator(
      allowPartialUpgrades: allowPartialUpgrades));

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

  test(
      'annotation with non-based extending class '
      '${allowPartialUpgrades ? 'updates' : 'does not update'}', () {
    testSuggestor(
      expectedPatchCount: allowPartialUpgrades ? 1 : 0,
      input: '''
        @Component()
        class FooComponent extends AbstractComponent {}
      ''',
      expectedOutput: '''
        @Component${allowPartialUpgrades ? '2' : ''}()
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
            eventHandler() {}
            
            @override
            componentWillMount() {}
            
            @override
            render() {}
            
            @override
            componentDidUpdate(Map prevProps, Map prevState) {}
          }
        ''',
        expectedOutput: '''
          @Component2()
          class FooComponent extends UiComponent2<FooProps> {
            eventHandler() {}
            
            @override
            componentWillMount() {}

            @override
            render() {}

            @override
            componentDidUpdate(Map prevProps, Map prevState) {}
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

    test(
        '${allowPartialUpgrades ? 'updates' : 'does not update'} when one or '
        'more lifecycle method has no codemod', () {
      testSuggestor(
        expectedPatchCount: allowPartialUpgrades ? 2 : 0,
        input: '''
          @Component()
          class FooComponent extends UiComponent<FooProps> {
            eventHandler() {}

            @override
            componentWillMount() {}

            @override
            render() {}

            @override
            componentDidUpdate(Map prevProps, Map prevState) {}

            @override
            componentWillUnmount() {}
          }
        ''',
        expectedOutput: '''
          @Component${allowPartialUpgrades ? '2' : ''}()
          class FooComponent extends UiComponent${allowPartialUpgrades ? '2' : ''}<FooProps> {
            eventHandler() {}
  
            @override
            componentWillMount() {}
            
            @override
            render() {}
            
            @override
            componentDidUpdate(Map prevProps, Map prevState) {}
            
            @override
            componentWillUnmount() {}
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
            void render() {}
          }
        ''',
        expectedOutput: '''
          @Component2()
          class FooComponent extends UiStatefulComponent2<FooProps, FooState> {
            @override
            void render() {}
          }
        ''',
      );
    });

    test(
        '${allowPartialUpgrades ? 'updates' : 'does not update'} when one or '
        'more lifecycle method has no codemod', () {
      testSuggestor(
        expectedPatchCount: allowPartialUpgrades ? 1 : 0,
        input: '''
          @Component2()
          class FooComponent extends UiStatefulComponent<FooProps, FooState> {
            @override
            shouldComponentUpdate() {}
            
            @override
            void render() {}
          }
        ''',
        expectedOutput: '''
          @Component2()
          class FooComponent extends UiStatefulComponent${allowPartialUpgrades ? '2' : ''}<FooProps, FooState> {
            @override
            shouldComponentUpdate() {}
            
            @override
            void render() {}
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
            eventHandler() {}

            @override
            render() {}
          }
        ''',
        expectedOutput: '''
          @Component2(isWrapper: true)
          class FooComponent extends UiComponent2<FooProps> {
            eventHandler() {}

            @override
            render() {}
          }
        ''',
      );
    });

    test(
        '${allowPartialUpgrades ? 'updates' : 'does not update'} when one or '
        'more lifecycle method has no codemod', () {
      testSuggestor(
        expectedPatchCount: allowPartialUpgrades ? 2 : 0,
        input: '''
          @Component(isWrapper: true)
          class FooComponent extends UiComponent<FooProps> {
            @override
            componentWillMount() {}
            
            @override
            componentDidMount() {}
          }
        ''',
        expectedOutput: '''
          @Component${allowPartialUpgrades ? '2' : ''}(isWrapper: true)
          class FooComponent extends UiComponent${allowPartialUpgrades ? '2' : ''}<FooProps> {
            @override
            componentWillMount() {}
            
            @override
            componentDidMount() {}
          }
        ''',
      );
    });

    test(
        'is non-Component ${allowPartialUpgrades ? 'updates' : 'does not update'}',
        () {
      testSuggestor(
        expectedPatchCount: allowPartialUpgrades ? 1 : 0,
        input: '''
          @Component(isWrapper: true)
          class FooComponent extends AbstractComponent<FooProps> {
            @override
            render() {}
          }
        ''',
        expectedOutput: '''
          @Component${allowPartialUpgrades ? '2' : ''}(isWrapper: true)
          class FooComponent extends AbstractComponent<FooProps> {
            @override
            render() {}
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
            componentWillMount() {}
          }
        ''',
        expectedOutput: '''
          @AbstractComponent2(isWrapper: true)
          abstract class FooComponent extends UiStatefulComponent2<FooProps, FooState> {
            @override
            componentWillMount() {}
          }
        ''',
      );
    });

    test(
        '${allowPartialUpgrades ? 'updates' : 'does not update'} when one or '
        'more lifecycle method has no codemod', () {
      testSuggestor(
        expectedPatchCount: allowPartialUpgrades ? 2 : 0,
        input: '''
          @AbstractComponent(isWrapper: true)
          abstract class FooComponent extends UiStatefulComponent<FooProps, FooState> {
            @override
            componentWillMount() {}

            @override
            shouldComponentUpdate() {}
          }
        ''',
        expectedOutput: '''
          @AbstractComponent${allowPartialUpgrades ? '2' : ''}(isWrapper: true)
          abstract class FooComponent extends UiStatefulComponent${allowPartialUpgrades ? '2' : ''}<FooProps, FooState> {
            @override
            componentWillMount() {}

            @override
            shouldComponentUpdate() {}
          }
        ''',
      );
    });

    test(
        'is non-Component ${allowPartialUpgrades ? 'updates' : 'does not update'}',
        () {
      testSuggestor(
        expectedPatchCount: allowPartialUpgrades ? 1 : 0,
        input: '''
          @AbstractComponent(isWrapper: true)
          abstract class FooComponent extends AbstractStatefulComponent<FooProps, FooState> {}
        ''',
        expectedOutput: '''
          @AbstractComponent${allowPartialUpgrades ? '2' : ''}(isWrapper: true)
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
            void componentDidUpdate(Map prevProps, Map prevState) {}
          }
        ''',
        expectedOutput: '''
          import 'package:react/react.dart' as react show Component, Component2;
          import 'package:react/react_dom.dart' as react_dom;

          class FooComponent extends react.Component2 {
            @override
            void componentDidUpdate(Map prevProps, Map prevState) {}
          }
        ''',
      );
    });

    test(
        '${allowPartialUpgrades ? 'updates' : 'does not update'} when one or '
        'more lifecycle method has no codemod', () {
      testSuggestor(
        expectedPatchCount: allowPartialUpgrades ? 2 : 0,
        input: '''
          import 'package:react/react.dart' as react show Component;
          import 'package:react/react_dom.dart' as react_dom;
        
          class FooComponent extends react.Component {
            @override
            componentDidUpdate(Map prevProps, Map prevState) {}
            
            @override
            componentWillReceiveProps() {}
          }
        ''',
        expectedOutput: '''
          import 'package:react/react.dart' as react show Component${allowPartialUpgrades ? ', Component2' : ''};
          import 'package:react/react_dom.dart' as react_dom;

          class FooComponent extends react.Component${allowPartialUpgrades ? '2' : ''} {
            @override
            componentDidUpdate(Map prevProps, Map prevState) {}
            
            @override
            componentWillReceiveProps() {}
          }
        ''',
      );
    });

    test('import from react.dart hide combinator does not update', () {
      testSuggestor(
        expectedPatchCount: 2,
        input: '''
          import 'package:react/react.dart' as react hide Component;
          
          @Component
          class FooComponent extends UiComponent {}
        ''',
        expectedOutput: '''
          import 'package:react/react.dart' as react hide Component;
          
          @Component2
          class FooComponent extends UiComponent2 {}
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
        expectedPatchCount: allowPartialUpgrades ? 5 : 3,
        input: '''
          import "package:react/react_dom.dart" as react_dom;
          import "package:react/react.dart" as react show Component;
        
          class FooComponent extends react.Component {
            @override
            componentWillReceiveProps() {}
          }
          
          class FooComponent extends react.Component {
            @override
            componentDidUpdate(Map prevProps, Map prevState) {}
          }
          
          class FooComponent extends react.Component {}
          
          class FooComponent extends react.Component {
            @override
            shouldComponentUpdate() {}
            
            @override
            render() {}
          }
        ''',
        expectedOutput: '''
          import "package:react/react_dom.dart" as react_dom;
          import "package:react/react.dart" as react show Component, Component2;
        
          class FooComponent extends react.Component${allowPartialUpgrades ? '2' : ''} {
            @override
            componentWillReceiveProps() {}
          }
          
          class FooComponent extends react.Component2 {
            @override
            componentDidUpdate(Map prevProps, Map prevState) {}
          }
          
          class FooComponent extends react.Component2 {}
          
          class FooComponent extends react.Component${allowPartialUpgrades ? '2' : ''} {
            @override
            shouldComponentUpdate() {}
            
            @override
            render() {}
          }
        ''',
      );
    });

    if (!allowPartialUpgrades) {
      test('does not update if all components in the file do not update', () {
        testSuggestor(
          expectedPatchCount: 0,
          input: '''
            import "package:react/react_dom.dart" as react_dom;
            import "package:react/react.dart" as react show Component;
          
            class FooComponent extends react.Component {
              @override
              componentWillReceiveProps() {}
            }
            
            class FooComponent extends react.Component {
              @override
              shouldComponentUpdate() {}
              
              @override
              render() {}
            }
          ''',
        );
      });
    }
  });

  test('already updated annotation and extending class does not update', () {
    testSuggestor(
      expectedPatchCount: 0,
      input: '''
        @Component2
        class FooComponent extends UiComponent2 {
          eventHandler() {}
          
          @override
          init() {}
          
          @override
          render() {}
          
          @override
          componentDidUpdate(Map prevProps, Map prevState, [snapshot]) {}
        }
      ''',
    );
  });
}

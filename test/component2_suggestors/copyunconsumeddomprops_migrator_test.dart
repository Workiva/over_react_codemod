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

import 'package:over_react_codemod/src/component2_suggestors/copyunconsumeddomprops_migrator.dart';
import 'package:test/test.dart';

import '../util.dart';

main() {
  group('CopyUnconsumedDomPropsMigrator', () {
    final testSuggestor = getSuggestorTester(CopyUnconsumedDomPropsMigrator());

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

    test('copyUnconsumedDomProps updates', () {
      testSuggestor(
        expectedPatchCount: 2,
        input: '''
          @Component2()
          class FooComponent extends UiComponent2<FooProps> {
            @override
            render() {
              return (Dom.span()
                ..addProps(copyUnconsumedDomProps())
              )(props.children);
            }
          }
        ''',
        expectedOutput: '''
          @Component2()
          class FooComponent extends UiComponent2<FooProps> {
            @override
            render() {
              return (Dom.span()
                ..modifyProps(addUnconsumedDomProps)
              )(props.children);
            }
          }
        ''',
      );
    });

    test('copyUnconsumedProps updates', () {
      testSuggestor(
        expectedPatchCount: 2,
        input: '''
          import 'package:react/react.dart' as react;
          
          class FooComponent extends react.Component2 {
            @override
            render() {
              return (Dom.span()
                ..addProps(copyUnconsumedProps())
              )(props.children);
            }
          }
        ''',
        expectedOutput: '''
          import 'package:react/react.dart' as react;
        
          class FooComponent extends react.Component2 {
            @override
            render() {
              return (Dom.span()
                ..modifyProps(addUnconsumedProps)
              )(props.children);
            }
          }
        ''',
      );
    });

    test('does not change copyUnconsumedProps for non-component2 classes', () {
      testSuggestor(
        expectedPatchCount: 0,
        input: '''
          @Component()
          class FooComponent extends FluxUiComponent {
            @override
            render() {
              return (Dom.span()
                ..addProps(copyUnconsumedDomProps())
              )(props.children);
            }
          }
        ''',
      );
    });
  });
}

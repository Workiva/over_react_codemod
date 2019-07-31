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

import 'package:over_react_codemod/src/react16_suggestors/constants.dart';
import 'package:over_react_codemod/src/react16_suggestors/react_dom_render_migrator.dart';
import 'package:test/test.dart';

import '../util.dart';

main() {
  group('ReactDomRenderMigrator', () {
    final testSuggestor = getSuggestorTester(ReactDomRenderMigrator());

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

    test('render without usage of return value', () {
      testSuggestor(
        expectedPatchCount: 2,
        input: '''
          main() {
            react_dom.render(Foo()(), mountNode);
          }
        ''',
        expectedOutput: '''
          main() {
            react_dom.render(ErrorBoundary()(Foo()()), mountNode);
          }
        ''',
      );
    });

    test('simple usage', () {
      testSuggestor(
        expectedPatchCount: 7,
        input: '''
          main() {
            var instance = react_dom.render(Foo()(), mountNode);
          }
        ''',
        expectedOutput: '''
          main() {
            var instance;
            $checkboxCommentWithType
            react_dom.render(ErrorBoundary()((Foo()
              ..ref = (ref) { instance = ref; }
            )()), mountNode);
          }
        ''',
      );
    });

    test('simple usage assignment to existing variable', () {
      testSuggestor(
        expectedPatchCount: 7,
        input: '''
          main() {
            var instance;
            instance = react_dom.render(Foo()(), mountNode);
          }
        ''',
        expectedOutput: '''
          main() {
            var instance;
            $checkboxComment
            react_dom.render(ErrorBoundary()((Foo()
              ..ref = (ref) { instance = ref; }
            )()), mountNode);
          }
        ''',
      );
    });

    test('simple usage as an argument', () {
      testSuggestor(
        expectedPatchCount: 3,
        input: '''
          main() {
            var instance = getDartComponent(react_dom.render(Foo()(), mountNode));
          }
        ''',
        expectedOutput: '''
          main() {
            var instance = getDartComponent( \n${getCheckboxManualUpdate(toUpdate: 'argument')}
            react_dom.render(ErrorBoundary()(Foo()()), mountNode));
          }
        ''',
      );
    });

    test('simple usage as a return value', () {
      testSuggestor(
        expectedPatchCount: 3,
        input: '''
          main() {
            return react_dom.render(Foo()(), mountNode);
          }
        ''',
        expectedOutput: '''
          main() {
            return ${getCheckboxManualUpdate(toUpdate: 'return')}
            react_dom.render(ErrorBoundary()(Foo()()), mountNode);
          }
        ''',
      );
    });

    test('simple usage with existing other props', () {
      testSuggestor(
        expectedPatchCount: 5,
        input: '''
          main() {
            var instance = react_dom.render((Foo()
              ..id = 'foo'
            )(), mountNode);
          }
        ''',
        expectedOutput: '''
          main() {
            var instance;
            $checkboxCommentWithType
            react_dom.render(ErrorBoundary()((Foo()
              ..ref = (ref) { instance = ref; }
              ..id = 'foo'
            )()), mountNode);
          }
        ''',
      );
    });

    test('simple usage with existing ref', () {
      testSuggestor(
        expectedPatchCount: 3,
        input: '''
          main() {
            var fooRef;
            react_dom.render((Foo()
              ..ref = (ref) { fooRef = ref; }
            )(), mountNode);
          }
        ''',
        expectedOutput: '''
          main() {
            var fooRef;
            $checkboxComment
            react_dom.render(ErrorBoundary()((Foo()
              ..ref = (ref) { fooRef = ref; }
            )()), mountNode);
          }
        ''',
      );
    });

    test('simple usage with existing ref in a void arrow function', () {
      testSuggestor(
        expectedPatchCount: 3,
        input: '''
          main() {
            void render() => react_dom.render((Foo()..ref = ((ref) => fooRef = ref))(), mountNode);
          }
        ''',
        expectedOutput: '''
          main() {
            void render() => $checkboxComment
            react_dom.render(ErrorBoundary()((Foo()..ref = ((ref) => fooRef = ref))()), mountNode);
          }
        ''',
      );
    });

    test('simple usage with existing ref in an arrow function', () {
      testSuggestor(
        expectedPatchCount: 3,
        input: '''
          main() {
            render() => react_dom.render((Foo()..ref = ((ref) => fooRef = ref))(), mountNode);
          }
        ''',
        expectedOutput: '''
          main() {
            render() => ${getCheckboxManualUpdate(toUpdate: 'return')} 
            react_dom.render(ErrorBoundary()((Foo()..ref = ((ref) => fooRef = ref))()), mountNode);
          }
        ''',
      );
    });

    test('existing ref and assignment', () {
      testSuggestor(
        expectedPatchCount: 4,
        input: '''
          main() {
            var fooRef = react_dom.render((Foo()
              ..ref = (ref) { somethingElse = ref; }
            )(), mountNode);
          }
        ''',
        expectedOutput: '''
          main() {
            var fooRef;
            $checkboxCommentWithType
            react_dom.render(ErrorBoundary()((Foo()
              ..ref = (ref) { somethingElse = ref; }
            )()), mountNode);
          }
        ''',
      );
    });

    test('simple usage with non-component usage', () {
      testSuggestor(
        expectedPatchCount: 16,
        input: '''
          main() {
            var instance1 = react_dom.render(foo(), mountNode);

            var instance2 = react_dom.render(foo, mountNode);

            instance3 = react_dom.render(foo(), mountNode);

            instance4 = react_dom.render(foo, mountNode);
          }
        ''',
        expectedOutput: '''
          main() {
            var instance1;
            $checkboxCommentExpressionRef
            react_dom.render(ErrorBoundary()(foo()), mountNode);

            var instance2;
            $checkboxCommentExpressionRef
            react_dom.render(ErrorBoundary()(foo), mountNode);

            $checkboxCommentExpressionRef
            react_dom.render(ErrorBoundary()(foo()), mountNode);

            $checkboxCommentExpressionRef
            react_dom.render(ErrorBoundary()(foo), mountNode);
          }
        ''',
      );
    });

    test('simple usage with validated ref', () {
      testSuggestor(
        expectedPatchCount: 0,
        input: '''
          main() {
            var fooRef;
            ${getCheckboxComment(checked: true)}
            react_dom.render(ErrorBoundary()((Foo()
              ..ref = (ref) { fooRef = ref; }
            )()), mountNode);
          }
        ''',
      );
    });

    test('simple usage with unvalidated ref', () {
      testSuggestor(
        expectedPatchCount: 0,
        input: '''
          main() {
            var fooRef;
            ${getCheckboxComment(checked: false)}
            react_dom.render(ErrorBoundary()((Foo()
              ..ref = (ref) { fooRef = ref; }
            )()), mountNode);
          }
        ''',
      );
    });

    test('simple usage in a test', () {
      testSuggestor(
        expectedPatchCount: 0,
        input: '''
          main() {
            test('simple test', () {
              var instance = react_dom.render(Foo()(), mountNode);
            });
          }
        ''',
      );
    });
  });
}

String getCheckboxComment({
  bool includeTypeMessage = false,
  bool checked = false,
}) =>
    '// ${checked ? '[x]' : '[ ]'}'
    ' Check this box upon manual validation of this ref'
    '${includeTypeMessage ? ' and its typing' : ''}.'
    '$willBeRemovedCommentSuffix';

String getCheckboxManualUpdate({
  String toUpdate = 'argument',
}) =>
    '// [ ] Check this box upon manually updating this $toUpdate '
    'to use a callback ref instead of the return value of `react_dom.render`.'
    '$willBeRemovedCommentSuffix';

final checkboxComment = getCheckboxComment();
final checkboxCommentWithType = getCheckboxComment(includeTypeMessage: true);
final checkboxCommentExpressionRef =
    '// [ ] Check this box upon manual validation that '
    'the component rendered by this expression uses a ref safely.'
    '$willBeRemovedCommentSuffix';

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
    final Future<void> Function({String expectedOutput, int expectedPatchCount, String input, bool shouldDartfmtOutput, bool testIdempotency, void Function(String) validateContents}) testSuggestor = getSuggestorTester(ReactDomRenderMigrator() as Stream<Patch> Function(FileContext));

    test('empty file', () async {
      await testSuggestor(expectedPatchCount: 0, input: '');
    });

    test('no matches', () async {
      await testSuggestor(
        expectedPatchCount: 0,
        input: '''
          library foo;
          var a = 'b';
          class Foo {}
        ''',
      );
    });

    test('render without usage of return value', () async {
      await testSuggestor(
        expectedPatchCount: 3,
        input: '''
          import 'package:react/react_dom.dart' as react_dom;

          main() {
            react_dom.render(Foo()(), mountNode);
          }
        ''',
        expectedOutput: '''
          import 'package:over_react/over_react.dart';
          import 'package:react/react_dom.dart' as react_dom;

          main() {
            react_dom.render(ErrorBoundary()(Foo()()), mountNode);
          }
        ''',
      );
    });

    test('simple usage', () async {
      await testSuggestor(
        expectedPatchCount: 7,
        input: '''
          import 'package:over_react/over_react.dart';
          import 'package:react/react_dom.dart' as react_dom;

          main() {
            var instance = react_dom.render(Foo()(), mountNode);
          }
        ''',
        expectedOutput: '''
          import 'package:over_react/over_react.dart';
          import 'package:react/react_dom.dart' as react_dom;

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

    test('simple usage already wrapped with ErrorBoundary that has props',
        () async {
      await testSuggestor(
        expectedPatchCount: 0,
        input: '''
          import 'package:over_react/over_react.dart';
          import 'package:react/react_dom.dart' as react_dom;

          main() {
            react_dom.render((ErrorBoundary()..prop = true)(Foo()()), mountNode);
            react_dom.render((ErrorBoundary()..prop = true)(foo), mountNode);
          }
        ''',
      );
    });

    test('simple usage assignment to existing variable', () async {
      await testSuggestor(
        expectedPatchCount: 7,
        input: '''
          import 'package:over_react/over_react.dart';
          import 'package:react/react_dom.dart' as react_dom;

          main() {
            var instance;
            instance = react_dom.render(Foo()(), mountNode);
          }
        ''',
        expectedOutput: '''
          import 'package:over_react/over_react.dart';
          import 'package:react/react_dom.dart' as react_dom;

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

    test('simple usage as an argument', () async {
      await testSuggestor(
        expectedPatchCount: 3,
        input: '''
          import 'package:over_react/over_react.dart';
          import 'package:react/react_dom.dart' as react_dom;

          main() {
            var instance = getDartComponent(react_dom.render(Foo()(), mountNode));
          }
        ''',
        expectedOutput: '''
          import 'package:over_react/over_react.dart';
          import 'package:react/react_dom.dart' as react_dom;

          main() {
            var instance = getDartComponent( \n$getArgumentCheckboxManualUpdate
            react_dom.render(ErrorBoundary()(Foo()()), mountNode));
          }
        ''',
      );
    });

    test('simple usage as a return value', () async {
      await testSuggestor(
        expectedPatchCount: 3,
        input: '''
          import 'package:over_react/over_react.dart';
          import 'package:react/react_dom.dart' as react_dom;

          main() {
            return react_dom.render(Foo()(), mountNode);
          }
        ''',
        expectedOutput: '''
          import 'package:over_react/over_react.dart';
          import 'package:react/react_dom.dart' as react_dom;

          main() {
            return $getVariableCheckboxManualUpdate
            react_dom.render(ErrorBoundary()(Foo()()), mountNode);
          }
        ''',
      );
    });

    test('simple usage with existing other props', () async {
      await testSuggestor(
        expectedPatchCount: 5,
        input: '''
          import 'package:over_react/over_react.dart';
          import 'package:react/react_dom.dart' as react_dom;

          main() {
            var instance = react_dom.render((Foo()
              ..id = 'foo'
            )(), mountNode);
          }
        ''',
        expectedOutput: '''
          import 'package:over_react/over_react.dart';
          import 'package:react/react_dom.dart' as react_dom;

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

    test('simple usage with existing ref', () async {
      await testSuggestor(
        expectedPatchCount: 3,
        input: '''
          import 'package:over_react/over_react.dart';
          import 'package:react/react_dom.dart' as react_dom;

          main() {
            var fooRef;
            react_dom.render((Foo()
              ..ref = (ref) { fooRef = ref; }
            )(), mountNode);
          }
        ''',
        expectedOutput: '''
          import 'package:over_react/over_react.dart';
          import 'package:react/react_dom.dart' as react_dom;

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

    test('simple usage with existing ref in a void arrow function', () async {
      await testSuggestor(
        expectedPatchCount: 3,
        input: '''
          import 'package:over_react/over_react.dart';
          import 'package:react/react_dom.dart' as react_dom;

          main() {
            void render() => react_dom.render((Foo()..ref = ((ref) => fooRef = ref))(), mountNode);
          }
        ''',
        expectedOutput: '''
          import 'package:over_react/over_react.dart';
          import 'package:react/react_dom.dart' as react_dom;

          main() {
            void render() => $checkboxComment
            react_dom.render(ErrorBoundary()((Foo()..ref = ((ref) => fooRef = ref))()), mountNode);
          }
        ''',
      );
    });

    test('simple usage with existing ref in an arrow function', () async {
      await testSuggestor(
        expectedPatchCount: 3,
        input: '''
          import 'package:over_react/over_react.dart';
          import 'package:react/react_dom.dart' as react_dom;

          main() {
            render() => react_dom.render((Foo()..ref = ((ref) => fooRef = ref))(), mountNode);
          }
        ''',
        expectedOutput: '''
          import 'package:over_react/over_react.dart';
          import 'package:react/react_dom.dart' as react_dom;

          main() {
            render() => $getVariableCheckboxManualUpdate
            react_dom.render(ErrorBoundary()((Foo()..ref = ((ref) => fooRef = ref))()), mountNode);
          }
        ''',
      );
    });

    test('existing ref and assignment', () async {
      await testSuggestor(
        expectedPatchCount: 4,
        input: '''
          import 'package:over_react/over_react.dart';
          import 'package:react/react_dom.dart' as react_dom;

          main() {
            var fooRef = react_dom.render((Foo()
              ..ref = (ref) { somethingElse = ref; }
            )(), mountNode);
          }
        ''',
        expectedOutput: '''
          import 'package:over_react/over_react.dart';
          import 'package:react/react_dom.dart' as react_dom;

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

    test('simple usage with non-component usage', () async {
      await testSuggestor(
        expectedPatchCount: 16,
        input: '''
          import 'package:over_react/over_react.dart';
          import 'package:react/react_dom.dart' as react_dom;

          main() {
            var instance1 = react_dom.render(foo(), mountNode);

            var instance2 = react_dom.render(foo, mountNode);

            instance3 = react_dom.render(foo(), mountNode);

            instance4 = react_dom.render(foo, mountNode);
          }
        ''',
        expectedOutput: '''
          import 'package:over_react/over_react.dart';
          import 'package:react/react_dom.dart' as react_dom;

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

    test('simple usage with validated ref', () async {
      await testSuggestor(
        expectedPatchCount: 0,
        input: '''
          import 'package:over_react/over_react.dart';
          import 'package:react/react_dom.dart' as react_dom;

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

    test('simple usage with unvalidated ref', () async {
      await testSuggestor(
        expectedPatchCount: 0,
        input: '''
          import 'package:over_react/over_react.dart';
          import 'package:react/react_dom.dart' as react_dom;

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

    test('simple usage in a test', () async {
      await testSuggestor(
        expectedPatchCount: 0,
        input: '''
          import 'package:over_react/over_react.dart';
          import 'package:react/react_dom.dart' as react_dom;

          main() {
            test('simple test', () {
              var instance = react_dom.render(Foo()(), mountNode);
            });
          }
        ''',
      );
    });

    test('import with double quotes', () async {
      await testSuggestor(
        expectedPatchCount: 2,
        input: '''
          import 'package:over_react/over_react.dart';
          import "package:react/react_dom.dart" as react_dom;

          main() {
            react_dom.render(Foo()(), mountNode);
          }
        ''',
        expectedOutput: '''
          import 'package:over_react/over_react.dart';
          import "package:react/react_dom.dart" as react_dom;

          main() {
            react_dom.render(ErrorBoundary()(Foo()()), mountNode);
          }
        ''',
      );
    });

    test('imported from `over_react` with namespace', () async {
      await testSuggestor(
        expectedPatchCount: 2,
        input: '''
          import 'package:over_react/over_react.dart';
          import 'package:over_react/react_dom.dart' as different_namespace;

          main() {
            different_namespace.render(Foo()(), mountNode);
          }
        ''',
        expectedOutput: '''
          import 'package:over_react/over_react.dart';
          import 'package:over_react/react_dom.dart' as different_namespace;

          main() {
            different_namespace.render(ErrorBoundary()(Foo()()), mountNode);
          }
        ''',
      );
    });

    test('imported from `over_react` without namespace', () async {
      await testSuggestor(
        expectedPatchCount: 2,
        input: '''
          import 'package:over_react/over_react.dart';
          import 'package:over_react/react_dom.dart';

          main() {
            render(Foo()(), mountNode);
          }
        ''',
        expectedOutput: '''
          import 'package:over_react/over_react.dart';
          import 'package:over_react/react_dom.dart';

          main() {
            render(ErrorBoundary()(Foo()()), mountNode);
          }
        ''',
      );
    });

    test('different import namespace', () async {
      await testSuggestor(
        expectedPatchCount: 2,
        input: '''
          import 'package:over_react/over_react.dart';
          import 'package:react/react_dom.dart' as different_namespace;

          main() {
            different_namespace.render(Foo()(), mountNode);
          }
        ''',
        expectedOutput: '''
          import 'package:over_react/over_react.dart';
          import 'package:react/react_dom.dart' as different_namespace;

          main() {
            different_namespace.render(ErrorBoundary()(Foo()()), mountNode);
          }
        ''',
      );
    });

    test('no import namespace', () async {
      await testSuggestor(
        expectedPatchCount: 2,
        input: '''
          import 'package:over_react/over_react.dart';
          import 'package:react/react_dom.dart';

          main() {
            render(Foo()(), mountNode);
          }
        ''',
        expectedOutput: '''
          import 'package:over_react/over_react.dart';
          import 'package:react/react_dom.dart';

          main() {
            render(ErrorBoundary()(Foo()()), mountNode);
          }
        ''',
      );
    });

    test('no react_dom.dart import', () async {
      await testSuggestor(
        expectedPatchCount: 0,
        input: '''
          main() {
            render(Foo()(), mountNode);
          }
        ''',
      );
    });

    test('no react_dom.dart import but usage has namespace in a `part of` file',
        () async {
      await testSuggestor(expectedPatchCount: 2, input: '''
          part of 'a_file.dart';

          main() {
            react_dom.render(Foo()(), mountNode);
          }
        ''', expectedOutput: '''
          part of 'a_file.dart';

          main() {
            react_dom.render(ErrorBoundary()(Foo()()), mountNode);
          }
        ''');
    });

    test('no react_dom.dart import but usage has namespace', () async {
      await testSuggestor(expectedPatchCount: 3, input: '''
          main() {
            react_dom.render(Foo()(), mountNode);
          }
        ''', expectedOutput: '''
          import 'package:over_react/over_react.dart';

          main() {
            react_dom.render(ErrorBoundary()(Foo()()), mountNode);
          }
        ''');
    });

    test('no import of over_react but is wrapped with ErrorBoundary', () async {
      await testSuggestor(
        expectedPatchCount: 1,
        input: '''
          import 'package:react/react_dom.dart';

          main() {
            render(ErrorBoundary()(Foo()()), mountNode);
          }
        ''',
        expectedOutput: '''
          import 'package:over_react/over_react.dart';
          import 'package:react/react_dom.dart';

          main() {
            render(ErrorBoundary()(Foo()()), mountNode);
          }
        ''',
      );
    });

    // These tests strings are split by web_skin_dart to work around issues with dependency_validator.
    test('doesnt add over_react if it imports web_skin_dart/ui_core instead',
        () async {
      await testSuggestor(
        expectedPatchCount: 0,
        input: '''
          import 'package:'''
            '''web_skin_dart/ui_core.dart';
          import 'package:react/react_dom.dart';

          main() {
            render(ErrorBoundary()(Foo()()), mountNode);
          }
        ''',
        expectedOutput: '''
          import 'package:'''
            '''web_skin_dart/ui_core.dart';
          import 'package:react/react_dom.dart';

          main() {
            render(ErrorBoundary()(Foo()()), mountNode);
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

final getArgumentCheckboxManualUpdate =
    '// [ ] Check this box upon manually updating this argument '
    'to use a callback ref instead of the return value of `react_dom.render`.'
    '$willBeRemovedCommentSuffix';

final getVariableCheckboxManualUpdate =
    '// [ ] Check this box upon manually updating this variable to be set using'
    ' a callback ref instead of the return value of `react_dom.render`.'
    '$willBeRemovedCommentSuffix';

final checkboxComment = getCheckboxComment();
final checkboxCommentWithType = getCheckboxComment(includeTypeMessage: true);
final checkboxCommentExpressionRef =
    '// [ ] Check this box upon manual validation that '
    'the component rendered by this expression uses a ref safely.'
    '$willBeRemovedCommentSuffix';

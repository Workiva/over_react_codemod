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
            render() {
              react_dom.render(Foo()(), mountNode);
            }
          }
        ''',
        expectedOutput: '''
          main() {
            render() {
              react_dom.render(ErrorBoundary()(Foo()()), mountNode);
            }
          }
        ''',
      );
    });

    test('simple usage', () {
      testSuggestor(
        expectedPatchCount: 7,
        input: '''
          main() {
            render() {
              var instance = react_dom.render(Foo()(), mountNode);
            }
          }
        ''',
        expectedOutput: '''
          main() {
            render() {
              var instance;
              $checkboxCommentWithType
              react_dom.render(ErrorBoundary()((Foo()
                ..ref = (ref) { instance = ref; }
              )()), mountNode);
            }
          }
        ''',
      );
    });

    test('simple usage assignment to existing variable', () {
      testSuggestor(
        expectedPatchCount: 7,
        input: '''
          main() {
            render() {
              var instance;
              instance = react_dom.render(Foo()(), mountNode);
            }
          }
        ''',
        expectedOutput: '''
          main() {
            render() {
              var instance;
              $checkboxComment
              react_dom.render(ErrorBoundary()((Foo()
                ..ref = (ref) { instance = ref; }
              )()), mountNode);
            }
          }
        ''',
      );
    });

    test('simple usage with existing other props', () {
      testSuggestor(
        expectedPatchCount: 5,
        input: '''
          main() {
            render() {
              var instance = react_dom.render((Foo()
                ..id = 'foo'
              )(), mountNode);
            }
          }
        ''',
        expectedOutput: '''
          main() {
            render() {
              var instance;
              $checkboxCommentWithType
              react_dom.render(ErrorBoundary()((Foo()
                ..ref = (ref) { instance = ref; }
                ..id = 'foo'
              )()), mountNode);
            }
          }
        ''',
      );
    });

    test('simple usage with existing ref', () {
      testSuggestor(
        expectedPatchCount: 3,
        input: '''
          main() {
            render() {
              var fooRef;
              react_dom.render((Foo()
                ..ref = (ref) { fooRef = ref; }
              )(), mountNode);
            }
          }
        ''',
        expectedOutput: '''
          main() {
            render() {
              var fooRef;
              $checkboxComment
              react_dom.render(ErrorBoundary()((Foo()
                ..ref = (ref) { fooRef = ref; }
              )()), mountNode);
            }
          }
        ''',
      );
    });

    test('simple usage with existing ref in an arrow function', () {
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

    test('existing ref and assignment', () {
      // TODO do we even care about this case?
      testSuggestor(
//        expectedPatchCount: 1,
        input: '''
          main() {
            render() {
              var fooRef = react_dom.render((Foo()
                ..ref = (ref) { somethingElse = ref; }
              )(), mountNode);
            }
          }
        ''',
        expectedOutput: '''
          main() {
            render() {
              var fooRef;
              $checkboxCommentWithType
              react_dom.render(ErrorBoundary()((Foo()
                ..ref = (ref) { somethingElse = ref; }
              )()), mountNode);
            }
          }
        ''',
      );
    });

    test('simple usage with non-component usage', () {
      testSuggestor(
        expectedPatchCount: 16,
        input: '''
          main() {
            render() {
              var instance1 = react_dom.render(foo(), mountNode);

              var instance2 = react_dom.render(foo, mountNode);

              instance3 = react_dom.render(foo(), mountNode);

              instance4 = react_dom.render(foo, mountNode);
            }
          }
        ''',
        expectedOutput: '''
          main() {
            render() {
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
          }
        ''',
      );
    });

    test('simple usage with validated ref', () {
      testSuggestor(
        expectedPatchCount: 0,
        input: '''
          main() {
            render() {
              var fooRef;
              ${getCheckboxComment(checked: true)}
              react_dom.render(ErrorBoundary()((Foo()
                ..ref = (ref) { fooRef = ref; }
              )()), mountNode);
            }
          }
        ''',
      );
    });

    test('simple usage with unvalidated ref', () {
      testSuggestor(
        expectedPatchCount: 0,
        input: '''
          main() {
            render() {
              var fooRef;
              ${getCheckboxComment(checked: true)}
              react_dom.render(ErrorBoundary()((Foo()
                ..ref = (ref) { fooRef = ref; }
              )()), mountNode);
            }
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
              var instance2 = react_dom.render(Foo()(), mountNode);
            });
          }
        ''',
      );
    });

    test('simple usage outside of a lifecycle method', () {
      testSuggestor(
        expectedPatchCount: 0,
        input: '''
          main() {
            var instance = react_dom.render(Foo()(), mountNode);
          }
        ''',
      );
    });
  });
}

String getCheckboxComment({
  bool includeTypeMessage = false,
  bool checked: false,
}) =>
    '// ${checked ? '[x]' : '[ ]'}'
    ' Check this box upon manual validation of this ref'
    '${includeTypeMessage ? ' and its typing' : ''}.'
    '$willBeRemovedCommentSuffix';

final checkboxComment = getCheckboxComment();
final checkboxCommentWithType = getCheckboxComment(includeTypeMessage: true);
final checkboxCommentExpressionRef =
    '// [ ] Check this box upon manual validation that '
    'the component rendered by this expression uses a ref safely.'
    '$willBeRemovedCommentSuffix';

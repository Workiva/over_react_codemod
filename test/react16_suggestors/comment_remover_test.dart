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

import 'package:over_react_codemod/src/react16_suggestors/comment_remover.dart';
import 'package:over_react_codemod/src/react16_suggestors/constants.dart';
import 'package:test/test.dart';

import '../util.dart';

const manualCheckedStyleMapString = '// [x] Check this box upon manual '
    'validation that this style map uses a valid value for the keys that are '
    'numbers.';

const manualCheckedRefString = '// [x] Check this box upon manual validation of'
    ' this ref and its typing. $willBeRemovedCommentSuffix';

main() {
  group('CommentRemover', () {
    final testSuggestor =
        getSuggestorTester(CommentRemover('Check this box', 'complete'));

    test('does not update an empty file', () async {
      await testSuggestor(expectedPatchCount: 0, input: '');
    });

    test('does not update when there are no matches', () async {
      await testSuggestor(
        expectedPatchCount: 0,
        input: '''
          class test extends UiComponent {
            // Hello!
          }
        ''',
      );
    });

    group('when removing style map comments', () {
      group('updates when there is a basic comment', () {
        test('', () async {
          await testSuggestor(
            expectedPatchCount: 1,
            input: '''
          class Test extends UiComponent {
            var aTest = Foo()
            $manualCheckedStyleMapString $willBeRemovedCommentSuffix
            ..style = {};
          }
        ''',
            expectedOutput: '''
          class Test extends UiComponent {
            var aTest = Foo()
            ..style = {};
          }
        ''',
          );
        });

        test('nested under a function', () async {
          await testSuggestor(
            expectedPatchCount: 1,
            input: '''
          class test extends UiComponent {
            dynamic function() {
              return Foo()
                $manualCheckedStyleMapString $willBeRemovedCommentSuffix
                ..style = {};
            }
          }
        ''',
            expectedOutput: '''
          class test extends UiComponent {
            dynamic function() {
              return Foo()
                ..style = {};
            }
          }
        ''',
          );
        });
      });

      test('updates when there is a multiline comment', () async {
        await testSuggestor(
          expectedPatchCount: 1,
          input: '''
          class Test extends UiComponent {
            var aTest = Foo()
             $manualCheckedStyleMapString
             $styleMapExplanation
             //$willBeRemovedCommentSuffix
             ..style = {};
            }
          ''',
          expectedOutput: '''
            class Test extends UiComponent {
              var aTest = Foo()
              ..style = {};
            }
          ''',
        );
      });

      test(
          'updates when there is a multiline comment and a comment string is'
          ' split', () async {
        await testSuggestor(
          expectedPatchCount: 1,
          input: '''
          class Test extends UiComponent {
            var aTest = Foo()
             // [x] Check this box upon manual validation that this style map is
             // receiving a value that is valid for the following keys: width.
             $styleMapExplanation
             //$willBeRemovedCommentSuffix
             ..style = {};
            }
          ''',
          expectedOutput: '''
            class Test extends UiComponent {
              var aTest = Foo()
              ..style = {};
            }
          ''',
        );

        await testSuggestor(
          expectedPatchCount: 1,
          input: '''
          class Test extends UiComponent {
            var aTest = Foo()
             // [x] Check this box upon manual validation that this style map is
             // receiving a value that is valid for the keys that are simple
             // string variables.
             $styleMapExplanation
             //$willBeRemovedCommentSuffix
             ..style = {};
            }
          ''',
          expectedOutput: '''
            class Test extends UiComponent {
              var aTest = Foo()
              ..style = {};
            }
          ''',
        );

        await testSuggestor(
          expectedPatchCount: 1,
          input: '''
          class Test extends UiComponent {
            var aTest = Foo()
             // [x] Check this box upon manual validation that this style map
             // uses a valid value for the keys that are numbers.
             $styleMapExplanation
             //$willBeRemovedCommentSuffix
             ..style = {};
            }
          ''',
          expectedOutput: '''
            class Test extends UiComponent {
              var aTest = Foo()
              ..style = {};
            }
          ''',
        );
      });

      test('does not remove comments above', () async {
        await testSuggestor(
          expectedPatchCount: 1,
          input: ''' 
          class Test extends UiComponent {
            var aTest = Foo()
             // A random comment that should not be removed.
             $manualCheckedStyleMapString
             $styleMapExplanation
             //$willBeRemovedCommentSuffix
             ..style = {};
            }
          ''',
          expectedOutput: '''
            class Test extends UiComponent {
              var aTest = Foo()
              // A random comment that should not be removed.
              ..style = {};
            }
          ''',
        );
      });

      test('does not remove comments below', () async {
        await testSuggestor(
          expectedPatchCount: 1,
          input: '''
          class Test extends UiComponent {
            var aTest = Foo()
             $manualCheckedStyleMapString
             $styleMapExplanation
             //$willBeRemovedCommentSuffix
             // A random comment that should not be removed.
             ..style = {};
            }
          ''',
          expectedOutput: '''
            class Test extends UiComponent {
              var aTest = Foo()
              // A random comment that should not be removed.
              ..style = {};
            }
          ''',
        );
      });
    });

    group('when removing react_dom.render comments', () {
      test('updates when there is a basic comment', () async {
        await testSuggestor(
          expectedPatchCount: 1,
          input: '''
            main() {
              var instance;
              $manualCheckedRefString
              react_dom.render(ErrorBoundary()((Foo()
                ..ref = (ref) { instance = ref; }
              )()), mountNode);
            }
          ''',
          expectedOutput: '''
            main() {
              var instance;
              react_dom.render(ErrorBoundary()((Foo()
                ..ref = (ref) { instance = ref; }
              )()), mountNode);
            }
          ''',
        );
      });

      test('updates when there is a multiline comment', () async {
        await testSuggestor(
          expectedPatchCount: 1,
          input: '''
            main() {
              var instance;
              // [x] Check this box upon manual validation of
              // this ref and its typing.
              // $willBeRemovedCommentSuffix
              react_dom.render(ErrorBoundary()((Foo()
                ..ref = (ref) { instance = ref; }
              )()), mountNode);
            }
          ''',
          expectedOutput: '''
            main() {
              var instance;
              react_dom.render(ErrorBoundary()((Foo()
                ..ref = (ref) { instance = ref; }
              )()), mountNode);
            }
          ''',
        );

        await testSuggestor(
          expectedPatchCount: 1,
          input: '''
          main() {
            void mount() {
            // [x] Check this box upon manual validation of this ref. This will be removed once the transition to React 16 is
            // complete.
            react_dom.render(
                ErrorBoundary()(
                  (FileInput()
                    ..id = 'file_input'
                    ..ref = ((ref) => fileInputRef = ref)
                  )(),
                ),
                mountNode);
            }
          }
        ''',
          expectedOutput: '''
          main() {
            void mount() {
            react_dom.render(
                ErrorBoundary()(
                  (FileInput()
                    ..id = 'file_input'
                    ..ref = ((ref) => fileInputRef = ref)
                  )(),
                ),
                mountNode);
            }
          }
        ''',
        );
      });
    });
  });
}

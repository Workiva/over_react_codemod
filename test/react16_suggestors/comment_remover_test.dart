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

main() {
  group('DependencyOverrideUpdater', () {
    final testSuggestor = getSuggestorTester(
        CommentRemover([manualValidationCommentSubstring,
          styleMapExample,
          'Incorrect value for',
          'CSS number strings are no longer auto-converted to px',
          willBeRemovedCommentSuffix,
        ]));

    test('does not update an empty file', () {
      testSuggestor(expectedPatchCount: 0, input: '');
    });

    test('does not update when there are no matches', () {
      testSuggestor(
        expectedPatchCount: 0,
        input: '''
          class test extends UiComponent {
            // Hello!
          }
        ''',
      );
    });

    test('updates when there is a basic comment', () {
      testSuggestor(
        expectedPatchCount: 1,
        input: '''
          class test extends UiComponent {
            // [] ${manualValidationCommentSubstring}
          }
        ''',
        expectedOutput: '''
          class test extends UiComponent {
          }
        ''',
      );
    });

    test('when there are two comments in the same file', () {
      testSuggestor(
        expectedPatchCount: 1,
        input: '''
          class test extends UiComponent {
            // [] ${manualValidationCommentSubstring}
          }
        ''',
        expectedOutput: '''
          class test extends UiComponent {
          }
        ''',
      );
    });

    group('a multiline comment', () {
      test('with an unchecked box', () {
        testSuggestor(
          expectedPatchCount: 4,
          input: '''
          class test extends UiComponent {
            var test = Foo()
             // [ ] Check this box upon manual validation that this style map uses a valid value for the keys that are numbers.
             $styleMapExample
             //$willBeRemovedCommentSuffix
             ..style = {};
            }
          ''',
        );
      });

      test('with a checked box', () {
        testSuggestor(
          expectedPatchCount: 4,
          input: '''
          class test extends UiComponent {
            var test = Foo()
             // [x] Check this box upon manual validation that this style map uses a valid value for the keys that are numbers.
             $styleMapExample
             //$willBeRemovedCommentSuffix
             ..style = {};
            }
          ''',
          expectedOutput: '''
            class test extends UiComponent {
              var test = Foo()
              ..style = {};
            }
          ''',
        );
      });
    });
  });
}

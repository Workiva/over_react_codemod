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

import 'package:over_react_codemod/src/react16_suggestors/react_16_pubspec_upgrader.dart';
import 'package:test/test.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:over_react_codemod/src/react16_suggestors/constants.dart';

import '../util.dart';

main() {
  group('React16PubspecUpdater', () {
    final testSuggestor = getSuggestorTester(React16PubspecUpdater(VersionConstraint.parse(reactVersionRange)));

    test('does nothing if there is no dependency key', () {
      testSuggestor(
        expectedPatchCount: 0,
        shouldDartfmtOutput: false,
        input: '''
          name: nothing
          verion: 0.0.0
        ''',
        expectedOutput: '''
          name: nothing
          verion: 0.0.0
        ''',
      );
    });

    test('adds dependency if missing', () {
      testSuggestor(
        expectedPatchCount: 1,
        shouldDartfmtOutput: false,
        input: '''
          dependencies:
            test: 1.5.1
        ''',
        expectedOutput: '''
          dependencies:
            react: '>=4.7.0 <6.0.0'
            test: 1.5.1
        ''',
      );
    });

    group('updates the caret syntax', () {
      test('', () {
        testSuggestor(
          expectedPatchCount: 1,
          shouldDartfmtOutput: false,
          input: '''
          react: ^4.6.1
          test: 1.5.1
        ''',
          expectedOutput: '''
          react: '>=4.7.0 <6.0.0'
          test: 1.5.1
        ''',
        );
      });

      test('with single quotes', () {
        testSuggestor(
          expectedPatchCount: 1,
          shouldDartfmtOutput: false,
          input: '''
          react: '^4.6.1'
          test: 1.5.1
        ''',
          expectedOutput: '''
          react: '>=4.7.0 <6.0.0'
          test: 1.5.1
        ''',
        );
      });

      test('with double quotes', () {
        testSuggestor(
          expectedPatchCount: 1,
          shouldDartfmtOutput: false,
          input: '''
          react: '^4.6.1'
          test: 1.5.1
        ''',
          expectedOutput: '''
          react: '>=4.7.0 <6.0.0'
          test: 1.5.1
        ''',
        );
      });
    });

    group('updates the range syntax', () {
      test('with single quotes', () {
        testSuggestor(
          expectedPatchCount: 1,
          shouldDartfmtOutput: false,
          input: '''
          react: '>=4.5.0 <4.6.5'
          test: 1.5.1
        ''',
          expectedOutput: '''
          react: '>=4.7.0 <6.0.0'
          test: 1.5.1
        ''',
        );
      });

      test('with double quotes', () {
        testSuggestor(
          expectedPatchCount: 1,
          shouldDartfmtOutput: false,
          input: '''
          react: ">=4.5.0 <4.6.5"
          test: 1.5.1
        ''',
          expectedOutput: '''
          react: ">=4.7.0 <6.0.0"
          test: 1.5.1
        ''',
        );
      });
    });

    group('updates mid-only range', () {
      test('', () {
        testSuggestor(
          expectedPatchCount: 1,
          shouldDartfmtOutput: false,
          input: '''
          react: >=4.5.0
          test: 1.5.1
        ''',
          expectedOutput: '''
          react: '>=4.7.0 <6.0.0'
          test: 1.5.1
        ''',
        );
      });

      test('with single quotes', () {
        testSuggestor(
          expectedPatchCount: 1,
          shouldDartfmtOutput: false,
          input: '''
          react: '>=4.5.0'
          test: 1.5.1
        ''',
          expectedOutput: '''
          react: '>=4.7.0 <6.0.0'
          test: 1.5.1
        ''',
        );
      });

      test('with double quotes', () {
        testSuggestor(
          expectedPatchCount: 1,
          shouldDartfmtOutput: false,
          input: '''
          react: ">=4.5.0"
          test: 1.5.1
        ''',
          expectedOutput: '''
          react: ">=4.7.0 <6.0.0"
          test: 1.5.1
        ''',
        );
      });
    });
  });
}
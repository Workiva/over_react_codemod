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
import 'package:over_react_codemod/src/react16_suggestors/pubspec_react_upgrader.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import '../util.dart';

main() {
  group('React16PubspecUpdater', () {
    final testSuggestor = getSuggestorTester(
        PubspecReactUpdater(VersionConstraint.parse(reactVersionRange)));

    test('does nothing if there is no dependency key', () {
      testSuggestor(
        expectedPatchCount: 0,
        shouldDartfmtOutput: false,
        input: ''
            'name: nothing\n'
            'verion: 0.0.0\n'
            '',
        expectedOutput: ''
            'name: nothing\n'
            'verion: 0.0.0\n'
            '',
      );
    });

    test('adds dependency if missing', () {
      testSuggestor(
        expectedPatchCount: 1,
        shouldDartfmtOutput: false,
        input: ''
            'dependencies:\n'
            '  test: 1.5.1\n'
            '',
        expectedOutput: ''
            'dependencies:\n'
            '  react: \'>=4.7.0 <6.0.0\'\n'
            '  test: 1.5.1\n'
            '',
      );
    });

    group('updates the caret syntax', () {
      test('', () {
        testSuggestor(
          expectedPatchCount: 1,
          shouldDartfmtOutput: false,
          input: ''
              'react: ^4.6.1\n'
              'test: 1.5.1\n'
              '',
          expectedOutput: getExpectedOutput(),
        );
      });

      test('with single quotes', () {
        testSuggestor(
          expectedPatchCount: 1,
          shouldDartfmtOutput: false,
          input: ''
              'react: \'^4.6.1\'\n'
              'test: 1.5.1\n'
              '',
          expectedOutput: getExpectedOutput(),
        );
      });

      test('with double quotes', () {
        testSuggestor(
          expectedPatchCount: 1,
          shouldDartfmtOutput: false,
          input: ''
              'react: "^4.6.1"\n'
              'test: 1.5.1\n'
              '',
          expectedOutput: getExpectedOutput(usesDoubleQuotes: true),
        );
      });
    });

    group('updates the range syntax', () {
      test('with single quotes', () {
        testSuggestor(
          expectedPatchCount: 1,
          shouldDartfmtOutput: false,
          input: ''
              'react: \'>=4.5.0 <4.6.5\'\n'
              'test: 1.5.1\n'
              '',
          expectedOutput: getExpectedOutput(),
        );
      });

      test('with double quotes', () {
        testSuggestor(
          expectedPatchCount: 1,
          shouldDartfmtOutput: false,
          input: ''
              'react: ">=4.5.0 <4.6.5"\n'
              'test: 1.5.1\n'
              '',
          expectedOutput: getExpectedOutput(usesDoubleQuotes: true),
        );
      });
    });

    group('updates mid-only range', () {
      test('', () {
        testSuggestor(
          expectedPatchCount: 1,
          shouldDartfmtOutput: false,
          input: ''
              'react: >=4.5.0\n'
              'test: 1.5.1\n'
              '',
          expectedOutput: getExpectedOutput(),
        );
      });

      test('with single quotes', () {
        testSuggestor(
          expectedPatchCount: 1,
          shouldDartfmtOutput: false,
          input: ''
              'react: \'>=4.5.0\'\n'
              'test: 1.5.1\n'
              '',
          expectedOutput: getExpectedOutput(),
        );
      });

      test('with double quotes', () {
        testSuggestor(
          expectedPatchCount: 1,
          shouldDartfmtOutput: false,
          input: ''
              'react: ">=4.5.0"\n'
              'test: 1.5.1\n'
              '',
          expectedOutput: getExpectedOutput(usesDoubleQuotes: true),
        );
      });
    });
  });
}

String getExpectedOutput({
  bool usesDoubleQuotes = false,
}) {
  String quotes = usesDoubleQuotes ? '"' : "'";

  return ''
      'react: $quotes>=4.7.0 <6.0.0$quotes\n'
      'test: 1.5.1\n'
      '';
}

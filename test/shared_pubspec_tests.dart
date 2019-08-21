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

import 'package:meta/meta.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

void sharedPubspecTest({
  @required
      Function({bool usesDoubleQuotes, bool shouldAddSpace}) getExpectedOutput,
  @required Function testSuggestor,
  @required String dependency,
  @required VersionRange startingRange,
  bool shouldUpdateMidRange,
  String midVersionRange,
}) {
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

  test('does nothing if the dependency matches the target already', () {
    testSuggestor(
      expectedPatchCount: 0,
      shouldDartfmtOutput: false,
      input: ''
          'name: nothing\n'
          'verion: 0.0.0\n'
          'dependencies:\n'
          '${getExpectedOutput(shouldAddSpace: true)}'
          '',
      expectedOutput: ''
          'name: nothing\n'
          'verion: 0.0.0\n'
          'dependencies:\n'
          '${getExpectedOutput(shouldAddSpace: true)}'
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
          '${getExpectedOutput(shouldAddSpace: true)}'
          '',
    );
  });

  group('updates the caret syntax', () {
    test('', () {
      testSuggestor(
        expectedPatchCount: 1,
        shouldDartfmtOutput: false,
        input: ''
            '$dependency: ^${startingRange.min}\n'
            'test: 1.5.1\n'
            '',
        expectedOutput: getExpectedOutput(),
      );
    });

    if (midVersionRange != null) {
      assert(midVersionRange != null);

      String output = shouldUpdateMidRange
          ? getExpectedOutput()
          : ''
          '$dependency: $midVersionRange\n'
          'test: 1.5.1\n'
          '';

      test(
          '${shouldUpdateMidRange ? '' : 'except'} when the version is within the expected range',
          () {
        testSuggestor(
          expectedPatchCount: shouldUpdateMidRange ? 1 : 0,
          shouldDartfmtOutput: false,
          input: ''
              '$dependency: $midVersionRange\n'
              'test: 1.5.1\n'
              '',
          expectedOutput: output,
        );
      });
    }

    test('with single quotes', () {
      testSuggestor(
        expectedPatchCount: 1,
        shouldDartfmtOutput: false,
        input: ''
            '$dependency: \'^${startingRange.min}\'\n'
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
            '$dependency: "^${startingRange.min}"\n'
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
            '$dependency: \'$startingRange\'\n'
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
            '$dependency: "$startingRange"\n'
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
            '$dependency: >=${startingRange.min}\n'
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
            '$dependency: \'>=${startingRange.min}\'\n'
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
            '$dependency: ">=${startingRange.min}"\n'
            'test: 1.5.1\n'
            '',
        expectedOutput: getExpectedOutput(usesDoubleQuotes: true),
      );
    });
  });
}

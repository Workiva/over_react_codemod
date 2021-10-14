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

import 'package:over_react_codemod/src/constants.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:test/test.dart';

import 'util.dart';

/// Testing suite used to validate codemods that update pubspec.yaml
/// dependencies.
///
/// `getExpectedOutput` is used because the dependency name and version will
/// change based on the dependency being tested, and the output can change
/// based on the test. `useMidVersionMin` is required because the codemod
/// will match the midversion lowest constraint.
///
/// `testSuggestor` is the suggestor that all of the tests will be run against.
///
/// `dependency` is the name of the dependency being tested.
///
/// `startingRange` is the range that exists in the pubspec before the
/// suggestor is run.
///
/// `shouldAddDependencies` means the suggestor will add the dependency to
/// the pubspec if it is not already there.
///
/// `shouldUpdate` will determine if the tests should have any patches at all.
/// If the starting range is acceptable, the tests should indicate no updates.
///
/// `shouldUpdateMidRange` indicates whether or not the suggestor will update
/// a range if the dependency's constraint is already within the target
/// constraint's bounds.
///
/// `midVersionRange` is a version range between the expected range max and
/// min. Used in conjunction with `shouldUpdateMidRange`.
void sharedPubspecTest({
  required Function({bool useMidVersionMin, String? hostedUrl})
      getExpectedOutput,
  required SuggestorTester testSuggestor,
  required String dependency,
  required VersionRange startingRange,
  required bool isDevDependency,
  String? hostedUrl,
  bool shouldAddDependencies = true,
  bool shouldUpdate = true,
  bool shouldUpdateMidRange = true,
  String? midVersionRange,
}) {
  final patchCount = shouldUpdate ? 1 : 0;
  final key = isDevDependency ? 'dev_dependencies' : 'dependencies';

  test('does nothing if there is no dependency key', () async {
    await testSuggestor(
      expectedPatchCount: 0,
      shouldDartfmtOutput: false,
      validateContents: validatePubspecYaml,
      input: ''
          'name: nothing\n'
          'version: 0.0.0\n'
          '',
      expectedOutput: ''
          'name: nothing\n'
          'version: 0.0.0\n'
          '',
    );
  });

  test('does nothing if the dependency matches the target already', () async {
    await testSuggestor(
      expectedPatchCount: 0,
      shouldDartfmtOutput: false,
      validateContents: validatePubspecYaml,
      input: ''
          'name: nothing\n'
          'version: 0.0.0\n'
          '${getExpectedOutput(hostedUrl: hostedUrl)}'
          '',
      expectedOutput: ''
          'name: nothing\n'
          'version: 0.0.0\n'
          '${getExpectedOutput(hostedUrl: hostedUrl)}'
          '',
    );
  });

  test('does nothing if the dependency is set to `any`', () async {
    await testSuggestor(
      expectedPatchCount: 0,
      shouldDartfmtOutput: false,
      validateContents: validatePubspecYaml,
      input: ''
          'name: nothing\n'
          'version: 0.0.0\n'
          '$key:\n'
          '${getDependencyDeclaration(dependency, 'any', hostedUrl)}'
          '',
      expectedOutput: ''
          'name: nothing\n'
          'version: 0.0.0\n'
          '$key:\n'
          '${getDependencyDeclaration(dependency, 'any', hostedUrl)}'
          '',
    );
  });

  test(
      '${shouldAddDependencies ? 'adds the' : 'does not add the'} dependency '
      'if missing', () async {
    await testSuggestor(
      expectedPatchCount: shouldAddDependencies ? 1 : 0,
      shouldDartfmtOutput: false,
      validateContents: validatePubspecYaml,
      input: ''
          '$key:\n'
          '  test: 1.5.1\n'
          '',
      expectedOutput: ''
          '${shouldAddDependencies ? getExpectedOutput(hostedUrl: hostedUrl) : ''
              '$key:\n'
              '  test: 1.5.1\n'}'
          '',
    );
  });

  if (shouldAddDependencies) {
    group('adds the dependency, if missing, in correct alphabetical order', () {
      final expectedAddedDep = (hostedUrl == null
                  ? getDependencyRegExp(dependency)
                  : getHostedDependencyRegExp(dependency))
              .firstMatch(getExpectedOutput(hostedUrl: hostedUrl))
              ?.group(0) ??
          '';

      test('when the dependency should be first', () async {
        await testSuggestor(
          expectedPatchCount: 1,
          shouldDartfmtOutput: false,
          validateContents: validatePubspecYaml,
          input: ''
              '$key:\n'
              '  z: 1.5.1\n'
              '',
          expectedOutput: ''
              '$key:\n'
              '  $expectedAddedDep\n'
              '  z: 1.5.1\n'
              '',
        );
      });

      test('when the dependency should be last', () async {
        await testSuggestor(
          expectedPatchCount: 1,
          shouldDartfmtOutput: false,
          validateContents: validatePubspecYaml,
          input: ''
              '$key:\n'
              '  a: 1.5.1\n'
              '  c: 1.5.1\n'
              '',
          expectedOutput: ''
              '$key:\n'
              '  a: 1.5.1\n'
              '  c: 1.5.1\n'
              '  $expectedAddedDep\n'
              '',
        );
      });

      test('when the dependency should be in the middle', () async {
        await testSuggestor(
          expectedPatchCount: 1,
          shouldDartfmtOutput: false,
          validateContents: validatePubspecYaml,
          input: ''
              '$key:\n'
              '  a: 1.5.1\n'
              '  b: 1.5.1\n'
              '  x: 1.5.1\n'
              '',
          expectedOutput: ''
              '$key:\n'
              '  a: 1.5.1\n'
              '  b: 1.5.1\n'
              '  $expectedAddedDep\n'
              '  x: 1.5.1\n'
              '',
        );
      });
    });
  }

  group('updates the caret syntax', () {
    test('', () async {
      await testSuggestor(
        expectedPatchCount: patchCount,
        shouldDartfmtOutput: false,
        validateContents: validatePubspecYaml,
        input: ''
            '$key:\n'
            '${getDependencyDeclaration(dependency, '^${startingRange.min}', hostedUrl)}'
            '  test: 1.5.1\n'
            '',
        expectedOutput: shouldUpdate
            ? getExpectedOutput(hostedUrl: hostedUrl)
            : ''
                '$key:\n'
                '${getDependencyDeclaration(dependency, '^${startingRange.min}', hostedUrl)}'
                '  test: 1.5.1\n'
                '',
      );
    });

    test(
        '${shouldUpdateMidRange ? '' : 'except'} when the version is within the expected range',
        () async {
      await testSuggestor(
        expectedPatchCount: shouldUpdateMidRange ? 1 : 0,
        shouldDartfmtOutput: false,
        validateContents: validatePubspecYaml,
        input: ''
            '$key:\n'
            '${getDependencyDeclaration(dependency, midVersionRange, hostedUrl)}'
            '  test: 1.5.1\n'
            '',
        expectedOutput: shouldUpdateMidRange
            ? getExpectedOutput(useMidVersionMin: true, hostedUrl: hostedUrl)
            : ''
                '$key:\n'
                '${getDependencyDeclaration(dependency, midVersionRange, hostedUrl)}'
                '  test: 1.5.1\n'
                '',
      );
    });

    test('with single quotes', () async {
      await testSuggestor(
        expectedPatchCount: patchCount,
        shouldDartfmtOutput: false,
        validateContents: validatePubspecYaml,
        input: ''
            '$key:\n'
            '${getDependencyDeclaration(dependency, '\'^${startingRange.min}\'', hostedUrl)}'
            '  test: 1.5.1\n'
            '',
        expectedOutput: shouldUpdate
            ? getExpectedOutput(hostedUrl: hostedUrl)
            : ''
                '$key:\n'
                '${getDependencyDeclaration(dependency, '\'^${startingRange.min}\'', hostedUrl)}'
                '  test: 1.5.1\n'
                '',
      );
    });

    test('with double quotes', () async {
      await testSuggestor(
        expectedPatchCount: patchCount,
        shouldDartfmtOutput: false,
        validateContents: validatePubspecYaml,
        input: ''
            '$key:\n'
            '${getDependencyDeclaration(dependency, '"^${startingRange.min}"', hostedUrl)}'
            '  test: 1.5.1\n'
            '',
        expectedOutput: shouldUpdate
            ? getExpectedOutput(hostedUrl: hostedUrl)
            : ''
                '$key:\n'
                '${getDependencyDeclaration(dependency, '"^${startingRange.min}"', hostedUrl)}'
                '  test: 1.5.1\n'
                '',
      );
    });
  });

  group('updates the range syntax', () {
    test('with single quotes', () async {
      await testSuggestor(
        expectedPatchCount: patchCount,
        shouldDartfmtOutput: false,
        validateContents: validatePubspecYaml,
        input: ''
            '$key:\n'
            '${getDependencyDeclaration(dependency, '\'$startingRange\'', hostedUrl)}'
            '  test: 1.5.1\n'
            '',
        expectedOutput: shouldUpdate
            ? getExpectedOutput(hostedUrl: hostedUrl)
            : ''
                '$key:\n'
                '${getDependencyDeclaration(dependency, '\'$startingRange\'', hostedUrl)}'
                '  test: 1.5.1\n'
                '',
      );
    });

    test('with double quotes', () async {
      await testSuggestor(
        expectedPatchCount: patchCount,
        shouldDartfmtOutput: false,
        validateContents: validatePubspecYaml,
        input: ''
            '$key:\n'
            '${getDependencyDeclaration(dependency, '"$startingRange"', hostedUrl)}'
            '  test: 1.5.1\n'
            '',
        expectedOutput: shouldUpdate
            ? getExpectedOutput(hostedUrl: hostedUrl)
            : ''
                '$key:\n'
                '${getDependencyDeclaration(dependency, '"$startingRange"', hostedUrl)}'
                '  test: 1.5.1\n'
                '',
      );
    });
  });

  group('updates mid-only range', () {
    test('', () async {
      await testSuggestor(
        expectedPatchCount: patchCount,
        shouldDartfmtOutput: false,
        validateContents: validatePubspecYaml,
        input: ''
            '$key:\n'
            '${getDependencyDeclaration(dependency, '">=${startingRange.min}"', hostedUrl)}'
            '  test: 1.5.1\n'
            '',
        expectedOutput: shouldUpdate
            ? getExpectedOutput(hostedUrl: hostedUrl)
            : ''
                '$key:\n'
                '${getDependencyDeclaration(dependency, '">=${startingRange.min}"', hostedUrl)}'
                '  test: 1.5.1\n'
                '',
      );
    });

    test('with single quotes', () async {
      await testSuggestor(
        expectedPatchCount: patchCount,
        shouldDartfmtOutput: false,
        validateContents: validatePubspecYaml,
        input: ''
            '$key:\n'
            '${getDependencyDeclaration(dependency, '\'>=${startingRange.min}\'', hostedUrl)}'
            '  test: 1.5.1\n'
            '',
        expectedOutput: shouldUpdate
            ? getExpectedOutput(hostedUrl: hostedUrl)
            : ''
                '$key:\n'
                '${getDependencyDeclaration(dependency, '\'>=${startingRange.min}\'', hostedUrl)}'
                '  test: 1.5.1\n'
                '',
      );
    });

    test('with double quotes', () async {
      await testSuggestor(
        expectedPatchCount: patchCount,
        shouldDartfmtOutput: false,
        validateContents: validatePubspecYaml,
        input: ''
            '$key:\n'
            '${getDependencyDeclaration(dependency, '">=${startingRange.min}"', hostedUrl)}'
            '  test: 1.5.1\n'
            '',
        expectedOutput: shouldUpdate
            ? getExpectedOutput(hostedUrl: hostedUrl)
            : ''
                '$key:\n'
                '${getDependencyDeclaration(dependency, '">=${startingRange.min}"', hostedUrl)}'
                '  test: 1.5.1\n'
                '',
      );
    });
  });
}

String getDependencyDeclaration(String dependency, String? version,
    [String? hostedUrl]) {
  if (hostedUrl != null) {
    return '  $dependency:\n'
        '    hosted:\n'
        '      name: $dependency\n'
        '      url: $hostedUrl\n'
        '    version: $version\n';
  }

  return '  $dependency: $version\n';
}

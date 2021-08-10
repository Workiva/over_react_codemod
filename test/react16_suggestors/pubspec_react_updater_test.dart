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

import '../shared_pubspec_tests.dart';
import '../util.dart';

/// Variable used for testing how the codemod handles being given a
/// constraint in the middle of the upgrade range.
///
/// Must be between the min and max constraints used in the testing group.
/// This variable is also used by [getExpectedOutput] because the tests will
/// use this variable as the lower bound when the codemod encounters the range.
const midVersionMin = '4.8.3';

main() {
  group('PubspecReactUpdater', () {
    /// Suggestor used to test the default configurations.
    final testSuggestor = getSuggestorTester(
        PubspecReactUpdater(VersionConstraint.parse(reactVersionRange) as VersionRange) as Stream<Patch> Function(FileContext));

    /// Suggestor to test when the codemod should not add the dependency if
    /// it does not encounter it.
    final doNotAddDependencies = getSuggestorTester(PubspecReactUpdater(
        VersionConstraint.parse(reactVersionRange) as VersionRange,
        shouldAddDependencies: false) as Stream<Patch> Function(FileContext));

    group('when there are no special cases', () {
      sharedPubspecTest(
          testSuggestor: testSuggestor,
          getExpectedOutput: getExpectedOutput as dynamic Function({bool? useMidVersionMin}),
          startingRange: VersionConstraint.parse('>=4.6.1 <4.9.0') as VersionRange,
          isDevDependency: false,
          dependency: 'react',
          midVersionRange: '^$midVersionMin');

      group('and the new version is a pre-release version', () {
        sharedPubspecTest(
            testSuggestor: getSuggestorTester(PubspecReactUpdater(
                VersionConstraint.parse(reactVersionRangeForTesting) as VersionRange) as Stream<Patch> Function(FileContext)),
            getExpectedOutput: getExpectedPreReleaseOutput as dynamic Function({bool? useMidVersionMin}),
            startingRange: VersionConstraint.parse('>=4.6.1 <4.9.0') as VersionRange,
            isDevDependency: false,
            midVersionRange: '^5.5.3',
            shouldUpdateMidRange: false,
            dependency: 'react');
      });
    });

    group('when the codemod should not add dependencies', () {
      sharedPubspecTest(
          testSuggestor: doNotAddDependencies,
          getExpectedOutput: getExpectedOutput as dynamic Function({bool? useMidVersionMin}),
          startingRange: VersionConstraint.parse('>=4.6.1 <4.9.0') as VersionRange,
          isDevDependency: false,
          dependency: 'react',
          midVersionRange: '^$midVersionMin',
          shouldAddDependencies: false);
    });

    group(
        'when the codemod should not update because the version range is '
        'acceptable', () {
      sharedPubspecTest(
          testSuggestor: testSuggestor,
          getExpectedOutput: getExpectedOutput as dynamic Function({bool? useMidVersionMin}),
          startingRange: VersionConstraint.parse('^5.0.0') as VersionRange,
          isDevDependency: false,
          dependency: 'react',
          shouldUpdate: false,
          shouldUpdateMidRange: false,
          midVersionRange: '^5.5.3');
    });

    test('does not lower the lower bound', () async {
      await testSuggestor(
        expectedPatchCount: 1,
        shouldDartfmtOutput: false,
        validateContents: validatePubspecYaml,
        input: ''
            'name: nothing\n'
            'version: 0.0.0\n'
            'dependencies:\n'
            '  react: ">=4.8.0 <5.0.0"\n'
            '  test: 1.5.1\n'
            '',
        expectedOutput: ''
            'name: nothing\n'
            'version: 0.0.0\n'
            'dependencies:\n'
            '  react: ">=4.8.0 <6.0.0"\n'
            '  test: 1.5.1\n'
            '',
      );
    });

    group('does not attempt to update dependency_overrides', () {
      test('git', () async {
        await testSuggestor(
          expectedPatchCount: 0,
          shouldDartfmtOutput: false,
          validateContents: validatePubspecYaml,
          input: ''
              'dependency_overrides:\n'
              '  react:\n'
              '    git:\n'
              '      url: git@github.com:cleandart/react-dart.git\n'
              '      ref: 5.0.0-wip\n',
        );
      });

      test('path', () async {
        await testSuggestor(
          expectedPatchCount: 0,
          shouldDartfmtOutput: false,
          validateContents: validatePubspecYaml,
          input: ''
              'dependency_overrides:\n'
              '  react:\n'
              '    path: ../\n',
        );
      });
    });
  });
}

String getExpectedOutput({bool useMidVersionMin = false}) {
  if (useMidVersionMin) {
    final expected =
        VersionConstraint.parse('^5.0.0').allows(Version.parse(midVersionMin))
            ? '^$midVersionMin'
            : '">=$midVersionMin <6.0.0"';

    return ''
        'dependencies:\n'
        '  react: $expected\n'
        '  test: 1.5.1\n'
        '';
  }

  return ''
      'dependencies:\n'
      '  react: ">=4.7.0 <6.0.0"\n'
      '  test: 1.5.1\n'
      '';
}

String getExpectedPreReleaseOutput({bool useMidVersionMin = false}) {
  return ''
      'dependencies:\n'
      '  react: ^5.0.0-alpha\n'
      '  test: 1.5.1\n'
      '';
}

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

import 'package:over_react_codemod/src/dart2_suggestors/pubspec_over_react_upgrader.dart';
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
const midRangeMark = '2.0.0';

main() {
  group('PubspecOverReactUpdater', () {
    const versionRange = '>=1.30.2 <3.0.0';
    const dependency = 'over_react';
    final startingTestRange = VersionConstraint.parse('>=1.0.0 <2.0.0');

    group('with shouldAlwaysUpdate false', () {
      final defaultTestSuggestor = getSuggestorTester(
          PubspecOverReactUpgrader(VersionConstraint.parse(versionRange)));

      final doNotAddDependencies = getSuggestorTester(PubspecOverReactUpgrader(
          VersionConstraint.parse(versionRange),
          shouldAddDependencies: false));

      sharedPubspecTest(
        testSuggestor: defaultTestSuggestor,
        getExpectedOutput: getExpectedOutput,
        startingRange: startingTestRange,
        dependency: dependency,
        midVersionRange: midRangeMark,
      );

      sharedPubspecTest(
        testSuggestor: doNotAddDependencies,
        getExpectedOutput: getExpectedOutput,
        startingRange: startingTestRange,
        dependency: dependency,
        midVersionRange: midRangeMark,
        shouldAddDependencies: false,
      );

      test('does not lower the lower bound', () {
        defaultTestSuggestor(
          expectedPatchCount: 1,
          shouldDartfmtOutput: false,
          validateContents: validatePubspecYaml,
          input: ''
              'name: nothing\n'
              'version: 0.0.0\n'
              'dependencies:\n'
              '  over_react: ">=1.50.0 <2.0.0"\n'
              '  test: 1.5.1\n'
              '',
          expectedOutput: ''
              'name: nothing\n'
              'version: 0.0.0\n'
              'dependencies:\n'
              '  over_react: ">=1.50.0 <3.0.0"\n'
              '  test: 1.5.1\n'
              '',
        );
      });

      group('does not attempt to update dependency_overrides', () {
        test('git', () {
          defaultTestSuggestor(
              expectedPatchCount: 0,
              shouldDartfmtOutput: false,
              validateContents: validatePubspecYaml,
              input: ''
                  'dependency_overrides:\n'
                  '  over_react:\n'
                  '    git:\n'
                  '      url: git@github.com:cleandart/react-dart.git\n'
                  '      ref: 5.0.0-wip\n',
          );
        });

        test('path', () {
          defaultTestSuggestor(
            expectedPatchCount: 0,
            shouldDartfmtOutput: false,
            validateContents: validatePubspecYaml,
            input: ''
                'dependency_overrides:\n'
                '  over_react:\n'
                '    path: ../\n',
          );
        });
      });
    });

    group('with shouldAlwaysUpdate true', () {
      final defaultTestSuggestor = getSuggestorTester(
          PubspecOverReactUpgrader.alwaysUpdate(
              VersionConstraint.parse(versionRange)));

      sharedPubspecTest(
        testSuggestor: defaultTestSuggestor,
        getExpectedOutput: getExpectedOutput,
        startingRange: startingTestRange,
        dependency: dependency,
        midVersionRange: midRangeMark,
      );

      group('does not attempt to update dependency_overrides', () {
        test('git', () {
          defaultTestSuggestor(
              expectedPatchCount: 0,
              shouldDartfmtOutput: false,
              validateContents: validatePubspecYaml,
              input: ''
                  'dependency_overrides:\n'
                  '  over_react:\n'
                  '    git:\n'
                  '      url: git@github.com:cleandart/react-dart.git\n'
                  '      ref: 5.0.0-wip\n',
              expectedOutput: ''
                  'dependency_overrides:\n'
                  '  over_react:\n'
                  '    git:\n'
                  '      url: git@github.com:cleandart/react-dart.git\n'
                  '      ref: 5.0.0-wip\n');
        });

        test('path', () {
          defaultTestSuggestor(
            expectedPatchCount: 0,
            shouldDartfmtOutput: false,
            validateContents: validatePubspecYaml,
            input: ''
                'dependency_overrides:\n'
                '  over_react:\n'
                '    path: ../\n',
            expectedOutput: ''
                'dependency_overrides:\n'
                '  over_react:\n'
                '    path: ../\n',
          );
        });
      });
    });
  });
}

String getExpectedOutput({bool useMidVersionMin = false}) {
  if (useMidVersionMin) {
    return ''
        'dependencies:\n'
        '  over_react: ">=$midRangeMark <3.0.0"\n'
        '  test: 1.5.1\n'
        '';
  }

  return ''
      'dependencies:\n'
      '  over_react: ">=1.30.2 <3.0.0"\n'
      '  test: 1.5.1\n'
      '';
}

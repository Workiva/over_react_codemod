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

main() {
  group('PubspecOverReactUpdater', () {
    final versionRange = '>=1.30.2 <3.0.0';
    final dependency = 'over_react';
    final midRangeMark = '^2.0.0';
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
        shouldUpdateMidRange: false,
      );

      sharedPubspecTest(
        testSuggestor: doNotAddDependencies,
        getExpectedOutput: getExpectedOutput,
        startingRange: startingTestRange,
        dependency: dependency,
        midVersionRange: midRangeMark,
        shouldAddDependencies: false,
        shouldUpdateMidRange: false,
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
        shouldUpdateMidRange: true,
      );
    });
  });
}

String getExpectedOutput({bool useMidVersionMin = false}) {
  if (useMidVersionMin) {
    return ''
        'dependencies:\n'
        '  over_react: ">=2.0.0 <3.0.0"\n'
        '  test: 1.5.1\n'
        '';
  }

  return ''
      'dependencies:\n'
      '  over_react: ">=1.30.2 <3.0.0"\n'
      '  test: 1.5.1\n'
      '';
}

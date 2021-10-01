// Copyright 2021 Workiva Inc.
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

import 'package:over_react_codemod/src/dependency_validator_suggestors/v3_updater.dart';
import 'package:test/test.dart';

import '../util.dart';

main() {
  group('V3DependencyUpdater', () {
    const addedDependency = 'an_added_dependency';
    final testSuggestor =
        getSuggestorTester(V3DependencyValidatorUpdater(addedDependency));

    test('updates when the file is empty', () async {
      await testSuggestor(
          shouldDartfmtOutput: false,
          expectedPatchCount: 1,
          input: '''''',
          expectedOutput: ''
              'ignore:\n'
              '  - $addedDependency\n'
              '');
    });

    test('adds an ignore tag if one is not present', () async {
      await testSuggestor(
          shouldDartfmtOutput: false,
          expectedPatchCount: 1,
          input: ''
              '# a comment above exclude\n'
              'exclude:\n'
              '  # a comment above an excluded directory\n'
              '  - app\n'
              '',
          expectedOutput: ''
              '# a comment above exclude\n'
              'exclude:\n'
              '  # a comment above an excluded directory\n'
              '  - app\n'
              'ignore:\n'
              '  - $addedDependency\n'
              '');
    });

    test('appends the new dependency to the ignore tag if the tag is present',
        () async {
      await testSuggestor(
          shouldDartfmtOutput: false,
          expectedPatchCount: 1,
          input: ''
              '# a comment above exclude\n'
              'exclude:\n'
              '  # a comment above an excluded directory\n'
              '  - app\n'
              'ignore:\n'
              '  # a comment above a specific dependency\n'
              '  - a_dependency\n'
              '',
          expectedOutput: ''
              '# a comment above exclude\n'
              'exclude:\n'
              '  # a comment above an excluded directory\n'
              '  - app\n'
              'ignore:\n'
              '  # a comment above a specific dependency\n'
              '  - a_dependency\n'
              '  - $addedDependency\n'
              '');
    });

    test('makes no change if the dependency is already there', () async {
      await testSuggestor(
          shouldDartfmtOutput: false,
          expectedPatchCount: 0,
          input: ''
              '# a comment above exclude\n'
              'exclude:\n'
              '  # a comment above an excluded directory\n'
              '  - app\n'
              'ignore:\n'
              '  # a comment above a specific dependency\n'
              '  - a_dependency\n'
              '  - $addedDependency\n'
              '');
    });
  });
}

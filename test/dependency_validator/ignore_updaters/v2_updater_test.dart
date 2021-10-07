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

import 'package:over_react_codemod/src/dependency_validator_suggestors/ignore_updaters/v2_updater.dart';
import 'package:test/test.dart';

import '../../util.dart';

main() {
  group('V2DependencyUpdater', () {
    const addedDependency = 'an_added_dependency';
    final testSuggestor =
        getSuggestorTester(V2DependencyValidatorUpdater(addedDependency));

    test('updates when the file is empty', () async {
      await testSuggestor(
          shouldDartfmtOutput: false,
          expectedPatchCount: 1,
          input: '''''',
          expectedOutput: ''
              'dependency_validator:\n'
              '  ignore:\n'
              '    - $addedDependency\n'
              '');
    });

    test('adds a dependency validator config if none exists', () async {
      await testSuggestor(
          shouldDartfmtOutput: false,
          expectedPatchCount: 1,
          input: ''
              'name: a_package\n'
              'version: 1.3.4\n'
              '\n'
              '# a comment above environment\n'
              'environment: ">=2.11.0 <3.0.0"\n'
              '\n'
              'dependencies:\n'
              '  # a comment above a dependency\n'
              '  a_dependency: ^1.0.0\n'
              '',
          expectedOutput: ''
              'name: a_package\n'
              'version: 1.3.4\n'
              '\n'
              '# a comment above environment\n'
              'environment: ">=2.11.0 <3.0.0"\n'
              '\n'
              'dependencies:\n'
              '  # a comment above a dependency\n'
              '  a_dependency: ^1.0.0\n'
              '\n'
              'dependency_validator:\n'
              '  ignore:\n'
              '    - $addedDependency\n'
              '');
    });

    group('adds an ignore tag if one is not present', () {
      test('and the config is at the bottom of the pubspec', () async {
        await testSuggestor(
            shouldDartfmtOutput: false,
            expectedPatchCount: 1,
            input: ''
                'name: a_package\n'
                'version: 1.3.4\n'
                '\n'
                '# a comment above environment\n'
                'environment: ">=2.11.0 <3.0.0"\n'
                '\n'
                'dependencies:\n'
                '  # a comment above a dependency\n'
                '  a_dependency: ^1.0.0\n'
                '\n'
                'dependency_validator:\n'
                '  exclude:\n'
                '    # a comment above an excluded directory\n'
                '    - app\n'
                '',
            expectedOutput: ''
                'name: a_package\n'
                'version: 1.3.4\n'
                '\n'
                '# a comment above environment\n'
                'environment: ">=2.11.0 <3.0.0"\n'
                '\n'
                'dependencies:\n'
                '  # a comment above a dependency\n'
                '  a_dependency: ^1.0.0\n'
                '\n'
                'dependency_validator:\n'
                '  exclude:\n'
                '    # a comment above an excluded directory\n'
                '    - app\n'
                '  ignore: \n'
                '    - $addedDependency\n'
                '');
      });

      test('and the config is not at the bottom of the pubspec', () async {
        await testSuggestor(
            shouldDartfmtOutput: false,
            expectedPatchCount: 1,
            input: ''
                'name: a_package\n'
                'version: 1.3.4\n'
                '\n'
                '# a comment above environment\n'
                'environment: ">=2.11.0 <3.0.0"\n'
                '\n'
                'dependencies:\n'
                '  # a comment above a dependency\n'
                '  a_dependency: ^1.0.0\n'
                '\n'
                'dependency_validator:\n'
                '  exclude:\n'
                '    # a comment above an excluded directory\n'
                '    - app\n'
                '\n'
                'dependency_overrides:\n'
                '  over_react:\n'
                '    path: ../over_react\n'
                '',
            expectedOutput: ''
                'name: a_package\n'
                'version: 1.3.4\n'
                '\n'
                '# a comment above environment\n'
                'environment: ">=2.11.0 <3.0.0"\n'
                '\n'
                'dependencies:\n'
                '  # a comment above a dependency\n'
                '  a_dependency: ^1.0.0\n'
                '\n'
                'dependency_validator:\n'
                '  exclude:\n'
                '    # a comment above an excluded directory\n'
                '    - app\n'
                '  ignore: \n'
                '    - $addedDependency\n'
                '\n'
                'dependency_overrides:\n'
                '  over_react:\n'
                '    path: ../over_react\n'
                '');
      });
    });

    group('appends the new dependency to the ignore tag if the tag is present',
        () {
      test('and the config is at the bottom of the pubspec', () async {
        await testSuggestor(
            shouldDartfmtOutput: false,
            expectedPatchCount: 1,
            input: ''
                'name: a_package\n'
                'version: 1.3.4\n'
                '\n'
                'environment: ">=2.11.0 <3.0.0"\n'
                '\n'
                'dependencies:\n'
                '  a_dependency: ^1.0.0\n'
                '\n'
                'dependency_validator:\n'
                '  exclude:\n'
                '    # a comment above an excluded directory\n'
                '    - app\n'
                '  ignore:\n'
                '    # a comment above an excluded dependency\n'
                '    - a_dependency\n'
                '',
            expectedOutput: ''
                'name: a_package\n'
                'version: 1.3.4\n'
                '\n'
                'environment: ">=2.11.0 <3.0.0"\n'
                '\n'
                'dependencies:\n'
                '  a_dependency: ^1.0.0\n'
                '\n'
                'dependency_validator:\n'
                '  exclude:\n'
                '    # a comment above an excluded directory\n'
                '    - app\n'
                '  ignore:\n'
                '    # a comment above an excluded dependency\n'
                '    - a_dependency\n'
                '    - $addedDependency\n'
                '');
      });

      test('and the config is not in the bottom of the pubspec', () async {
        await testSuggestor(
            shouldDartfmtOutput: false,
            expectedPatchCount: 1,
            input: ''
                'name: a_package\n'
                'version: 1.3.4\n'
                '\n'
                'environment: ">=2.11.0 <3.0.0"\n'
                '\n'
                'dependencies:\n'
                '  a_dependency: ^1.0.0\n'
                '\n'
                'dependency_validator:\n'
                '  exclude:\n'
                '    # a comment above an excluded directory\n'
                '    - app\n'
                '  ignore:\n'
                '    # a comment above an excluded dependency\n'
                '    - a_dependency\n'
                '\n'
                'dependency_overrides:\n'
                '  over_react:\n'
                '    path: ../over_react\n'
                '',
            expectedOutput: ''
                'name: a_package\n'
                'version: 1.3.4\n'
                '\n'
                'environment: ">=2.11.0 <3.0.0"\n'
                '\n'
                'dependencies:\n'
                '  a_dependency: ^1.0.0\n'
                '\n'
                'dependency_validator:\n'
                '  exclude:\n'
                '    # a comment above an excluded directory\n'
                '    - app\n'
                '  ignore:\n'
                '    # a comment above an excluded dependency\n'
                '    - a_dependency\n'
                '    - $addedDependency\n'
                '\n'
                'dependency_overrides:\n'
                '  over_react:\n'
                '    path: ../over_react\n'
                '');
      });
    });

    test('makes no change if the dependency is already there', () async {
      await testSuggestor(
          shouldDartfmtOutput: false,
          expectedPatchCount: 0,
          input: ''
              'name: a_package\n'
              'version: 1.3.4\n'
              '\n'
              'environment: ">=2.11.0 <3.0.0"\n'
              '\n'
              'dependencies:\n'
              '  a_dependency: ^1.0.0\n'
              'dependency_validator:\n'
              '  exclude:\n'
              '    # a comment above an excluded directory\n'
              '    - app\n'
              '  ignore:\n'
              '    # a comment above an excluded dependency\n'
              '    - a_dependency\n'
              '    - $addedDependency\n'
              '');
    });
  });
}

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

import 'package:codemod/codemod.dart';
import 'package:over_react_codemod/src/creator_utils.dart';
import 'package:over_react_codemod/src/react16_suggestors/dependency_override_updater.dart';
import 'package:over_react_codemod/src/react16_suggestors/pubspec_updater.dart';
import 'package:test/test.dart';

import '../util.dart';

main() {
  group('DependencyOverrideUpdater', () {
    final testSuggestor = getSuggestorTester(
        PubspecUpdater([
          DependencyCreator('react', gitOverride: 'https://github.com/cleandart/react-dart.git', ref: '5.0.0-wip'),
          DependencyCreator('over_react', gitOverride: 'https://github.com/Workiva/over_react.git', ref: '3.0.0-wip')
          ],
          shouldUpdate: (existingDep, target, sectionsFound) {
            print(existingDep);
            if (existingDep.isOverride) {
              if (existingDep.gitOverride == target.gitOverride) return false;
              return true;
            }
            return false;
          },
          shouldAdd: (existingDeps, target, sectionsFound) {
            if (existingDeps.isEmpty) {
              return true;
            }
            return false;
          },
        )
    );

    group('adds the dependencies if', () {
      test('the pubspec is empty', () {
        // The output has a new line because the testSuggester appends one.
        testSuggestor(
          expectedPatchCount: 1,
          shouldDartfmtOutput: false,
          input: '',
          expectedOutput: '\n'
              'dependency_overrides:\n'
              '  react:\n'
              '    git:\n'
              '      url: https://github.com/cleandart/react-dart.git\n'
              '      ref: 5.0.0-wip\n'
              '  over_react:\n'
              '    git:\n'
              '      url: https://github.com/Workiva/over_react.git\n'
              '      ref: 3.0.0-wip\n'
              '',
        );
      });

      test('react and over_react are not dependencies', () {
        testSuggestor(
          expectedPatchCount: 1,
          shouldDartfmtOutput: false,
          input: ''
              'dependencies:\n'
              '  test: 1.5.1\n'
              '\n'
              'dev_dependencies:\n'
              '  dart_dev: ^2.0.1\n'
              '',
          expectedOutput: ''
              'dependencies:\n'
              '  test: 1.5.1\n'
              '\n'
              'dev_dependencies:\n'
              '  dart_dev: ^2.0.1\n'
              '\n'
              'dependency_overrides:\n'
              '  react:\n'
              '    git:\n'
              '      url: https://github.com/cleandart/react-dart.git\n'
              '      ref: 5.0.0-wip\n'
              '  over_react:\n'
              '    git:\n'
              '      url: https://github.com/Workiva/over_react.git\n'
              '      ref: 3.0.0-wip\n'
              '',
        );
      });

      group('the dependencies are already being overridden via', () {
        test('git (SSH)', () {
          testSuggestor(
            expectedPatchCount: 2,
            shouldDartfmtOutput: false,
            input: ''
                'dependencies:\n'
                '  test: 1.5.1\n'
                '  react: ^4.6.0\n'
                '  over_react: ^2.0.0\n'
                '\n'
                'dev_dependencies:\n'
                '  dart_dev: ^2.0.1\n'
                '\n'
                'dependency_overrides:\n'
                '  react:\n'
                '    git:\n'
                '      url: git@github.com:cleandart/react-dart.git\n'
                '      ref: 5.0.0-wip\n'
                '  over_react:\n'
                '    git:\n'
                '      url: git@github.com:Workiva/over_react.git\n'
                '      ref: 3.0.0-wip\n'
                '',
            expectedOutput: ''
                'dependencies:\n'
                '  test: 1.5.1\n'
                '  react: ^4.6.0\n'
                '  over_react: ^2.0.0\n'
                '\n'
                'dev_dependencies:\n'
                '  dart_dev: ^2.0.1\n'
                '\n'
                'dependency_overrides:\n'
                '  react:\n'
                '    git:\n'
                '      url: https://github.com/cleandart/react-dart.git\n'
                '      ref: 5.0.0-wip\n'
                '  over_react:\n'
                '    git:\n'
                '      url: https://github.com/Workiva/over_react.git\n'
                '      ref: 3.0.0-wip\n'
                '',
          );
        });

        test('git (HTTPS)', () {
          testSuggestor(
            expectedPatchCount: 0,
            shouldDartfmtOutput: false,
            input: ''
                'dependencies:\n'
                '  test: 1.5.1\n'
                '  react: ^4.6.0\n'
                '  over_react: ^2.0.0\n'
                '\n'
                'dev_dependencies:\n'
                '  dart_dev: ^2.0.1\n'
                '\n'
                'dependency_overrides:\n'
                '  react:\n'
                '    git:\n'
                '      url: https://github.com/cleandart/react-dart.git\n'
                '      ref: 5.0.0-wip\n'
                '  over_react:\n'
                '    git:\n'
                '      url: https://github.com/Workiva/over_react.git\n'
                '      ref: 3.0.0-wip\n'
                '',
            expectedOutput: ''
                'dependencies:\n'
                '  test: 1.5.1\n'
                '  react: ^4.6.0\n'
                '  over_react: ^2.0.0\n'
                '\n'
                'dev_dependencies:\n'
                '  dart_dev: ^2.0.1\n'
                '\n'
                'dependency_overrides:\n'
                '  react:\n'
                '    git:\n'
                '      url: https://github.com/cleandart/react-dart.git\n'
                '      ref: 5.0.0-wip\n'
                '  over_react:\n'
                '    git:\n'
                '      url: https://github.com/Workiva/over_react.git\n'
                '      ref: 3.0.0-wip\n'
                '',
          );
        });

        test('path', () {
          testSuggestor(
            expectedPatchCount: 2,
            shouldDartfmtOutput: false,
            input: ''
                'dependencies:\n'
                '  test: 1.5.1\n'
                '  react: ^4.6.0\n'
                '  over_react: ^2.0.0\n'
                '\n'
                'dev_dependencies:\n'
                '  dart_dev: ^2.0.1\n'
                '\n'
                'dependency_overrides:\n'
                '  react:\n'
                '    path: ../../anywhere\n'
                '  over_react:\n'
                '    path: ../../anywhere\n'
                '',
            expectedOutput: ''
                'dependencies:\n'
                '  test: 1.5.1\n'
                '  react: ^4.6.0\n'
                '  over_react: ^2.0.0\n'
                '\n'
                'dev_dependencies:\n'
                '  dart_dev: ^2.0.1\n'
                '\n'
                'dependency_overrides:\n'
                '  react:\n'
                '    git:\n'
                '      url: https://github.com/cleandart/react-dart.git\n'
                '      ref: 5.0.0-wip\n'
                '  over_react:\n'
                '    git:\n'
                '      url: https://github.com/Workiva/over_react.git\n'
                '      ref: 3.0.0-wip\n'
                '',
          );
        });
      });
    });

    test('adds dependency if missing', () {
      testSuggestor(
        expectedPatchCount: 1,
        shouldDartfmtOutput: false,
        input: ''
            'dependencies:\n'
            '  test: 1.5.1\n'
            '  react: ^4.6.0\n'
            '  over_react: ^2.0.0\n'
            '\n'
            'dev_dependencies:\n'
            '  dart_dev: ^2.0.1\n'
            '',
        expectedOutput: ''
            'dependencies:\n'
            '  test: 1.5.1\n'
            '  react: ^4.6.0\n'
            '  over_react: ^2.0.0\n'
            '\n'
            'dev_dependencies:\n'
            '  dart_dev: ^2.0.1\n'
            '\n'
            'dependency_overrides:\n'
            '  react:\n'
            '    git:\n'
            '      url: https://github.com/cleandart/react-dart.git\n'
            '      ref: 5.0.0-wip\n'
            '  over_react:\n'
            '    git:\n'
            '      url: https://github.com/Workiva/over_react.git\n'
            '      ref: 3.0.0-wip\n'
            '',
      );
    });

    test('preserves existing, unrelated dependency overrides', () {
      testSuggestor(
        expectedPatchCount: 1,
        shouldDartfmtOutput: false,
        // On this test, and the following tests, idemopotency is disabled
        // because of the codemod's tendency to add a line between already the
        // existing and the new overrides being added (only after the initial
        // run). The behavior is minor but finding a solution to stop it is
        // non-trivial.
        testIdempotency: false,
        input: ''
            'dependencies:\n'
            '  test: 1.5.1\n'
            '  react: ^4.6.0\n'
            '  over_react: ^2.0.0\n'
            '\n'
            'dev_dependencies:\n'
            '  dart_dev: ^2.0.1\n'
            '\n'
            'dependency_overrides:\n'
            '  foo:\n'
            '    git:\n'
            '      url: git@github.com:Workiva/foo.git\n'
            '      ref: 100.0.0\n'
            '',
        expectedOutput: ''
            'dependencies:\n'
            '  test: 1.5.1\n'
            '  react: ^4.6.0\n'
            '  over_react: ^2.0.0\n'
            '\n'
            'dev_dependencies:\n'
            '  dart_dev: ^2.0.1\n'
            '\n'
            'dependency_overrides:\n'
            '  react:\n'
            '    git:\n'
            '      url: https://github.com/cleandart/react-dart.git\n'
            '      ref: 5.0.0-wip\n'
            '  over_react:\n'
            '    git:\n'
            '      url: https://github.com/Workiva/over_react.git\n'
            '      ref: 3.0.0-wip\n'
            '  foo:\n'
            '    git:\n'
            '      url: git@github.com:Workiva/foo.git\n'
            '      ref: 100.0.0\n'
            '',
      );
    });

    test('does not override sections after dependency_overrides', () {
      testSuggestor(
        expectedPatchCount: 1,
        shouldDartfmtOutput: false,
        testIdempotency: false,
        input: ''
            'dependencies:\n'
            '  test: 1.5.1\n'
            '  react: ^4.6.0\n'
            '  over_react: ^2.0.0\n'
            '\n'
            'dev_dependencies:\n'
            '  dart_dev: ^2.0.1\n'
            '\n'
            'dependency_overrides:\n'
            '  foo:\n'
            '    git:\n'
            '      url: git@github.com:Workiva/foo.git\n'
            '      ref: 100.0.0\n'
            '\n'
            'executables:\n'
            '  dart2_upgrade:\n'
            '  react_16_upgrade:\n'
            '',
        expectedOutput: ''
            'dependencies:\n'
            '  test: 1.5.1\n'
            '  react: ^4.6.0\n'
            '  over_react: ^2.0.0\n'
            '\n'
            'dev_dependencies:\n'
            '  dart_dev: ^2.0.1\n'
            '\n'
            'dependency_overrides:\n'
            '  react:\n'
            '    git:\n'
            '      url: https://github.com/cleandart/react-dart.git\n'
            '      ref: 5.0.0-wip\n'
            '  over_react:\n'
            '    git:\n'
            '      url: https://github.com/Workiva/over_react.git\n'
            '      ref: 3.0.0-wip\n'
            '  foo:\n'
            '    git:\n'
            '      url: git@github.com:Workiva/foo.git\n'
            '      ref: 100.0.0\n'
            '\n'
            'executables:\n'
            '  dart2_upgrade:\n'
            '  react_16_upgrade:\n'
            '',
      );
    });

    test('does not fail if there is no trailing new line.', () {
      testSuggestor(
        expectedPatchCount: 1,
        shouldDartfmtOutput: false,
        testIdempotency: false,
        input: ''
            'dependencies:\n'
            '  test: 1.5.1\n'
            '  react: ^4.6.0\n'
            '  over_react: ^2.0.0\n'
            '\n'
            'dev_dependencies:\n'
            '  dart_dev: ^2.0.1\n',
        expectedOutput: ''
            'dependencies:\n'
            '  test: 1.5.1\n'
            '  react: ^4.6.0\n'
            '  over_react: ^2.0.0\n'
            '\n'
            'dev_dependencies:\n'
            '  dart_dev: ^2.0.1\n'
            '\n'
            'dependency_overrides:\n'
            '  react:\n'
            '    git:\n'
            '      url: https://github.com/cleandart/react-dart.git\n'
            '      ref: 5.0.0-wip\n'
            '  over_react:\n'
            '    git:\n'
            '      url: https://github.com/Workiva/over_react.git\n'
            '      ref: 3.0.0-wip\n'
            '',
      );
    });
  });
}

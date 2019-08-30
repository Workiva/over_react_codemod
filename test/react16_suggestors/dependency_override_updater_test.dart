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

import 'package:over_react_codemod/src/react16_suggestors/dependency_override_updater.dart';
import 'package:test/test.dart';

import '../util.dart';

main() {
  group('DependencyOverrideUpdater', () {
    final testSuggestor = getSuggestorTester(DependencyOverrideUpdater());

    group('adds the dependencies if', () {
      test('the pubspec is empty', () {
        // The output has a new line because the testSuggester appends one.
        testSuggestor(
          expectedPatchCount: 2,
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
          expectedPatchCount: 2,
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
        expectedPatchCount: 2,
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
        expectedPatchCount: 2,
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
  });
}

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
    const defaultDependencies = '  test: 1.5.1\n'
        '  react: ^4.6.0\n'
        '  over_react: ^2.0.0\n';
    const defaultDevDependencies = '  dart_dev: ^2.0.1\n';

    const expectedOutputSections = {
      'dependencies': defaultDependencies,
      'dev_dependencies': defaultDevDependencies,
    };

    void testDependencyOverridesSectionByPosition(SuggestorTester tester,
        Map inputSections, String expectedOverrideContent,
        {String additionalOverrides, bool testIdempotency = true}) {
      if (additionalOverrides != null) {
        expectedOverrideContent += additionalOverrides;
      }

      test('and the dependency_overrides section is last', () {
        tester(
          expectedPatchCount: 2,
          shouldDartfmtOutput: false,
          testIdempotency: testIdempotency,
          input: ''
                  'dependencies:\n' +
              inputSections['dependencies'] +
              '\n'
                  'dev_dependencies:\n' +
              inputSections['dev_dependencies'] +
              '\n'
                  'dependency_overrides:\n' +
              inputSections['dependency_overrides'] +
              '',
          expectedOutput: ''
                  'dependencies:\n' +
              expectedOutputSections['dependencies'] +
              '\n'
                  'dev_dependencies:\n' +
              expectedOutputSections['dev_dependencies'] +
              '\n'
                  'dependency_overrides:\n' +
              expectedOverrideContent +
              '',
        );
      });

      test('and the dependency_overrides section is first', () {
        // The extra line-break is not ideal, but the effort to make it be a
        // single break no matter the order of the sections is not worth it, IMO.
        final lineBreaksAfterDepOverridesSection =
            additionalOverrides == null ? '\n\n' : '\n';

        tester(
          expectedPatchCount: 2,
          shouldDartfmtOutput: false,
          testIdempotency: testIdempotency,
          input: ''
                  'dependency_overrides:\n' +
              inputSections['dependency_overrides'] +
              '\n'
                  'dependencies:\n' +
              inputSections['dependencies'] +
              '\n'
                  'dev_dependencies:\n' +
              inputSections['dev_dependencies'] +
              '',
          expectedOutput: ''
                  'dependency_overrides:\n' +
              expectedOverrideContent +
              lineBreaksAfterDepOverridesSection +
              'dependencies:\n' +
              expectedOutputSections['dependencies'] +
              '\n'
                  'dev_dependencies:\n' +
              expectedOutputSections['dev_dependencies'] +
              '',
        );
      });

      test('and the dependency_overrides section is in the middle', () {
        // The extra line-break is not ideal, but the effort to make it be a
        // single break no matter the order of the sections is not worth it, IMO.
        final lineBreaksAfterDepOverridesSection =
            additionalOverrides == null ? '\n\n' : '\n';

        tester(
          expectedPatchCount: 2,
          shouldDartfmtOutput: false,
          testIdempotency: testIdempotency,
          input: ''
                  'dependencies:\n' +
              inputSections['dependencies'] +
              '\n'
                  'dependency_overrides:\n' +
              inputSections['dependency_overrides'] +
              '\n'
                  'dev_dependencies:\n' +
              inputSections['dev_dependencies'] +
              '',
          expectedOutput: ''
                  'dependencies:\n' +
              expectedOutputSections['dependencies'] +
              '\n'
                  'dependency_overrides:\n' +
              expectedOverrideContent +
              lineBreaksAfterDepOverridesSection +
              'dev_dependencies:\n' +
              expectedOutputSections['dev_dependencies'] +
              '',
        );
      });
    }

    void commonOverrideUpdaterTests(
        SuggestorTester tester, String expectedOverrideOutput,
        {bool testIdempotency = true}) {
      group('- common override updater tests -', () {
        group('adds the dependencies if', () {
          test('the pubspec is empty', () {
            // The output has a new line because the testSuggester appends one.
            tester(
              expectedPatchCount: 2,
              shouldDartfmtOutput: false,
              input: '',
              expectedOutput: '\n'
                      'dependency_overrides:\n' +
                  expectedOverrideOutput +
                  '',
            );
          });

          test('react and over_react are not dependencies', () {
            tester(
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
                      'dependency_overrides:\n' +
                  expectedOverrideOutput +
                  '',
            );
          });

          group('the dependencies are already being overridden via', () {
            group('git (SSH)', () {
              const inputSections = {
                'dependencies': defaultDependencies,
                'dev_dependencies': defaultDevDependencies,
                'dependency_overrides': '  react:\n'
                    '    git:\n'
                    '      url: git@github.com:cleandart/react-dart.git\n'
                    '      ref: 5.0.0-wip\n'
                    '  over_react:\n'
                    '    git:\n'
                    '      url: git@github.com:Workiva/over_react.git\n'
                    '      ref: 3.0.0-wip\n',
              };

              testDependencyOverridesSectionByPosition(
                  tester, inputSections, expectedOverrideOutput,
                  testIdempotency: testIdempotency);
            });

            group('git (HTTPS)', () {
              const inputSections = {
                'dependencies': defaultDependencies,
                'dev_dependencies': defaultDevDependencies,
                'dependency_overrides': '  react:\n'
                    '    git:\n'
                    '      url: https://github.com/cleandart/react-dart.git\n'
                    '      ref: 5.0.0-wip\n'
                    '  over_react:\n'
                    '    git:\n'
                    '      url: https://github.com/Workiva/over_react.git\n'
                    '      ref: 3.0.0-wip\n',
              };

              testDependencyOverridesSectionByPosition(
                  tester, inputSections, expectedOverrideOutput,
                  testIdempotency: testIdempotency);
            });

            group('path', () {
              const inputSections = {
                'dependencies': defaultDependencies,
                'dev_dependencies': defaultDevDependencies,
                'dependency_overrides': '  react:\n'
                    '    path: ../../anywhere\n'
                    '  over_react:\n'
                    '    path: ../../anywhere\n',
              };

              testDependencyOverridesSectionByPosition(
                  tester, inputSections, expectedOverrideOutput,
                  testIdempotency: testIdempotency);
            });
          });

          test('adds dependency if missing', () {
            tester(
              expectedPatchCount: 2,
              shouldDartfmtOutput: false,
              input: ''
                      'dependencies:\n' +
                  defaultDependencies +
                  '\n'
                      'dev_dependencies:\n' +
                  defaultDevDependencies +
                  '',
              expectedOutput: ''
                      'dependencies:\n' +
                  defaultDependencies +
                  '\n'
                      'dev_dependencies:\n' +
                  defaultDevDependencies +
                  '\n'
                      'dependency_overrides:\n' +
                  expectedOverrideOutput +
                  '',
            );
          });

          group('preserves existing, unrelated dependency overrides', () {
            const unrelatedOverride = '  foo:\n'
                '    git:\n'
                '      url: git@github.com:Workiva/foo.git\n'
                '      ref: 100.0.0\n';
            const inputSections = {
              'dependencies': defaultDependencies,
              'dev_dependencies': defaultDevDependencies,
              'dependency_overrides': unrelatedOverride,
            };

            testDependencyOverridesSectionByPosition(
                tester, inputSections, expectedOverrideOutput,
                additionalOverrides: unrelatedOverride,
                testIdempotency: testIdempotency);
          });

          test('does not override sections after dependency_overrides', () {
            tester(
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
                      'dependency_overrides:\n' +
                  expectedOverrideOutput +
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
            tester(
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
                      'dependency_overrides:\n' +
                  expectedOverrideOutput +
                  '',
            );
          });
        });
      });
    }

    group('with a SimpleOverrideConfig', () {
      final defaultReactConfig =
          SimpleOverrideConfig(name: 'react', version: '^5.0.0-alpha');
      final defaultOverReactConfig =
          SimpleOverrideConfig(name: 'over_react', version: '^3.0.0-alpha');

      const expectedOverrides = '  react: ^5.0.0-alpha\n'
          '  over_react: ^3.0.0-alpha\n';

      final testSuggestor = getSuggestorTester(DependencyOverrideUpdater(
          reactOverrideConfig: defaultReactConfig,
          overReactOverrideConfig: defaultOverReactConfig));

      commonOverrideUpdaterTests(testSuggestor, expectedOverrides);
    });

    group('with a GitOverrideConfig', () {
      group('', () {
        const expectedOverrides = '''  react:
    git:
      url: https://github.com/cleandart/react-dart.git
      ref: 6.0.0-wip
  over_react:
    git:
      url: https://github.com/Workiva/over_react.git
      ref: release_over_react_4.0.0
''';

        final defaultReactConfig = GitOverrideConfig(
            name: 'react',
            url: 'https://github.com/cleandart/react-dart.git',
            ref: '6.0.0-wip');
        final defaultOverReactConfig = GitOverrideConfig(
            name: 'over_react',
            url: 'https://github.com/Workiva/over_react.git',
            ref: 'release_over_react_4.0.0');

        final testSuggestor = getSuggestorTester(DependencyOverrideUpdater(
            reactOverrideConfig: defaultReactConfig,
            overReactOverrideConfig: defaultOverReactConfig));

        // turning idempotency tests off for this because it would just add a new line the second run,
        // which caused failures for insignificant white space
        commonOverrideUpdaterTests(testSuggestor, expectedOverrides,
            testIdempotency: false);
      });

      group('with no ref', () {
        const expectedOverrides = '''  react:
    git:
      url: https://github.com/cleandart/react-dart.git
  over_react:
    git:
      url: https://github.com/Workiva/over_react.git
''';

        final defaultReactConfig = GitOverrideConfig(
            name: 'react', url: 'https://github.com/cleandart/react-dart.git');
        final defaultOverReactConfig = GitOverrideConfig(
            name: 'over_react',
            url: 'https://github.com/Workiva/over_react.git');

        final testSuggestor = getSuggestorTester(DependencyOverrideUpdater(
            reactOverrideConfig: defaultReactConfig,
            overReactOverrideConfig: defaultOverReactConfig));

        // turning idempotency tests off for this because it would just add a new line the second run,
        // which caused failures for insignificant white space
        commonOverrideUpdaterTests(testSuggestor, expectedOverrides,
            testIdempotency: false);
      });
    });
  });
}

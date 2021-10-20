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

import 'package:over_react_codemod/src/dependency_validator_suggestors/ignore_updaters/v1_updater.dart';
import 'package:test/test.dart';

import '../../util.dart';

const depValidatorCommand = 'dart run dependency_validator

Map<String, String Function(String command)> contexts = {
  'basic-dockerfile': basicDockerFile,
  'chained-docker-command': chainedDockerfileCommand,
  'dart-command': dartCommand,
  'dart-dev-task': dartDevTask,
  'yaml-script': yamlScript,
  'yaml-ci-workflow': yamlCiWorkflow,
  'yaml-skynet': yamlSkynet,
};

main() {
  group('V1DependencyUpdater', () {
    const addedDependency = 'an_added_dependency';
    final testSuggestor =
        getSuggestorTester(V1DependencyValidatorUpdater(addedDependency));

    void sharedCommandTests(String contextName,
        String Function(String command) getCommandWithinContext) {
      group(contextName, () {
        test('makes no updates when there is no command', () async {
          await testSuggestor(
            shouldDartfmtOutput: false,
            expectedPatchCount: 0,
            input: getCommandWithinContext('dart format .'),
            expectedOutput: getCommandWithinContext('dart format .'),
          );
        });

        group('adds the dependency when', () {
          test('there are no other args on the command', () async {
            await testSuggestor(
                shouldDartfmtOutput: false,
                expectedPatchCount: 1,
                input: getCommandWithinContext(depValidatorCommand),
                expectedOutput: getCommandWithinContext(
                    '$depValidatorCommand -i $addedDependency'));
          });

          test('the exclude flag is present', () async {
            await testSuggestor(
              shouldDartfmtOutput: false,
              expectedPatchCount: 1,
              input: getCommandWithinContext(
                  '$depValidatorCommand -x app/,bin/,random/'),
              expectedOutput: getCommandWithinContext(
                  '$depValidatorCommand -i $addedDependency -x app/,bin/,random/'),
            );
          });

          test('there are multiple other args present', () async {
            await testSuggestor(
              shouldDartfmtOutput: false,
              expectedPatchCount: 1,
              input: getCommandWithinContext(
                  '$depValidatorCommand --no-fatal-unused -x app/,bin/,random/ --no-fatal-missing'),
              expectedOutput: getCommandWithinContext(
                  '$depValidatorCommand -i $addedDependency --no-fatal-unused -x app/,bin/,random/ --no-fatal-missing'),
            );
          });

          group('there is already an ignore arg', () {
            test('using `-i`', () async {
              await testSuggestor(
                shouldDartfmtOutput: false,
                expectedPatchCount: 1,
                input: getCommandWithinContext(
                    '$depValidatorCommand -i over_react'),
                expectedOutput: getCommandWithinContext(
                    '$depValidatorCommand -i over_react,$addedDependency'),
              );
            });

            test('using `-i with no space`', () async {
              await testSuggestor(
                shouldDartfmtOutput: false,
                expectedPatchCount: 1,
                input: getCommandWithinContext(
                    '$depValidatorCommand -iover_react'),
                expectedOutput: getCommandWithinContext(
                    '$depValidatorCommand -iover_react,$addedDependency'),
              );
            });

            test('using `--ignore`', () async {
              await testSuggestor(
                shouldDartfmtOutput: false,
                expectedPatchCount: 1,
                input: getCommandWithinContext(
                    '$depValidatorCommand --ignore over_react'),
                expectedOutput: getCommandWithinContext(
                    '$depValidatorCommand --ignore over_react,$addedDependency'),
              );
            });

            test('using `--ignore=`', () async {
              await testSuggestor(
                shouldDartfmtOutput: false,
                expectedPatchCount: 1,
                input: getCommandWithinContext(
                    '$depValidatorCommand --ignore=over_react'),
                expectedOutput: getCommandWithinContext(
                    '$depValidatorCommand --ignore=over_react,$addedDependency'),
              );
            });

            test('when there happens to be a trailing comma', () async {
              await testSuggestor(
                shouldDartfmtOutput: false,
                expectedPatchCount: 1,
                input: getCommandWithinContext(
                    '$depValidatorCommand -i over_react,'),
                expectedOutput: getCommandWithinContext(
                    '$depValidatorCommand -i over_react,$addedDependency'),
              );
            });

            test('when there are args after the ignore arg', () async {
              await testSuggestor(
                shouldDartfmtOutput: false,
                expectedPatchCount: 1,
                input: getCommandWithinContext(
                    '$depValidatorCommand -i over_react -x app/,bin/,random/ --no-fatal-missing'),
                expectedOutput: getCommandWithinContext(
                    '$depValidatorCommand -i over_react,$addedDependency -x app/,bin/,random/ --no-fatal-missing'),
              );
            });

            test('when there are args before the ignore arg', () async {
              await testSuggestor(
                shouldDartfmtOutput: false,
                expectedPatchCount: 1,
                input: getCommandWithinContext(
                    '$depValidatorCommand -x app/,bin/,random/ --no-fatal-missing -i over_react'),
                expectedOutput: getCommandWithinContext(
                    '$depValidatorCommand -x app/,bin/,random/ --no-fatal-missing -i over_react,$addedDependency'),
              );
            });

            test('when there are args on both sides of the ignore arg',
                () async {
              await testSuggestor(
                shouldDartfmtOutput: false,
                expectedPatchCount: 1,
                input: getCommandWithinContext(
                    '$depValidatorCommand -x app/,bin/,random/ -i over_react --no-fatal-missing'),
                expectedOutput: getCommandWithinContext(
                    '$depValidatorCommand -x app/,bin/,random/ -i over_react,$addedDependency --no-fatal-missing'),
              );
            });

            test(
                'when the dependency name is part of an existing ignore dependency',
                () async {
              await testSuggestor(
                shouldDartfmtOutput: false,
                expectedPatchCount: 1,
                input: getCommandWithinContext(
                    '$depValidatorCommand -i ${addedDependency}_plus_more'),
                expectedOutput: getCommandWithinContext(
                    '$depValidatorCommand -i ${addedDependency}_plus_more,$addedDependency'),
              );
            });
          });
        });
      });
    }

    group('within the context', () {
      contexts.forEach(sharedCommandTests);
    });

    test('adds to all locations within a file', () async {
      final getCommandWithinContext = contexts['basic-dockerfile'];
      await testSuggestor(
          shouldDartfmtOutput: false,
          expectedPatchCount: 2,
          input: getCommandWithinContext!(
              '$depValidatorCommand\n$depValidatorCommand'),
          expectedOutput: getCommandWithinContext(
              '$depValidatorCommand -i $addedDependency\n$depValidatorCommand -i $addedDependency'));
    });

    test('Adds a fixme if there are two ignore flags', () async {
      await testSuggestor(
          shouldDartfmtOutput: false,
          expectedPatchCount: 1,
          input: '''
RUN pub get
RUN $depValidatorCommand -i over_react -x app/ -i over_react
RUN dart format -l 80 --set-exit-if-changed lib/ test/
RUN dart analyze --fatal-infos --fatal-warnings lib
''',
          expectedOutput: '''
RUN pub get
//FIXME: unexpected outcome; there should only be one ignore argument
RUN $depValidatorCommand -i over_react -x app/ -i over_react
RUN dart format -l 80 --set-exit-if-changed lib/ test/
RUN dart analyze --fatal-infos --fatal-warnings lib
''');
    });
  });
}

String basicDockerFile(String command) => '''
RUN pub get
RUN $command
RUN dart format -l 80 --set-exit-if-changed lib/ test/
RUN dart analyze --fatal-infos --fatal-warnings lib
''';

String chainedDockerfileCommand(String command) => '''
RUN pub get && \\
        $command && \\
        pub run dart_dev analyze
''';

String dartCommand(String command) => '''
await Future.wait([
    run('$command',
        workingDirectory: analyzeDir),
    run('pub run dart_dev format --check', workingDirectory: analyzeDir),
  ]);
''';

String dartDevTask(String command) => '''
import 'package:dart_dev/dart_dev.dart'
    show dev, config, Environment, TestRunnerConfig;

main(List<String> args) async {
  var directories = ['bin/', 'lib/', 'tool/', 'test/'];

  config.analyze.entryPoints = directories;

  config.format
    ..paths = directories
    ..exclude = ['test/generated_unit_test_runner.dart'];

  config.genTestRunner.configs = [
    new TestRunnerConfig(
        env: Environment.vm, filename: 'generated_unit_test_runner'),
  ];

  config.test
    ..functionalTests = ['test/functional/test_packages.dart']
    ..unitTests = ['test/generated_unit_test_runner.dart'];

  config.taskRunner.tasksToRun = [
    '$command',
    'pub run abide',
    'pub run dart_dev analyze',
    'pub run dart_dev format --check',
  ];

  await dev(args);
}
''';

String yamlScript(String command) => '''
language: dart

dart:
  - 1.24.3
  - stable

script:
  - pub get
  - dartfmt --set-exit-if-changed --dry-run lib bin test tool
  - $command
  - dartanalyzer bin lib test
  - pub run test --concurrency=4 -p vm --reporter=expanded test/vm/
''';

String yamlCiWorkflow(String command) => '''
name: Dart CI

on:
  push:
    branches:
      - 'master'
      - 'test_consume_*'
  pull_request:
    branches:
      - '*'

jobs:
  build:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        sdk: [ 2.7.2, 2.13.4, stable, dev ]
    steps:
      - uses: actions/checkout@v2
      - uses: dart-lang/setup-dart@v0.2
    
      - name: Validate dependencies
        run: $command
        if: always() && steps.install.outcome == 'success'
''';

String yamlSkynet(String command) => '''
---
# TODO: Remove this plan once the core checks cause failures.
name: code_quality_analysis
description: Run code quality checks that will cause failures since the built-in core checks do not do so yet.

image: drydock.workiva.net/workiva/dart_unit_test_image:1
size: large
timeout: 600
scripts:
  - pub get
  - $command
  - pub global activate tuneup

---
''';

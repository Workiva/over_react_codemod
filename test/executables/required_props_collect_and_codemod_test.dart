// Copyright 2024 Workiva Inc.
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

import 'dart:convert';
import 'dart:io';

import 'package:async/async.dart';
import 'package:meta/meta.dart';
import 'package:over_react_codemod/src/util/command.dart';
import 'package:over_react_codemod/src/util/package_util.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

// Change this to `true` and all of the functional tests in this file will print
// the stdout/stderr of the codemod processes.
final _debug = false;

void main() {
  group(
      'null_safety_required_props collect and codemod command, end-to-end behavior:',
      () {
    final requiredPropsScript = p.join(
        findPackageRootFor(p.current), 'bin/null_safety_required_props.dart');

    const name = 'test_package';
    late d.DirectoryDescriptor projectDir;
    late String dataFilePath;

    setUpAll(() async {
      print('setUpAll: Collecting data...');
      final tmpDir =
          Directory.systemTemp.createTempSync('required_props_codemod_test');
      dataFilePath = p.join(tmpDir.path, 'prop_requiredness.json');
      await runCommandAndThrowIfFailed('dart', [
        requiredPropsScript,
        'collect',
        '--output',
        dataFilePath,
        p.join(findPackageRootFor(p.current),
            'test/test_fixtures/required_props/test_consuming_package'),
      ]);
      expect(File(dataFilePath).existsSync(), isTrue);
      print('setUpAll: Done.');
    });

    setUp(() async {
      projectDir = d.DirectoryDescriptor.fromFilesystem(
          name,
          p.join(findPackageRootFor(p.current),
              'test/test_fixtures/required_props/test_package'));
      await projectDir.create();
    });

    const noDataTodoComment =
        r"// TODO(orcm.required_props): No data for prop; either it's never set, all places it was set were on dynamic usages, or requiredness data was collected on a version before this prop was added.";

    test('adds hints as expected in different cases', () async {
      await testCodemod(
        script: requiredPropsScript,
        args: [
          'codemod',
          '--prop-requiredness-data',
          dataFilePath,
          '--yes-to-all',
        ],
        input: projectDir,
        expectedOutput: d.dir(projectDir.name, [
          d.dir('lib', [
            d.dir('src', [
              d.file('test_private.dart', contains('''
mixin TestPrivateProps on UiProps {
  /*late*/ String set100percent;
  String/*?*/ set80percent;
  String/*?*/ set20percent;
  $noDataTodoComment
  String/*?*/ set0percent;
}''')),
              d.file('test_class_component_defaults.dart', contains('''
mixin TestPrivatePropsMixin on UiProps {
  String/*?*/ notDefaultedOptional;
  /*late*/ String notDefaultedAlwaysSet;
  /*late*/ String/*?*/ defaultedNullable;
  /*late*/ num/*!*/ defaultedNonNullable;
}

mixin SomeOtherPropsMixin on UiProps {
  /*late*/ num/*!*/ anotherDefaultedNonNullable;
}''')),
              d.file('test_class_component_defaults.dart', contains('''
mixin TestPublic2PropsMixin on UiProps {
  String/*?*/ notDefaultedOptional;
  /*late*/ String notDefaultedAlwaysSet;
  String/*?*/ defaultedNullable;
  num/*?*/ defaultedNonNullable;
}''')),
              d.file('test_private_dynamic.dart', contains('''
// TODO(orcm.required_props): This codemod couldn't reliably determine requiredness for these props
//  because 75% of usages of components with these props (> max allowed 20% for private props)
//  either contained forwarded props or were otherwise too dynamic to analyze.
//  It may be possible to upgrade some from optional to required, with some manual inspection and testing.
mixin TestPrivateDynamicProps on UiProps {
  String/*?*/ set100percent;
}''')),
              d.file('test_private_existing_hints.dart', contains('''
mixin TestPrivateExistingHintsProps on UiProps {
  /*late*/ String set100percentWithoutHint;
  /*late*/ String set100percent;
  String/*?*/ set80percent;
  String/*?*/ set0percent;
}''')),
            ]),
          ]),
        ]),
      );
    });

    group('makes props with required over_react annotations late', () {
      test('by default', () async {
        await testCodemod(
          script: requiredPropsScript,
          args: [
            'codemod',
            '--prop-requiredness-data',
            dataFilePath,
            '--yes-to-all',
          ],
          input: projectDir,
          expectedOutput: d.dir(projectDir.name, [
            d.dir('lib', [
              d.dir('src', [
                // Note that there's no to-do comment on annotatedRequiredPropSet0Percent
                // since we short-circuit the logic that inserts it when trusting the annotation.
                d.file('test_required_annotations.dart', contains('''
mixin TestRequiredAnnotationsProps on UiProps {
  /*late*/ String annotatedRequiredProp;
  /*late*/ String annotatedNullableRequiredProp;

  /*late*/ String annotatedRequiredPropSet50Percent;
  /*late*/ String annotatedRequiredPropSet0Percent;

  /// Doc comment
  /*late*/ String annotatedRequiredPropWithDocComment;
}''')),
              ]),
            ]),
          ]),
        );
      });

      test('unless consumers pass --no-trust-required-annotation', () async {
        await testCodemod(
          script: requiredPropsScript,
          args: [
            'codemod',
            '--prop-requiredness-data',
            dataFilePath,
            '--no-trust-required-annotations',
            '--yes-to-all',
          ],
          input: projectDir,
          expectedOutput: d.dir(projectDir.name, [
            d.dir('lib', [
              d.dir('src', [
                d.file('test_required_annotations.dart', contains('''
mixin TestRequiredAnnotationsProps on UiProps {
  /*late*/ String annotatedRequiredProp;
  /*late*/ String annotatedNullableRequiredProp;

  String/*?*/ annotatedRequiredPropSet50Percent;
  $noDataTodoComment
  String/*?*/ annotatedRequiredPropSet0Percent;

  /// Doc comment
  /*late*/ String annotatedRequiredPropWithDocComment;
}''')),
              ]),
            ]),
          ]),
        );
      });
    });

    test('allows customizing requiredness thresholds via command line options',
        () async {
      await testCodemod(
        script: requiredPropsScript,
        args: [
          'codemod',
          '--prop-requiredness-data',
          dataFilePath,
          '--private-requiredness-threshold=0.1',
          '--public-requiredness-threshold=0.7',
          '--yes-to-all',
        ],
        input: projectDir,
        expectedOutput: d.dir(projectDir.name, [
          d.dir('lib', [
            d.dir('src', [
              d.file('test_private.dart', contains('''
mixin TestPrivateProps on UiProps {
  /*late*/ String set100percent;
  /*late*/ String set80percent;
  /*late*/ String set20percent;
  $noDataTodoComment
  String/*?*/ set0percent;
}''')),
              d.file('test_public_multiple_components.dart', contains('''
mixin TestPublicUsedByMultipleComponentsProps on UiProps {
  /*late*/ String set100percent;
  /*late*/ String set80percent;
  String/*?*/ set20percent;
  $noDataTodoComment
  String/*?*/ set0percent;
}'''))
            ]),
          ]),
        ]),
      );
    });

    group('allows customizing skip thresholds via command line options', () {
      // Don't test both private and public above/below the threshold,
      // so that tests ensure the private/public numbers don't get mixed up somewhere along the way.
      test('private props below threshold, public above', () async {
        await testCodemod(
          script: requiredPropsScript,
          args: [
            'codemod',
            '--prop-requiredness-data',
            dataFilePath,
            '--private-max-allowed-skip-rate=0.12',
            '--public-max-allowed-skip-rate=0.9',
            '--yes-to-all',
          ],
          input: projectDir,
          expectedOutput: d.dir(projectDir.name, [
            d.dir('lib', [
              d.dir('src', [
                d.file('test_private_dynamic.dart', contains('''
// TODO(orcm.required_props): This codemod couldn't reliably determine requiredness for these props
//  because 75% of usages of components with these props (> max allowed 12% for private props)
//  either contained forwarded props or were otherwise too dynamic to analyze.
//  It may be possible to upgrade some from optional to required, with some manual inspection and testing.
mixin TestPrivateDynamicProps on UiProps {
  String/*?*/ set100percent;
}''')),
                d.file('test_public_dynamic.dart', contains('''
mixin TestPublicDynamicProps on UiProps {
  /*late*/ String set100percent;
}'''))
              ]),
            ]),
          ]),
        );
      });

      test('private props below threshold, public above', () async {
        await testCodemod(
          script: requiredPropsScript,
          args: [
            'codemod',
            '--prop-requiredness-data',
            dataFilePath,
            '--private-max-allowed-skip-rate=0.9',
            '--public-max-allowed-skip-rate=0.34',
            '--yes-to-all',
          ],
          input: projectDir,
          expectedOutput: d.dir(projectDir.name, [
            d.dir('lib', [
              d.dir('src', [
                d.file('test_private_dynamic.dart', contains('''
mixin TestPrivateDynamicProps on UiProps {
  /*late*/ String set100percent;
}''')),
                d.file('test_public_dynamic.dart', contains('''
// TODO(orcm.required_props): This codemod couldn't reliably determine requiredness for these props
//  because 80% of usages of components with these props (> max allowed 34% for public props)
//  either contained forwarded props or were otherwise too dynamic to analyze.
//  It may be possible to upgrade some from optional to required, with some manual inspection and testing.
mixin TestPublicDynamicProps on UiProps {
  String/*?*/ set100percent;
}'''))
              ]),
            ]),
          ]),
        );
      });
    });
  }, timeout: Timeout(Duration(minutes: 2)));
}

// Adapted from `testCodemod` in https://github.com/Workiva/dart_codemod/blob/c5d245308554b0e1e7a15a54fbd2c79a9231e2be/test/functional/run_interactive_codemod_test.dart#L39
// Intentionally does not run `pub get` on the project.
@isTest
Future<Null> testCodemod({
  required String script,
  required d.DirectoryDescriptor input,
  d.DirectoryDescriptor? expectedOutput,
  List<String>? args,
  void Function(String out, String err)? body,
  int? expectedExitCode,
  List<String>? stdinLines,
}) async {
  final projectDir = input;

  final processArgs = [
    script,
    ...?args,
  ];
  if (_debug) {
    processArgs.add('--verbose');
  }
  final process = await Process.start('dart', processArgs,
      workingDirectory: projectDir.io.path);

  // If _debug, split these single-subscription streams into two
  // so that we can display the output as it comes in.
  final stdoutStreams = StreamSplitter.splitFrom(
      process.stdout.transform(utf8.decoder), _debug ? 2 : 1);
  final stderrStreams = StreamSplitter.splitFrom(
      process.stderr.transform(utf8.decoder), _debug ? 2 : 1);
  if (_debug) {
    stdoutStreams[1]
        .transform(LineSplitter())
        .forEach((line) => print('STDOUT: $line'));
    stderrStreams[1]
        .transform(LineSplitter())
        .forEach((line) => print('STDERR: $line'));
  }

  stdinLines?.forEach(process.stdin.writeln);
  final codemodExitCode = await process.exitCode;
  expectedExitCode ??= 0;

  final codemodStdout = await stdoutStreams[0].join();
  final codemodStderr = await stderrStreams[0].join();

  expect(codemodExitCode, expectedExitCode,
      reason: 'Expected codemod to exit with code $expectedExitCode, but '
          'it exited with $codemodExitCode.\n'
          'Process stderr:\n$codemodStderr');

  if (expectedOutput != null) {
    // Expect that the modified projet matches the gold files.
    await expectedOutput.validate();
  }

  if (body != null) {
    body(codemodStdout, codemodStderr);
  }
}

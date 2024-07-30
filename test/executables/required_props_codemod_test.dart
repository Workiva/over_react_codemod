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
  group('required_props data collection and codemod end-to-end behavior:', () {
    final requiredPropsScript = p.join(
        findPackageRootFor(p.current), 'bin/null_safety_required_props.dart');

    const name = 'test_package';
    late d.DirectoryDescriptor projectDir;
    late String dataFilePath;

    setUp(() async {
      projectDir = d.DirectoryDescriptor.fromFilesystem(
          name,
          p.join(findPackageRootFor(p.current),
              'test/test_fixtures/required_props/test_package'));

      await projectDir.create();

      final tmpDir =
          Directory.systemTemp.createTempSync('required_props_codemod_test');
      dataFilePath = p.join(tmpDir.path, 'prop_requiredness.json');

      // TODO perhaps just run on original package dir?
      await runCommandAndThrowIfFailed('dart', [
        requiredPropsScript,
        'collect',
        '--output',
        dataFilePath,
        projectDir.io.path
      ]);
    });

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
              d.file('test_private.dart', contains(r'''
mixin TestPrivateProps on UiProps {
  /*late*/ String set100percent;
  String/*?*/ set80percent;
  String/*?*/ set20percent;
  // TODO(orcm.required_props): No data for prop; either it's never set, all places it was set were on dynamic usages, or requiredness data was collected on a version before this prop was added.
  String/*?*/ set0percent;

  /*late*/ String annotatedRequiredProp;
  /*late*/ String annotatedNullableRequiredProp;
}''')),
            ]),
          ]),
        ]),
      );
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

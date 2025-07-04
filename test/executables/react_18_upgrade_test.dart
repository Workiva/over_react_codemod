// Copyright 2025 Workiva Inc.
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
import 'package:codemod/src/run_interactive_codemod.dart' show codemodArgParser;
import 'package:meta/meta.dart';
import 'package:over_react_codemod/src/util/package_util.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

// Change this to `true` and all of the functional tests in this file will print
// the stdout/stderr of the codemod processes.
final _debug = false;

void main() {
  group('react_18_upgrade executable', () {
    final react18CodemodScript =
    p.join(findPackageRootFor(p.current), 'bin/react_18_upgrade.dart');

    testCodemod(
        'applies all patches via --yes-to-all,'
            'and also correctly runs `pub get` if needed, migrates components,'
            ' adds MUI imports, and removes WSD imports all in a single run',
        script: react18CodemodScript,
        input: inputFiles(),
        expectedOutput: expectedOutputFiles(),
        args: ['--yes-to-all']);

    testCodemod('--fail-on-changes exits with 0 when no changes needed',
        script: react18CodemodScript,
        input: expectedOutputFiles(),
        expectedOutput: expectedOutputFiles(),
        args: ['--fail-on-changes'], body: (out, err) {
          expect(out, contains('No changes needed.'));
        });
  });
}

d.DirectoryDescriptor inputFiles(
    {Iterable<d.Descriptor> additionalFilesInLib = const []}) =>
    d.dir('project', [
      // todo add link versions
      d.file('dev.html', /*language=html*/ '''
<script src="packages/react/react.js"></script>
        <script src="packages/react/react_dom.js"></script>'''),
      d.file('dev_with_addons.html', /*language=html*/ '''
<script src="packages/react/react_with_addons.js"></script>
        <script src="packages/react/react_dom.js"></script>'''),
      d.file('prod.html', /*language=html*/ '''
<script src="packages/react/react_prod.js"></script>
        <script src="packages/react/react_dom_prod.js"></script>'''),
      d.file('prod_with_addons.html', /*language=html*/ '''
<script src="packages/react/react_with_react_dom_prod.js"></script>
        <script src="packages/react/react_dom_prod.js"></script>''')
    ]);

d.DirectoryDescriptor expectedOutputFiles({
  Iterable<d.Descriptor> additionalFilesInLib = const [],
  String rmuiVersionConstraint = '^1.1.1',
}) =>
    d.dir('project', [
      d.file('dev.html', /*language=html*/ '''
<script src="packages/react/js/react.dev.js"></script>
        <script src="packages/react/react_dom.js"></script>'''),
      d.file('dev_with_addons.html', /*language=html*/ '''
<script src="packages/react/js/react.dev.js"></script>
        <script src="packages/react/react_dom.js"></script>'''),
      d.file('prod.html', /*language=html*/ '''
<script src="packages/react/js/react.min.js"></script>
        <script src="packages/react/react_dom_prod.js"></script>'''),
      d.file('prod_with_addons.html', /*language=html*/ '''
<script src="packages/react/js/react.min.js"></script>
        <script src="packages/react/react_dom_prod.js"></script>''')
    ]);

// Adapted from `testCodemod` in https://github.com/Workiva/dart_codemod/blob/c5d245308554b0e1e7a15a54fbd2c79a9231e2be/test/functional/run_interactive_codemod_test.dart#L39
// Intentionally does not run `pub get` on the project, since we want to test that the MUI executable does that.
@isTest
Future<Null> testCodemod(
    String description, {
      required String script,
      required d.DirectoryDescriptor input,
      d.DirectoryDescriptor? expectedOutput,
      List<String>? args,
      void Function(String out, String err)? body,
      int? expectedExitCode,
      List<String>? stdinLines,
    }) async {
  test(description, () async {
    final projectDir = input;
    await projectDir.create();

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
  });
}

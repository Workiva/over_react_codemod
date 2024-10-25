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
  group('mui_migration executable', () {
    final muiCodemodScript =
        p.join(findPackageRootFor(p.current), 'bin/mui_migration.dart');

    testCodemod('--help outputs usage help text and does not run the codemod',
        script: muiCodemodScript,
        input: inputFiles(),
        expectedOutput: inputFiles(),
        expectedExitCode: 0,
        args: ['--help'], body: (out, err) {
      expect(
          err,
          allOf(
            contains(codemodArgParser.usage),
            contains('MUI Migration Options:'),
          ));
    });

    testCodemod(
        'applies all patches via --yes-to-all,'
        'and also correctly runs `pub get` if needed, migrates components,'
        ' adds MUI imports, and removes WSD imports all in a single run',
        script: muiCodemodScript,
        input: inputFiles(),
        expectedOutput: expectedOutputFiles(),
        args: ['--yes-to-all']);

    testCodemod('--fail-on-changes exits with 0 when no changes needed',
        script: muiCodemodScript,
        input: expectedOutputFiles(),
        expectedOutput: expectedOutputFiles(),
        args: ['--fail-on-changes'], body: (out, err) {
      expect(out, contains('No changes needed.'));
    });

    testCodemod(
        '--fail-on-changes exits with non-zero when changes needed and does not update files',
        script: muiCodemodScript,
        input: inputFiles(),
        expectedOutput: inputFiles(),
        args: ['--fail-on-changes'],
        expectedExitCode: 1, body: (out, err) {
      expect(err, contains(' change(s) needed.'));
    });

    testCodemod('fails when component factories cannot be resolved',
        script: muiCodemodScript,
        input: d.dir('project', [
          // Use a pubspec without WSD so this runs a little faster
          d.file('pubspec.yaml', /*language=yaml*/ '''
name: test_project
environment:
  sdk: ">=2.11.0 <3.0.0"
dependencies:'''),
          d.dir('lib', [
            d.file('usage.dart', /*language=dart*/ '''usage() => Button()();''')
          ]),
        ]),
        args: ['--yes-to-all'],
        expectedExitCode: 70, body: (out, err) {
      expect(err, contains('Builder static type could not be resolved'));
    });

    testCodemod('resolves part files even when they come before library files',
        script: muiCodemodScript,
        input: inputFiles(additionalFilesInLib: [
          d.file('a_part.dart', /*language=dart*/ '''
            part of 'library.dart';

            usage() => Button()();'''),
          d.file('library.dart', /*language=dart*/ '''
            import 'package:web_skin_dart/component2/button.dart';

            part 'a_part.dart';'''),
        ]),
        expectedOutput: expectedOutputFiles(additionalFilesInLib: [
          d.file('a_part.dart', /*language=dart*/ '''
            part of 'library.dart';

            usage() => mui.Button()();'''),
          d.file('library.dart', /*language=dart*/ '''
            import 'package:react_material_ui/react_material_ui.dart' as mui;

            part 'a_part.dart';'''),
        ]),
        args: ['--yes-to-all']);

    group('--component flag', () {
      testCodemod('fails with no components given',
          script: muiCodemodScript,
          input: inputFiles(),
          expectedOutput: inputFiles(),
          args: ['--yes-to-all', '--component'],
          expectedExitCode: 255, body: (out, err) {
        expect(err, contains('Missing argument for "component"'));
      });

      testCodemod('for one component',
          script: muiCodemodScript,
          input: inputFiles(additionalFilesInLib: [
            d.file('usage2.dart', /*language=dart*/ '''
              import 'package:web_skin_dart/component2/all.dart';

              usage() => ButtonToolbar()(
                Button()(),
                ButtonGroup()(
                  Button()(),
                  Button()(),
                ),
              );'''),
          ]),
          expectedOutput: expectedOutputFiles(additionalFilesInLib: [
            d.file('usage2.dart', /*language=dart*/ '''
              import 'package:react_material_ui/react_material_ui.dart' as mui;
import 'package:web_skin_dart/component2/all.dart';

              usage() => ButtonToolbar()(
                mui.Button()(),
                ButtonGroup()(
                  mui.Button()(),
                  mui.Button()(),
                ),
              );'''),
          ]),
          args: ['--yes-to-all', '--component=Button']);

      testCodemod('for multiple components',
          script: muiCodemodScript,
          input: inputFiles(additionalFilesInLib: [
            d.file('usage2.dart', /*language=dart*/ '''
              import 'package:web_skin_dart/component2/all.dart';

              usage() => ButtonToolbar()(
                Button()(),
                ButtonGroup()(
                  Button()(),
                  Button()(),
                ),
              );'''),
          ]),
          expectedOutput: expectedOutputFiles(additionalFilesInLib: [
            d.file('usage2.dart', /*language=dart*/ '''
              import 'package:react_material_ui/react_material_ui.dart' as mui;
import 'package:web_skin_dart/component2/all.dart';

              usage() => mui.ButtonToolbar()(
                mui.Button()(),
                ButtonGroup()(
                  mui.Button()(),
                  mui.Button()(),
                ),
              );'''),
          ]),
          args: ['--yes-to-all', '--component=Button,ButtonToolbar']);

      testCodemod('fails if one of the components does not have a migrator',
          script: muiCodemodScript,
          input: inputFiles(),
          expectedOutput: inputFiles(),
          args: ['--yes-to-all', '--component=Button,DoesNotExist'],
          expectedExitCode: 255, body: (out, err) {
        expect(err, contains('is not an allowed value for option "component"'));
      });

      testCodemod('updates all components when the flag is not present',
          script: muiCodemodScript,
          input: inputFiles(additionalFilesInLib: [
            d.file('usage2.dart', /*language=dart*/ '''
              import 'package:web_skin_dart/component2/all.dart';

              usage() => ButtonToolbar()(
                Button()(),
                ButtonGroup()(
                  Button()(),
                  Button()(),
                ),
              );'''),
          ]),
          expectedOutput: expectedOutputFiles(additionalFilesInLib: [
            d.file('usage2.dart', /*language=dart*/ '''
              import 'package:react_material_ui/react_material_ui.dart' as mui;

              usage() => mui.ButtonToolbar()(
                mui.Button()(),
                mui.ButtonGroup()(
                  mui.Button()(),
                  mui.Button()(),
                ),
              );'''),
          ]),
          args: ['--yes-to-all']);
    });

    testCodemod(
        '--rmui-version flag sets the version used in the react_material_ui version constraint',
        script: muiCodemodScript,
        input: inputFiles(),
        expectedOutput: expectedOutputFiles(rmuiVersionConstraint: '^9.9.9'),
        args: ['--yes-to-all', '--rmui-version=9.9.9']);

    testCodemod('nested pubspecs',
        script: muiCodemodScript,
        input: d.dir('project', [
          d.file('pubspec.yaml', /*language=yaml*/ '''
name: test_project
environment:
  sdk: '>=2.11.0 <3.0.0'
dependencies:
  over_react: ^4.2.0
  react: ^6.1.0'''),
          d.dir('lib', [
            inputFiles(),
          ]),
          inputFiles(),
        ]),
        expectedOutput: d.dir('project', [
          d.file('pubspec.yaml', /*language=yaml*/ '''
name: test_project
environment:
  sdk: '>=2.11.0 <3.0.0'
dependencies:
  over_react: ^4.2.0
  react: ^6.1.0
  react_material_ui:
    hosted:
      name: react_material_ui
      url: https://pub.workiva.org
    version: ^1.1.1
'''),
          d.dir('lib', [
            expectedOutputFiles(),
          ]),
          expectedOutputFiles(),
        ]),
        args: ['--yes-to-all']);

    testCodemod('fails when pub get fails',
        script: muiCodemodScript,
        input: d.dir('project', [
          d.file('pubspec.yaml', /*language=yaml*/ '''
name: test_project
environment:
  sdk: '>=2.11.0 <3.0.0'
dependencies:
  does_not_exist: ^1.0.0
  web_skin_dart:
    hosted:
      name: web_skin_dart
      url: https://pub.workiva.org
    version: ^2.56.0'''),
          d.dir('lib', [
            d.file('usage.dart', /*language=dart*/ '''
          import 'package:web_skin_dart/component2/button.dart';

          usage() => Button()();''')
          ]),
        ]),
        expectedOutput: d.dir('project', [
          d.file('pubspec.yaml', /*language=yaml*/ '''
name: test_project
environment:
  sdk: '>=2.11.0 <3.0.0'
dependencies:
  does_not_exist: ^1.0.0
  web_skin_dart:
    hosted:
      name: web_skin_dart
      url: https://pub.workiva.org
    version: ^2.56.0'''),
          d.dir('lib', [
            d.file('usage.dart', /*language=dart*/ '''
          import 'package:web_skin_dart/component2/button.dart';

          usage() => Button()();''')
          ]),
        ]),
        args: ['--yes-to-all'],
        expectedExitCode: 255, body: (out, err) {
      expect(err, contains('pub get failed'));
    });

    // Set a longer timeout since some of these need to `pub get` and resolve WSD.
    // Even with a primed pub cache, the longest of these tests take ~35 seconds locally.
  }, timeout: Timeout(Duration(minutes: 2)));
}

d.DirectoryDescriptor inputFiles(
        {Iterable<d.Descriptor> additionalFilesInLib = const []}) =>
    d.dir('project', [
      d.file('pubspec.yaml', /*language=yaml*/ '''
name: test_project
environment:
  sdk: '>=2.11.0 <3.0.0'
dependencies:
  web_skin_dart:
    hosted:
      name: web_skin_dart
      url: https://pub.workiva.org
    version: ^2.56.0'''),
      d.dir('lib', [
        ...additionalFilesInLib,
        d.file('usage.dart', /*language=dart*/ '''
          import 'package:web_skin_dart/component2/button.dart';
            
          usage() => Button()();''')
      ]),
    ]);

d.DirectoryDescriptor expectedOutputFiles({
  Iterable<d.Descriptor> additionalFilesInLib = const [],
  String rmuiVersionConstraint = '^1.1.1',
}) =>
    d.dir('project', [
      d.file('pubspec.yaml', /*language=yaml*/ '''
name: test_project
environment:
  sdk: '>=2.11.0 <3.0.0'
dependencies:
  react_material_ui:
    hosted:
      name: react_material_ui
      url: https://pub.workiva.org
    version: $rmuiVersionConstraint
  web_skin_dart:
    hosted:
      name: web_skin_dart
      url: https://pub.workiva.org
    version: ^2.56.0'''),
      d.dir('lib', [
        ...additionalFilesInLib,
        d.file('usage.dart', /*language=dart*/ '''
          import 'package:react_material_ui/react_material_ui.dart' as mui;
            
          usage() => mui.Button()();''')
      ]),
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

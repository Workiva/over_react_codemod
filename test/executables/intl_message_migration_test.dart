// Copyright 2022 Workiva Inc.
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

import 'package:codemod/src/run_interactive_codemod.dart' show codemodArgParser;
import 'package:over_react_codemod/src/util/package_util.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'mui_migration_test.dart' show testCodemod;

// Change this to `true` and all of the functional tests in this file will print
// the stdout/stderr of the codemod processes.
final _debug = false;

// The help text may have different amount of whitespace depending on the names
// of the options, so collapse all whitespace to a
String condenseWhitespace(String input) =>
    input.split(RegExp(r"\s+")).join(" ");

void main() {
  group('intl_message_migration executable', () {
    final script = p.join(
        findPackageRootFor(p.current), 'bin/intl_message_migration.dart');

    testCodemod('--help outputs usage help text and does not run the codemod',
        script: script,
        input: inputFiles(),
        expectedOutput: inputFiles(),
        expectedExitCode: 0,
        args: ['--help'], body: (out, err) {
      expect(
          condenseWhitespace(err),
          allOf(
            contains(condenseWhitespace(codemodArgParser.usage)),
            contains('Migrates literal strings'),
          ));
    });

    testCodemod('applies all patches via --yes-to-all,',
        script: script,
        input: inputFiles(),
        expectedOutput: expectedOutputFiles(),
        args: ['--yes-to-all']);

    testCodemod('--fail-on-changes exits with 0 when no changes needed',
        script: script,
        input: expectedOutputFiles(),
        expectedOutput: expectedOutputFiles(),
        args: ['--fail-on-changes'], body: (out, err) {
      expect(out, contains('No changes needed.'));
    });

    testCodemod(
        '--fail-on-changes exits with non-zero when changes needed and does not update files',
        script: script,
        input: inputFiles(),
        expectedOutput: inputFiles(),
        args: ['--fail-on-changes'],
        expectedExitCode: 1, body: (out, err) {
      expect(err, contains(' change(s) needed.'));
    });

    testCodemod('Output is sorted',
        script: script,
        input: inputFiles(additionalFilesInLib: [
          d.file('more_stuff.dart',
              /*language=dart*/ '''import 'package:react_material_ui/react_material_ui.dart' as mui;

someMoreStrings() => (mui.Button()..aria.label='orange')('aquamarine');''')
        ]),
        expectedOutput: expectedOutputFiles(
            additionalFilesInLib: [
              d.file('more_stuff.dart',
                  /*language=dart*/ '''import 'package:react_material_ui/react_material_ui.dart' as mui;
import 'package:test_project/src/intl/test_project_intl.dart';

someMoreStrings() => (mui.Button()..aria.label=TestProjectIntl.orange)(TestProjectIntl.aquamarine);''')
            ],
            messages: [
              ...defaultMessages,
              "  static String get orange => Intl.message('orange', name: 'TestProjectIntl_orange',);",
              "  static String get aquamarine => Intl.message('aquamarine', name: 'TestProjectIntl_aquamarine',);"
            ]..sort()),
        args: ['--yes-to-all']);
  }, tags: 'wsd');
}

d.DirectoryDescriptor inputFiles(
    {Iterable<d.Descriptor> additionalFilesInLib = const []}) {
  String rmuiVersionConstraint = '^1.1.1';
  return d.dir('project', [
    d.file('pubspec.yaml', /*language=yaml*/ '''
name: test_project
environment:
  sdk: '>=2.11.0 <3.0.0'
dependencies:
  react_material_ui:
    hosted:
      name: react_material_ui
      url: https://pub.workiva.org
    version: $rmuiVersionConstraint'''),
    d.dir('lib', [
      ...additionalFilesInLib,
      d.file('usage.dart',
          /*language=dart*/ '''import 'package:react_material_ui/react_material_ui.dart' as mui;

usage() => (mui.Button()..aria.label='Sorts later')('Literal String');''')
    ]),
  ]);
}

const List<String> defaultMessages = [
  "  static String get literalString => Intl.message('Literal String', name: 'TestProjectIntl_literalString',);",
  "  static String get sortsLater => Intl.message('Sorts later', name: 'TestProjectIntl_sortsLater',);"
];

d.DirectoryDescriptor expectedOutputFiles({
  Iterable<d.Descriptor> additionalFilesInLib = const [],
  List<String> messages = defaultMessages,
  String rmuiVersionConstraint = '^1.1.1',
}) {
  return d.dir('project', [
    // Note that the codemod doesn't currently add the intl dependency to the pubspec.
    d.file('pubspec.yaml', /*language=yaml*/ '''
name: test_project
environment:
  sdk: '>=2.11.0 <3.0.0'
dependencies:
  react_material_ui:
    hosted:
      name: react_material_ui
      url: https://pub.workiva.org
    version: $rmuiVersionConstraint'''),
    d.dir('lib', [
      ...additionalFilesInLib,
      d.file('usage.dart', /*language=dart*/ '''
import 'package:react_material_ui/react_material_ui.dart' as mui;
import 'package:test_project/src/intl/test_project_intl.dart';

usage() => (mui.Button()..aria.label=TestProjectIntl.sortsLater)(TestProjectIntl.literalString);'''),
      d.dir('src', [
        d.dir('intl', [
          d.file('test_project_intl.dart', /*language=dart*/ '''
import 'package:intl/intl.dart';

//ignore: avoid_classes_with_only_static_members
class TestProjectIntl {
${messages.join('\n')}
}''')
        ]),
      ]),
    ]),
  ]);
}

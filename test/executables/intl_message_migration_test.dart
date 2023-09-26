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
import 'package:over_react_codemod/src/executables/intl_message_migration.dart';
import 'package:over_react_codemod/src/intl_suggestors/intl_messages.dart';
import 'package:over_react_codemod/src/util/package_util.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'mui_migration_test.dart' show testCodemod;

// The help text may have different amount of whitespace depending on the names
// of the options, so collapse all whitespace to a single space before comparing.
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

    // It would be nice to verify that the file modification date is newer, but
    // the codemod test framework doesn't really support that.
    testCodemod('--no-migrate exits with zero, does not does not update files',
        script: script,
        input: inputFiles(),
        expectedOutput: inputFiles(),
        args: ['--no-migrate']);

    testCodemod('Output is sorted',
        script: script,
        input: inputFiles(additionalFilesInLib: [extraInput()]),
        expectedOutput: expectedOutputFiles(
            additionalFilesInLib: [extraOutput()],
            messages: [...defaultMessages, ...extraMessages, ...longMessages]
              ..sort(),
          rmuiVersionConstraint: '^1.1.1',
          intlImport: 'package:test_project/src/intl/test_project_intl.dart',
        ),
        args: ['--yes-to-all']);

    // Test that additional information (desc, meaning) are preserved if we read and then rewrite the file.
    testCodemod('Manual modifications are preserved',
        script: script,
        input: expectedOutputFiles(additionalFilesInLib: [
          extraInput()
        ], messages: [
          ...defaultMessages,
          ...annotatedMessages,
        ]),
        expectedOutput: expectedOutputFiles(
            additionalFilesInLib: [extraOutput()],
            messages: [
              ...defaultMessages,
              ...annotatedMessages,
              ...longMessages,
            ]..sort(),
          rmuiVersionConstraint: '^1.1.1',
          intlImport: 'package:test_project/src/intl/test_project_intl.dart',
        ),
        args: ['--yes-to-all']);

    // We've removed the file for some that were already in the _intl.dart file,
    // and we expect them to be removed.
    testCodemod('Unused messages are removed',
        script: script,
        input: expectedOutputFiles(additionalFilesInLib: [], messages: [
          ...defaultMessages,
          ...annotatedMessages,
        ]),
        expectedOutput: expectedOutputFiles(
            additionalFilesInLib: [], messages: [...defaultMessages]..sort()),
        args: ['--yes-to-all', '--prune-unused']);

    // Don't prune, but remove the input file. Also add some extra messages to force
    // the file to be rewritten, and ensure the unused messages are still there.
    testCodemod("Unused messages are not removed if we don't pass the flag",
        script: script,
        input: expectedOutputFiles(additionalFilesInLib: [
          extraInput()
        ], messages: [
          ...defaultMessages,
          ...annotatedMessages,
        ]),
        expectedOutput: expectedOutputFiles(
            additionalFilesInLib: [],
            messages: [
              ...defaultMessages,
              ...annotatedMessages,
              ...longMessages
            ]..sort()),
        args: ['--yes-to-all']);

    // Test that we update the file to use the w_intl import, even if there are no other changes.
    testCodemod('Import is updated',
        script: script,
        input: expectedOutputFiles(additionalFilesInLib: [
          d.file('more_stuff.dart',
              /*language=dart*/ '''import 'package:react_material_ui/react_material_ui.dart' as mui;
import 'package:test_project/src/intl/test_project_intl.dart';

someMoreStrings() => (mui.Button()
  ..aria.label=TestProjectIntl.orange
  ..label=TestProjectIntl.aLongStringwithMultipleLines)(TestProjectIntl.aquamarine, TestProjectIntl.twoAdjacentStringsOnSeparate);
''')
        ], messages: [
          ...defaultMessages,
          ...annotatedMessages,
        ], intlImport: '${wIntl}/intl_wrapper.dart'),
        expectedOutput: expectedSecondOutputFiles(
            additionalFilesInLib: [extraOutput()],
            messages: [
              ...defaultMessages,
              ...annotatedMessages,
              ...longMessages
            ]..sort(),
            intlImport: '${wIntl}/intl_wrapper.dart'),
        args: ['--yes-to-all']);

    testCodemod('Import is updated without other modifications',
        script: script,
        input: expectedOutputFiles(intlImport: 'intl/intl.dart'),
        expectedOutput: expectedOutputFiles(),
        args: ['--yes-to-all']);

    testCodemod('Specify a single file',
        // We add some extra files, but we specify just the original, so they shouldn't be included.
        script: script,
        input: inputFiles(additionalFilesInLib: [extraInput()]),
        expectedOutput: expectedOutputFiles(messages: defaultMessages),
        args: ['--yes-to-all', 'lib/usage.dart']);

    testCodemod('Specifying only part files is an error',
        script: script,
        input: inputFiles(additionalFilesInLib: [
          d.file(
              'a_part_file.dart', /*language=dart*/ '''part of something.bigger;

someMoreStrings() => (mui.Button()..aria.label='orange')('aquamarine');''')
        ]),
        expectedOutput: inputFiles(),
        args: ['--yes-to-all', 'lib/a_part_file.dart'],
        expectedExitCode: 1, body: (out, err) {
      expect(err, contains('Only part files were specified'));
    });
  }, tags: 'wsd');

  group('limit paths', () {
    var all = ['lib/src/a.dart', 'lib/b.dart', 'lib/src/a/c.dart'];
    test('single file', () {
      var allowed = ['lib/src/a.dart'];
      expect(limitPaths(all, allowed: allowed), allowed);
    });

    test('multiples all match', () {
      var allowed = ['lib/b.dart', 'lib/src/a.dart'];
      expect(
          limitPaths(all, allowed: allowed), ['lib/src/a.dart', 'lib/b.dart']);
    });
    test('multiples some match', () {
      var allowed = ['lib/nothere.dart', 'lib/src/a/c.dart'];
      expect(limitPaths(all, allowed: allowed), ['lib/src/a/c.dart']);
    });
    test('directory match', () {
      var allowed = ['lib/src'];
      expect(limitPaths(all, allowed: allowed),
          ['lib/src/a.dart', 'lib/src/a/c.dart']);
    });

    test('directory plus file', () {
      var allowed = ['lib/src', 'test/foo.dart'];
      var allFiles = [...all, 'test/foo.dart', 'test/other.dart'];
      expect(limitPaths(allFiles, allowed: allowed),
          ['lib/src/a.dart', 'lib/src/a/c.dart', 'test/foo.dart']);
    });
    test('no match for file', () {
      var allowed = ['lib/src/nothere.dart'];
      expect(limitPaths(all, allowed: allowed), isEmpty);
    });

    test('no match for directory', () {
      var allowed = ['lib/src/nothere'];
      expect(limitPaths(all, allowed: allowed), isEmpty);
    });
  });
}

/// An extra input file we can use.
d.FileDescriptor extraInput() {
  return d.file('more_stuff.dart',
      /*language=dart*/ '''import 'package:react_material_ui/react_material_ui.dart' as mui;

someMoreStrings() => (mui.Button()
  ..aria.label='orange'
  ..label="""
A long string
with multiple
   lines""")
    ('aquamarine',
     'two adjacent '
     'strings on separate lines');''');
}

d.FileDescriptor extraOutput() {
  return d.file('more_stuff.dart',
      /*language=dart*/ '''import 'package:react_material_ui/react_material_ui.dart' as mui;
import 'package:test_project/src/intl/test_project_intl.dart';

someMoreStrings() => (mui.Button()
  ..aria.label=TestProjectIntl.orange
  ..label=TestProjectIntl.aLongStringwithMultipleLines)
    (TestProjectIntl.aquamarine, TestProjectIntl.twoAdjacentStringsOnSeparate);
''');
}

List<String> extraMessages = [
  "  static String get orange => Intl.message('orange', name: 'TestProjectIntl_orange');",
  "  static String get aquamarine => Intl.message('aquamarine', name: 'TestProjectIntl_aquamarine');"
];

/// Messages that have extra parameters we want to preserve.
List<String> annotatedMessages = [
  "  static String get orange => Intl.message('orange', name: 'TestProjectIntl_orange', desc: 'The color.');",
  "  static String get aquamarine => Intl.message('aquamarine', name: 'TestProjectIntl_aquamarine', desc: 'The color', meaning: 'blueish');"
];

List<String> longMessages = [
  """  static String get twoAdjacentStringsOnSeparate => Intl.message('two adjacent strings on separate lines', name: 'TestProjectIntl_twoAdjacentStringsOnSeparate');""",
  """  static String get aLongStringwithMultipleLines => Intl.message('''A long string
with multiple
   lines''', name: 'TestProjectIntl_aLongStringwithMultipleLines');""",
];

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
  "  static String get literalString => Intl.message('Literal String', name: 'TestProjectIntl_literalString');",
  "  static String get sortsLater => Intl.message('Sorts later', name: 'TestProjectIntl_sortsLater');",
];

d.DirectoryDescriptor expectedOutputFiles(
    {Iterable<d.Descriptor> additionalFilesInLib = const [],
    List<String> messages = defaultMessages,
    String rmuiVersionConstraint = '^1.1.1',
    String intlImport = '${wIntl}/intl_wrapper.dart'}) {
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
import 'package:test_project/src/intl/test_project_intl.dart';
import 'package:react_material_ui/react_material_ui.dart' as mui;

usage() => (mui.Button()..aria.label=TestProjectIntl.sortsLater)(TestProjectIntl.literalString);'''),
      d.dir('src', [
        d.dir('intl', [
          d.file('test_project_intl.dart', /*language=dart*/ '''
import 'package:${intlImport}';

${IntlMessages.introComment}

//ignore_for_file: avoid_classes_with_only_static_members
//ignore_for_file: unnecessary_brace_in_string_interps
class TestProjectIntl {
${messages.join('\n\n')}

}''')
        ]),
      ]),
    ]),
  ]);
}

d.DirectoryDescriptor expectedSecondOutputFiles(
    {Iterable<d.Descriptor> additionalFilesInLib = const [],
      List<String> messages = defaultMessages,
      String rmuiVersionConstraint = '^1.1.1',
      String intlImport = '${wIntl}/intl_wrapper.dart'}) {
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
import 'package:${intlImport}';

${IntlMessages.introComment}

//ignore_for_file: avoid_classes_with_only_static_members
//ignore_for_file: unnecessary_brace_in_string_interps
class TestProjectIntl {
${messages.join('\n\n')}

}''')
        ]),
      ]),
    ]),
  ]);
}

const wIntl = 'w_intl';

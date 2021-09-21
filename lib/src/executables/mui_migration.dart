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

import 'dart:io';

import 'package:args/args.dart';
import 'package:codemod/codemod.dart';
import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:logging/logging.dart';
import 'package:over_react_codemod/src/ignoreable.dart';
import 'package:over_react_codemod/src/mui_suggestors/mui_button_group_migrator.dart';
import 'package:over_react_codemod/src/mui_suggestors/mui_button_migrator.dart';
import 'package:over_react_codemod/src/mui_suggestors/mui_button_toolbar_migrator.dart';
import 'package:over_react_codemod/src/mui_suggestors/mui_importer.dart';
import 'package:over_react_codemod/src/util.dart';
import 'package:over_react_codemod/src/util/package_util.dart';
import 'package:over_react_codemod/src/util/pubspec_upgrader.dart';

final _log = Logger('orcm.mui_migration');

void main(List<String> args) async {
  final parser = ArgParser.allowAnything();

  final parsedArgs = parser.parse(args);

  // codemod sets up a global logging handler that forwards to the console, and
  // we want that set up before we do other non-codemodd things that might log.
  //
  // We could set up logging too, but we can't disable codemod's log handler,
  // so we'd have to disable our own logging before calling into codemod.
  // While hackier, this is easier.
  //
  // This also lets us handle `--help` before we start doing other work.
  //
  // FIXME each time we call runInteractiveCodemod, all subsequent logs are forwarded to the console an extra time. Update codemod package to prevent this (maybe a flag to disable automatic global logging?)
  exitCode = await runInteractiveCodemod(
    [],
    (_) async* {},
    args: parsedArgs.rest,
    additionalHelpOutput: parser.usage,
  );
  if (exitCode != 0) return;
  print('^ Ignore the "codemod found no files" warning above for now.');

  /// Runs a set of codemod sequences separately to work around an issue where
  /// updates from an earlier suggestor aren't reflected in the resolved AST
  /// for later suggestors.
  ///
  /// This means we have to set up analysis contexts multiple times, which takes longer,
  /// but isn't a dealbreaker. E.g., for wdesk_sdk, running two sequences takes 2:52
  /// as opposed to 2:00 for one sequence.
  ///
  /// If any sequence fails, returns that exit code and short-circuits the other
  /// sequences.
  Future<int> runCodemodSequences(
    Iterable<String> paths,
    Iterable<Iterable<Suggestor>> sequences,
  ) async {
    for (final sequence in sequences) {
      final exitCode = await runInteractiveCodemodSequence(
        paths,
        sequence,
        defaultYes: true,
        args: parsedArgs.rest,
        additionalHelpOutput: parser.usage,
      );
      if (exitCode != 0) return exitCode;
    }

    return 0;
  }

  final dartPaths = dartFilesToMigrate();
  await pubGetForAllPackageRoots(dartPaths);
  exitCode = await runCodemodSequences(dartPaths, [
    [
      // It should generally be safe to aggregate these since each component usage
      // should only be handled by a single migrator, and shouldn't depend on the
      // output of previous migrators.
      // fixme is there any benefit to aggregating these?
      aggregate([
        MuiButtonMigrator(),
        MuiButtonGroupMigrator(),
        MuiButtonToolbarMigrator(),
      ]),
    ],
    [muiImporter],
  ]);
  if (exitCode != 0) return;

  exitCode = await runInteractiveCodemod(
    // FIXME use allPubsepcYamlPaths()
    ['./pubspec.yaml'],
    aggregate([
      PubspecUpgrader('react_material_ui', parseVersionRange('^0.3.0'),
          hostedUrl: 'https://pub.workiva.org'),
    ].map((s) => ignoreable(s))),
    defaultYes: true,
    args: parsedArgs.rest,
    additionalHelpOutput: parser.usage,
  );
  if (exitCode != 0) return;
}

Future<void> pubGetForAllPackageRoots(Iterable<String> files) async {
  _log.info(
      'Running `pub get` if needed so that all Dart files can be resolved...');
  final packageRoots = files.map(getPackageRootForFile).toSet();
  for (final packageRoot in packageRoots) {
    await runPubGetIfNeeded(packageRoot);
  }
}

// TODO we'll probably going to need to also ignore files excluded in analysis_options.yaml
// so that our component migrator codemods don't fail when they can't resolve the files.
Iterable<String> dartFilesToMigrate() => Glob('**.dart', recursive: true)
    .listSync()
    .whereType<File>()
    .where(isNotHiddenFile)
    .where(isNotDartHiddenFile)
    .where(isNotWithinTopLevelBuildOutputDir)
    .map((e) => e.path);

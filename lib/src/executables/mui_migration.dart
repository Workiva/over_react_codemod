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
import 'package:over_react_codemod/src/ignoreable.dart';
import 'package:over_react_codemod/src/mui_suggestors/mui_button_group_migrator.dart';
import 'package:over_react_codemod/src/mui_suggestors/mui_button_migrator.dart';
import 'package:over_react_codemod/src/mui_suggestors/mui_button_toolbar_migrator.dart';
import 'package:over_react_codemod/src/mui_suggestors/mui_importer.dart';
import 'package:over_react_codemod/src/util.dart';
import 'package:over_react_codemod/src/util/pubspec_upgrader.dart';

void main(List<String> args) async {
  final parser = ArgParser.allowAnything();

  final parsedArgs = parser.parse(args);

  /// Runs a set of codemod sequences separately to work around an issue where
  /// updates from an earlier suggestor aren't reflected in the resolved AST
  /// for later suggestors.
  Future<void> runCodemodSequences(
    Iterable<String> paths,
    Iterable<Iterable<Suggestor>> sequences,
  ) async {
    for (final sequence in sequences) {
      exitCode = await runInteractiveCodemodSequence(
        paths,
        sequence,
        defaultYes: true,
        args: parsedArgs.rest,
        additionalHelpOutput: parser.usage,
      );
      if (exitCode != 0) break;
    }
  }

  await runCodemodSequences(allDartPathsExceptHiddenAndGenerated(), [
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

  exitCode = await runInteractiveCodemod(
    // FIXME use allPubsepcYamlPaths()
    ['./pubspec.yaml'],
    aggregate([
      PubspecUpgrader('react_material_ui', parseVersionRange('^0.3.0'),
          hostedUrl: 'https://pub.workiva.org'),
    ].map((s) => ignoreable(s))),
    defaultYes: true,
    args: parsedArgs.rest,
  );
}

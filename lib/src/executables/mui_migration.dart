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
import 'package:over_react_codemod/src/mui_suggestors/mui_importer.dart';
import 'package:over_react_codemod/src/mui_suggestors/mui_migrators.dart';

const _componentFlag = 'component';

void main(List<String> args) async {
  final parser = ArgParser()
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Prints this help output')
    ..addFlag(
      'yes-to-all',
      negatable: false,
      help: 'Forces all patches accepted without prompting the user. '
          'Useful for scripts.',
    )
    ..addSeparator('MUI Migration Options:')
    ..addMultiOption(
      _componentFlag,
      allowed: muiMigrators.keys,
      help: 'Choose which component migrators should be run.',
    );

  final parsedArgs = parser.parse(args);

  if (parsedArgs['help'] == true) {
    stderr.writeln(parser.usage);
    return;
  }

  /// Runs a set of codemod sequences separately to work around an issue where
  /// updates from an earlier suggestor aren't reflected in the resolved AST
  /// for later suggestors.
  Future<void> runCodemodSequences(
      Iterable<Iterable<Suggestor>> sequences) async {
    for (final sequence in sequences) {
      exitCode = await runInteractiveCodemodSequence(
        // allDartPathsExceptHidden(),
        // filePathsFromGlob(Glob('lib/src/embedding_harness/harness_module/components/harness_tools_panel.dart', recursive: true)),
        filePathsFromGlob(Glob('lib/**.dart', recursive: true)),
        sequence,
        defaultYes: true,
        args: parsedArgs.rest,
        additionalHelpOutput: parser.usage,
      );
      if (exitCode != 0) break;
    }
  }

  // Only run the migrators for components that were specified in [args].
  // If no components were specified, run all migrators.
  final migratorsToRun = parsedArgs[_componentFlag] == null
      ? muiMigrators.values
      : (parsedArgs[_componentFlag] as List<String>).map((componentName) {
          final migrator = muiMigrators[componentName];
          if (migrator == null) {
            throw Exception('Could not find a migrator for $componentName');
          }
          return migrator;
        });

  await runCodemodSequences([
    [
      // It should generally be safe to aggregate these since each component usage
      // should only be handled by a single migrator, and shouldn't depend on the
      // output of previous migrators.
      // fixme is there any benefit to aggregating these?
      aggregate(migratorsToRun)
    ],
    [muiImporter],
    // TODO update this to add RMUI dependency in pubspec
    // PubspecOverReactUpgrader(overReactVersionConstraint as VersionRange,
    //     shouldAddDependencies: false),
  ]);
}

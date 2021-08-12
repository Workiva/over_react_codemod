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
import 'package:logging/logging.dart';
import 'package:over_react_codemod/src/mui_suggestors/mui_button_migrator.dart';

void main(List<String> args) async {
  final parser = ArgParser()
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Prints this help output')
    ..addFlag('verbose',
        abbr: 'v',
        negatable: false,
        help: 'Outputs all logging to stdout/stderr.')
    ..addFlag(
      'yes-to-all',
      negatable: false,
      help: 'Forces all patches accepted without prompting the user. '
          'Useful for scripts.',
    )
    ..addSeparator('Boilerplate Upgrade Options:');

  final parsedArgs = parser.parse(args);

  if (parsedArgs['help'] == true) {
    stderr.writeln(parser.usage);
    return;
  }

  final logger = Logger('over_react_codemod.mui_migration');

  logger.onRecord.listen((rec) {
    // ignore severe messages here because stderr will print it
    if (rec.message.isNotEmpty && rec.level != Level.SEVERE) {
      print('[${rec.level}] ${rec.message}');
    }
    if (rec.error != null) {
      print(rec.error);
    }
    if (rec.stackTrace != null) {
      print(rec.stackTrace);
    }
  });

  exitCode = await runInteractiveCodemodSequence(
    // allDartPathsExceptHidden(),
    filePathsFromGlob(Glob('lib/**.dart', recursive: true)),
    [
      MuiButtonMigrator(),
      // TODO update this to add RMUI dependency in pubspec
      // PubspecOverReactUpgrader(overReactVersionConstraint as VersionRange,
      //     shouldAddDependencies: false),
    ],
    defaultYes: true,
  );
}

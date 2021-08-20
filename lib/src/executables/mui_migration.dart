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
import 'package:over_react_codemod/src/mui_suggestors/mui_button_migrator.dart';
import 'package:over_react_codemod/src/mui_suggestors/mui_importer.dart';

void main(List<String> args) async {
  final parser = ArgParser.allowAnything();

  final parsedArgs = parser.parse(args);

  exitCode = await runInteractiveCodemodSequence(
    // allDartPathsExceptHidden(),
    filePathsFromGlob(Glob('lib/**.dart', recursive: true)),
    [
      MuiButtonMigrator(),
      muiImporter,
      // TODO update this to add RMUI dependency in pubspec
      // PubspecOverReactUpgrader(overReactVersionConstraint as VersionRange,
      //     shouldAddDependencies: false),
    ],
    defaultYes: true,
    args: parsedArgs.rest,
    additionalHelpOutput: parser.usage,
  );
}

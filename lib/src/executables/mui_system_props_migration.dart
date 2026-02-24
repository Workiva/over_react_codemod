// Copyright 2026 Workiva Inc.
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
import 'package:over_react_codemod/src/mui_suggestors/system_props_to_sx_migrator.dart';
import 'package:over_react_codemod/src/util.dart';

const _changesRequiredOutput = """
  To update your code, run the following commands in your repository:
  dart pub global activate over_react_codemod
  dart pub global run over_react_codemod:mui_system_props_migration
""";

/// Migrates MUI system props to the `sx` prop.
///
/// MUI System props (such as `mt={*}`, `bgcolor={*}`, and more) have been deprecated
/// in MUI v6 in favor of the `sx` prop.
///
/// This codemod moves all System props to the sx prop, ensuring that existing
/// sx prop values are preserved and merged correctly.
void main(List<String> args) async {
  final parser = ArgParser.allowAnything();

  final parsedArgs = parser.parse(args);

  // Work around allowAnything not allowing you to pass flags.
  if (parsedArgs.arguments.contains('--help')) {
    // Print command description; flags and other output will get printed via runInteractiveCodemod.
    print('Migrates MUI system props to the `sx` prop.\n');
    print(
        'MUI System props (such as mt={*}, bgcolor={*}, and more) have been deprecated');
    print('in MUI v6 in favor of the sx prop.\n');
    print(
        'This codemod moves all System props to the sx prop, ensuring that existing');
    print('sx prop values are preserved and merged correctly.\n');
  }

  exitCode = await runInteractiveCodemod(
    allDartPathsExceptHidden(),
    aggregate([
      SystemPropsToSxMigrator(),
    ].map((s) => ignoreable(s))),
    defaultYes: true,
    args: parsedArgs.rest,
    additionalHelpOutput: parser.usage,
    changesRequiredOutput: _changesRequiredOutput,
  );
}

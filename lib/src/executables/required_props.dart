// Copyright 2024 Workiva Inc.
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

import 'package:args/args.dart';
import 'package:codemod/codemod.dart';
import 'package:over_react_codemod/src/dart3_suggestors/null_safety_prep/required_prop_info/prop_requiredness_aggregated.sg.dart';
import 'package:over_react_codemod/src/dart3_suggestors/null_safety_prep/required_props.dart';
import 'package:over_react_codemod/src/util.dart';

const _changesRequiredOutput = """
  To update your code, run the following commands in your repository:
  pub global activate over_react_codemod
  pub global run over_react_codemod:null_safety_prep
""";

const _requiredPropInfo = 'required-prop-info';

/// Codemods in this executable add nullability "hints" to assist with a
/// null-safety migration.
///
/// If it has not already been run, the `null_safety_prep` codemod should
/// also be run when migrating to null-safety.
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
    ..addSeparator('Boilerplate Upgrade Options:')
    ..addFlag(_requiredPropInfo,
        negatable: false,
        help:
            'Checks to see if this repo already has some components using the latest boilerplate and sets'
            'the codemod to fail on changes.');

  final parsedArgs = parser.parse(args);
  final dartPaths = allDartPathsExceptHiddenAndGenerated();

  final results = PropRequirednessResults.fromJson(jsonDecode(File(
          '/Users/greglittlefield/workspaces/wdesk_analysis_tools/prop_requiredness.json')
      .readAsStringSync()));
  final recommender =
      PropRequirednessRecommender(results, requirednessThreshold: 1);

  exitCode = await runInteractiveCodemodSequence(
    dartPaths,
    [
      RequiredPropsMigrator(recommender),
    ],
    defaultYes: true,
    args: parsedArgs.rest,
    additionalHelpOutput: parser.usage,
    changesRequiredOutput: _changesRequiredOutput,
  );
}

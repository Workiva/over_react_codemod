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
import 'package:over_react_codemod/src/dart3_suggestors/null_safety_prep/required_prop_info/aggregated_data.sg.dart';
import 'package:over_react_codemod/src/dart3_suggestors/null_safety_prep/required_props.dart';
import 'package:over_react_codemod/src/util.dart';

import '../util/codemod_args.dart';

class _Options {
  static const privateRequirednessThreshold = 'private-requiredness-threshold';
  static const privateMaxAllowedSkipRate = 'private-max-allowed-skip-rate';
  static const publicRequirednessThreshold = 'public-requiredness-threshold';
  static const publicMaxAllowedSkipRate = 'public-max-allowed-skip-rate';

  static const all = {
    privateRequirednessThreshold,
    privateMaxAllowedSkipRate,
    publicRequirednessThreshold,
    publicMaxAllowedSkipRate
  };
}

/// Codemods in this executable add nullability "hints" to assist with a
/// null-safety migration.
///
/// If it has not already been run, the `null_safety_prep` codemod should
/// also be run when migrating to null-safety.
void main(List<String> args) async {
  final parser = argParserWithCodemodArgs()
    ..addOption(_Options.privateRequirednessThreshold,
        defaultsTo: (0.95).toString(),
        help:
            'The minimum rate (0.0-1.0) a private prop must be set to be considered required.')
    ..addOption(_Options.privateMaxAllowedSkipRate,
        defaultsTo: (0.2).toString(),
        help:
            'The maximum allowed rate (0.0-1.0) of dynamic usages of private mixins, for which data collection was skipped.'
            '\nIf above this, all props in a mixin will be made optional (with a TODO comment).')
    ..addOption(_Options.publicRequirednessThreshold,
        defaultsTo: (1).toString(),
        help:
            'The minimum rate (0.0-1.0) a public prop must be set to be considered required.')
    ..addOption(_Options.publicMaxAllowedSkipRate,
        defaultsTo: (0.05).toString(),
        help:
            'The maximum allowed rate (0.0-1.0) of dynamic usages of public mixins, for which data collection was skipped.'
            '\nIf above this, all props in a mixin will be made optional (with a TODO comment).');

  final parsedArgs = parser.parse(args);
  final codemodArgs = removeOptionArgs(args, _Options.all);

  final dartPaths = allDartPathsExceptHiddenAndGenerated();

  final results = PropRequirednessResults.fromJson(jsonDecode(File(
          '/Users/greglittlefield/workspaces/wdesk_analysis_tools/prop_requiredness.json')
      .readAsStringSync()));
  final recommender = PropRequirednessRecommender(
    results,
    privateRequirednessThreshold:
        parsedArgs.argValueAsNumber(_Options.privateRequirednessThreshold),
    privateMaxAllowedSkipRate:
        parsedArgs.argValueAsNumber(_Options.privateMaxAllowedSkipRate),
    publicRequirednessThreshold:
        parsedArgs.argValueAsNumber(_Options.publicRequirednessThreshold),
    publicMaxAllowedSkipRate:
        parsedArgs.argValueAsNumber(_Options.publicMaxAllowedSkipRate),
  );

  exitCode = await runInteractiveCodemodSequence(
    dartPaths,
    [
      RequiredPropsMigrator(recommender),
    ],
    defaultYes: true,
    args: codemodArgs,
    additionalHelpOutput: parser.usage,
  );
}

extension on ArgResults {
  num argValueAsNumber(String name) => num.parse(this[name]);
}

// Copyright 2020 Workiva Inc.
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
import 'package:logging/logging.dart';
import 'package:over_react_codemod/src/ignoreable.dart';
import 'package:over_react_codemod/src/dart2_suggestors/pubspec_over_react_upgrader.dart';
import 'package:over_react_codemod/src/pubspec_suggestors/dependency_override_updater.dart';
import 'package:over_react_codemod/src/react16_suggestors/pubspec_react_upgrader.dart';
import 'package:over_react_codemod/src/util.dart';
import 'package:pub_semver/pub_semver.dart';

const _dependency = 'dependency';
const _range = 'range';
const _isDevDependency = 'dev-dependency';
const _shouldOverride = 'override';
const _overrideSrc = 'src';


const _changesRequiredOutput = """
  To update a dependency in your current project, run the following:
  pub global activate over_react_codemod
  pub global run over_react_codemod:upgrade_dependency
""";

void main(List<String> args) {
  final parser = ArgParser()
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Prints this help output')
    ..addSeparator('Required Options:')
    ..addFlag(_dependency,
        abbr: 'd', negatable: false, help: 'The dependency (i.e. a pubspec.yaml key in `dependencies`) being targeted.')
    ..addFlag(_range,
        abbr: 'r', negatable: false, help: 'The range to update the dependency to. This can be any valid pubspec range. The only time this is not required is when overriding the dependency to a path, git, or hosted src using the `override` and `src` flags.')
    ..addSeparator('Additional Options:')
    ..addOption(_isDevDependency,
        defaultsTo: 'false',
        help: 'Whether the dependency being targeted is a dev dependency.')
    ..addOption(_shouldOverride,
        defaultsTo: 'false',
        help: 'Whether this should add a dependency_override instead of updating the dependency directly.')
    ..addOption(_overrideSrc,
        defaultsTo: 'range',
        help: 'The source of the override details. This defaults to `range`, which means that this will use the provided version range as the override.');

  final parsedArgs = parser.parse(args);

  final logger = Logger('over_react_codemod.update_dependency');

  if (parsedArgs['help'] == true) {
    stderr.writeln(parser.usage);
    return;
  }

  Suggestor finalSuggestorToRun;

  final isOverriding = parsedArgs[_shouldOverride];

  if (isOverriding) {
    finalSuggestorToRun = DependencyOverrideUpdater([]);
  }


  exitCode = runInteractiveCodemod(
    pubspecYamlPaths(),
    AggregateSuggestor([
//      PubspecReactUpdater(reactVersionConstraint, shouldAddDependencies: false),
//      PubspecOverReactUpgrader(overReactVersionConstraint,
//          shouldAddDependencies: false),
    ].map((s) => Ignoreable(s))),
    args: args,
    defaultYes: true,
    changesRequiredOutput: _changesRequiredOutput,
  );
}
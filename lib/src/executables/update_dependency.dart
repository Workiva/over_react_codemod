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
import 'package:over_react_codemod/src/pubspec_suggestors/dependency_override_updater.dart';
import 'package:over_react_codemod/src/pubspec_suggestors/pubspec_upgrader.dart';
import 'package:over_react_codemod/src/react16_suggestors/pubspec_react_upgrader.dart';
import 'package:over_react_codemod/src/util.dart';
import 'package:pub_semver/pub_semver.dart';

const _dependency = 'dependency';
const _version = 'version';
const _isDevDependency = 'dev-dependency';

const _shouldOverride = 'override';
const _overrideSrc = 'src';
const _project = 'project';
const _org = 'org';
const _url = 'url';
const _ref = 'ref';
const _shouldIgnoreMin = 'ignore-min';
const _shouldAddDependencies = 'add-dependency';


const _changesRequiredOutput = """
  To update a dependency in your current project, run the following:
  pub global activate over_react_codemod
  pub global run over_react_codemod:upgrade_dependency
""";

enum OverrideSrc {
  git,
  hosted,
  range,
}

OverrideSrc mapStringToSrc(String src, [Logger logger]) {
  if (src == 'git') {
    return OverrideSrc.git;
  } else if (src == 'hosted') {
    return OverrideSrc.hosted;
  } else {
    if (logger != null && src != null && src != 'range') {
      logger.warning('Invalid src option provided. Returning the default (`range`) instead.');
    }

    return OverrideSrc.range;
  }
}

void main(List<String> args) {
  final parser = ArgParser()
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Prints this help output')
    ..addSeparator('Primary Options:')
    ..addOption(_dependency,
        abbr: 'd',  help: 'The dependency (i.e. a pubspec.yaml key in `dependencies` or `dev_dependencies`) being targeted. This is required.')
    ..addOption(_version,
        abbr: 'v',  help: 'The version range to update the dependency to. This can be any valid pubspec version. The only time this is not required is when overriding the dependency to a git or hosted src using the `override` and `src` options together.')
    ..addFlag(_shouldOverride,
        negatable: false,
        defaultsTo: false,
        abbr: 'o',
        help: 'A flag that defaults to false; whether this should add a dependency_override instead of updating the dependency directly.')
    ..addSeparator('Non-override Options:')
    ..addFlag(_isDevDependency,
        defaultsTo: false,
        negatable: false,
        abbr: 'x',
        help: 'Whether the dependency being targeted is a dev dependency.')
    ..addFlag(_shouldIgnoreMin,
        negatable: false,
        defaultsTo: false,
        abbr: 'i',
        help: 'Whether or not the codemod should ignore the constraint minimum when considering whether to write a patch.')
    ..addFlag(_shouldAddDependencies,
        negatable: false,
        defaultsTo: false,
        abbr: 'a',
        help: 'Whether or not the codemod should add the package if it is not already found.')
    ..addSeparator('Override Options:')
    ..addOption(_overrideSrc,
        abbr: 's',
        defaultsTo: 'range',
        allowed: ['range', 'hosted', 'git'],
        help: 'The source of the override details. This defaults to `range`, which means that this will use the provided version range as the override.')
    ..addOption(_url,
        abbr: 'u',
        help: 'The URL to use for both hosted and git overrides.\n\nHosted dependencies should always set this value.\n\nFor git overrides, the default URL will be: `https://github.com/Workiva/{dependency}.git`. The organization and project values can be set individually via `--org` and `--project`.')
    ..addOption(_ref,
        abbr: 'r',
        help: 'The ref used for a git override.')
    ..addOption(_org,
        abbr: 'w',
        defaultsTo: 'Workiva',
        help: 'The Github organization the repo is found in.')
    ..addOption(_project,
        abbr: 'p',
        help: 'The Github project the repo is found in. This defaults to the dependency name.');

  print('hi');
  print(args);
  print(parser.options);

  final parsedArgs = parser.parse(args);

  final logger = Logger('over_react_codemod.update_dependency');

  if (parsedArgs['help'] == true) {
    stderr.writeln(parser.usage);
    return;
  }

  Suggestor finalSuggestorToRun;

  final isOverriding = parsedArgs[_shouldOverride];

  String constructUrl() => 'https://github.com/${parsedArgs[_org] ?? 'Workiva'}/${parsedArgs[_project] ?? parsedArgs[_dependency]}.git';

  if (isOverriding) {
    final overrideSrc = mapStringToSrc(parsedArgs[_overrideSrc], logger);
    DependencyOverrideConfig config;

    switch(overrideSrc) {
      case OverrideSrc.git:
        config = GitOverrideConfig(
          name: parsedArgs[_dependency],
          ref: parsedArgs[_ref],
          url: parsedArgs[_url] ?? constructUrl(),
        );
        break;
      case OverrideSrc.hosted:
        // TODO: Add hosted support
        break;
      case OverrideSrc.range:
        config = SimpleOverrideConfig(name: parsedArgs[_dependency], version: parsedArgs[_version]);
        break;
    }

    finalSuggestorToRun = DependencyOverrideUpdater([config]);
  } else {
    finalSuggestorToRun = parsedArgs[_shouldIgnoreMin] ? PubspecUpgrader.alwaysUpdate(
        parsedArgs[_dependency],
        VersionConstraint.parse(parsedArgs[_version]),
        isDevDependency: parsedArgs[_isDevDependency],
        shouldAddDependencies: parsedArgs[_shouldAddDependencies],
    ) : PubspecUpgrader(
      parsedArgs[_dependency],
      VersionConstraint.parse(parsedArgs[_version]),
      isDevDependency: parsedArgs[_isDevDependency],
      shouldAddDependencies: parsedArgs[_shouldAddDependencies],
    );
  }


  exitCode = runInteractiveCodemod(
    pubspecYamlPaths(),
    finalSuggestorToRun,
    defaultYes: true,
    args: [],
    changesRequiredOutput: _changesRequiredOutput,
  );
}
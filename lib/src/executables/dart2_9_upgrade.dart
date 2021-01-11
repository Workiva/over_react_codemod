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

import 'package:codemod/codemod.dart';
import 'package:over_react_codemod/src/dart2_9_suggestors/factory_and_config_ignore_comment_remover.dart';
import 'package:over_react_codemod/src/dart2_9_suggestors/generated_factory_migrator.dart';
import 'package:over_react_codemod/src/dart2_suggestors/pubspec_over_react_upgrader.dart';
import 'package:over_react_codemod/src/util.dart';
import 'package:pub_semver/pub_semver.dart';

import '../ignoreable.dart';

const _changesRequiredOutput = """
  To update your code, run the following commands in your repository:
  pub global activate over_react_codemod
  pub global run over_react_codemod:dart2_9_upgrade
  pub run dart_dev format (If you format this repository).
""";

const overReactVersionRange = '^4.1.0';

void main(List<String> args) {
  final overReactVersionConstraint =
      VersionConstraint.parse(overReactVersionRange);

  exitCode = runInteractiveCodemod(
    pubspecYamlPaths(),
    AggregateSuggestor([
      PubspecOverReactUpgrader(overReactVersionConstraint,
          shouldAddDependencies: false),
    ].map((s) => Ignoreable(s))),
    args: args,
    defaultYes: true,
    changesRequiredOutput: _changesRequiredOutput,
  );

  if (exitCode != 0) return;

  exitCode = runInteractiveCodemodSequence(
    allDartPathsExceptHidden(),
    [
      FactoryAndConfigIgnoreCommentRemover('invalid_assignment'),
      FactoryAndConfigIgnoreCommentRemover('argument_type_not_assignable'),
      GeneratedFactoryMigrator(),
    ],
    args: args,
    defaultYes: true,
    changesRequiredOutput: _changesRequiredOutput,
  );
}

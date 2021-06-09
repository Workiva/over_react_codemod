// @dart=2.7
// ^ Do not remove until migrated to null safety. More info at https://wiki.atl.workiva.net/pages/viewpage.action?pageId=189370832
// Copyright 2019 Workiva Inc.
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

import 'package:logging/logging.dart';
import 'package:codemod/codemod.dart';
import 'package:over_react_codemod/src/ignoreable.dart';
import 'package:over_react_codemod/src/react16_suggestors/constants.dart';
import 'package:over_react_codemod/src/react16_suggestors/react16_utilities.dart';
import 'package:over_react_codemod/src/react16_suggestors/react_dom_render_migrator.dart';
import 'package:over_react_codemod/src/react16_suggestors/react_style_maps_updater.dart';
import 'package:over_react_codemod/src/dart2_suggestors/pubspec_over_react_upgrader.dart';
import 'package:over_react_codemod/src/react16_suggestors/pubspec_react_upgrader.dart';
import 'package:over_react_codemod/src/util.dart';
import 'package:pub_semver/pub_semver.dart';

import '../react16_suggestors/constants.dart';

const _changesRequiredOutput = """
  To update your code, run the following commands in your repository:
  pub global activate over_react_codemod
  pub global run over_react_codemod:react16_upgrade
  pub run dart_dev format (if you format this repository).
  Then, review the the changes, address any FIXMEs, and commit.
""";

void main(List<String> args) {
  // Update Pubspec
  final reactVersionConstraint = VersionConstraint.parse(reactVersionRange);
  final overReactVersionConstraint =
      VersionConstraint.parse(overReactVersionRange);

  exitCode = runInteractiveCodemod(
    pubspecYamlPaths(),
    AggregateSuggestor([
      PubspecReactUpdater(reactVersionConstraint, shouldAddDependencies: false),
      PubspecOverReactUpgrader(overReactVersionConstraint,
          // Don't always add this dependency.
          // We often need it for ErrorBoundary, but not in all packages, and
          // we don't want to force over_react to be added regardless.
          // We can just add in the dependency when the codemod imports over_react.
          shouldAddDependencies: false),
    ].map((s) => Ignoreable(s))),
    args: args,
    defaultYes: true,
    changesRequiredOutput: _changesRequiredOutput,
  );

  if (exitCode != 0) {
    return;
  }

  final dartPaths = allDartPathsExceptHiddenAndGenerated();

  // Update Componentry
  exitCode = runInteractiveCodemodSequence(
    dartPaths,
    <Suggestor>[
      ReactDomRenderMigrator(),
      ReactStyleMapsUpdater(),
    ].map((s) => Ignoreable(s)),
    args: args,
    defaultYes: true,
    changesRequiredOutput: _changesRequiredOutput,
  );

  final logger = Logger('over_react_codemod.fixmes');

  if (hasUnaddressedReact16Comment(dartPaths, logger: logger)) {
    exitCode = 1;
  }
}

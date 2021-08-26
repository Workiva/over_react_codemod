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

import 'package:codemod/codemod.dart';
import 'package:over_react_codemod/src/ignoreable.dart';
import 'package:over_react_codemod/src/dart2_suggestors/pubspec_over_react_upgrader.dart';
import 'package:over_react_codemod/src/react16_suggestors/pubspec_react_upgrader.dart';
import 'package:over_react_codemod/src/util.dart';
import 'package:pub_semver/pub_semver.dart';

const _changesRequiredOutput = """
  To update your code, run the following commands in your repository:
  pub global activate over_react_codemod
  pub global run over_react_codemod:react17_upgrade
""";

const reactVersionRange = '>=5.7.0 <7.0.0';
const overReactVersionRange = '>=3.12.0 <5.0.0';

void main(List<String> args) async {
  final reactVersionConstraint = VersionConstraint.parse(reactVersionRange);
  final overReactVersionConstraint =
      VersionConstraint.parse(overReactVersionRange);

  exitCode = await runInteractiveCodemod(
    pubspecYamlPaths(),
    aggregate([
      PubspecReactUpdater(reactVersionConstraint, shouldAddDependencies: false),
      PubspecOverReactUpgrader(overReactVersionConstraint,
          shouldAddDependencies: false),
    ].map((s) => ignoreable(s))),
    args: args,
    defaultYes: true,
    changesRequiredOutput: _changesRequiredOutput,
  );
}

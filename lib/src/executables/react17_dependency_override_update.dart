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
import 'package:over_react_codemod/src/dart2_suggestors/pubspec_over_react_upgrader.dart';
import 'package:over_react_codemod/src/ignoreable.dart';
import 'package:over_react_codemod/src/react16_suggestors/dependency_override_updater.dart';
import 'package:over_react_codemod/src/react16_suggestors/pubspec_react_upgrader.dart';
import 'package:over_react_codemod/src/util.dart';
import 'package:pub_semver/pub_semver.dart';

const _changesRequiredOutput = """
  To update your pubspec, run the following commands:
  pub global activate over_react_codemod
  pub global run over_react_codemod:react17_dependency_override_update
Then, review the the changes and commit.
""";

const reactVersionRangeForTesting = '^6.0.0-alpha';
const overReactVersionRangeForTesting = '^4.0.0-alpha';

void main(List<String> args) {
  final reactConfig = GitOverrideConfig(
    name: 'react',
    url: 'https://github.com/cleandart/react-dart.git',
    ref: '6.0.0-wip',
  );

  final overReactConfig = GitOverrideConfig(
    name: 'over_react',
    url: 'https://github.com/Workiva/over_react.git',
    ref: 'release_over_react_4.0.0',
  );

  exitCode = runInteractiveCodemod(
    pubspecYamlPaths(),
    DependencyOverrideUpdater(
        reactOverrideConfig: reactConfig,
        overReactOverrideConfig: overReactConfig),
    args: args,
    defaultYes: true,
    changesRequiredOutput: _changesRequiredOutput,
  );
}

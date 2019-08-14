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

import 'package:codemod/codemod.dart';
import 'package:over_react_codemod/src/react16_suggestors/pubspec_upgrader.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import '../react16_suggestors/constants.dart';

const _changesRequiredOutput = """
  To update your pubspec, run the following commands:
  pub global activate over_react_codemod ^1.1.0
  pub global run over_react_codemod:react_16_pubspec_upgrade
Then, review the the changes and commit.
""";

void main(List<String> args) {
  final reactVersionConstraint = VersionConstraint.parse(reactVersionRange);

  final pubspecYamlQuery = FileQuery.dir(
    pathFilter: (path) => p.basename(path) == 'pubspec.yaml',
  );

  exitCode = runInteractiveCodemod(
    pubspecYamlQuery,
    PubspecUpdater(reactVersionConstraint),
    args: args,
    defaultYes: true,
    changesRequiredOutput: _changesRequiredOutput,
  );

  if (exitCode > 0) {
    return;
  }
}

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
import 'package:pub_semver/pub_semver.dart';
import 'package:over_react_codemod/src/react16_suggestors/react_16_pubspec_upgrader.dart';
import '../react16_suggestors/constants.dart';

const _changesRequiredOutput = """
  To update your code, change your `react` dependency version in `pubspec.yaml` to `^5.0.0` and run the following commands:
  pub get
  pub global activate over_react_codemod ^1.1.0
  pub global run over_react_codemod:react_16_pubspec_upgrade
Then, review the the changes, address any FIXMEs, and commit.
""";

void main(List<String> args) {
  final reactVersionConstraint = VersionConstraint.parse(reactVersionRange);

  final query = FileQuery.dir(
    pathFilter: isDartFile,
    recursive: true,
  );
  exitCode = runInteractiveCodemodSequence(
    query,
    [
      React16PubspecUpdater(reactVersionConstraint),
    ],
    args: args,
    defaultYes: true,
    changesRequiredOutput: _changesRequiredOutput,
  );
}

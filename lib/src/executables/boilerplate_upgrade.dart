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
import 'package:over_react_codemod/src/boilerplate_suggestors/boilerplate_utilities.dart';
import 'package:over_react_codemod/src/boilerplate_suggestors/props_and_state_classes_migrator.dart';
import 'package:over_react_codemod/src/ignoreable.dart';

const _changesRequiredOutput = """
  To update your code, run the following commands in your repository:
  pub global activate over_react_codemod
  pub global run over_react_codemod:boilerplate_upgrade
  pub run dart_dev format (if you format this repository).
  Then, review the the changes, address any FIXMEs, and commit.
""";

Future<void> main(List<String> args) async {
  final query = FileQuery.dir(
    pathFilter: (path) {
      return isDartFile(path) && !isGeneratedDartFile(path);
    },
    recursive: true,
  );

  SemverHelper helper = SemverHelper();
  await helper.fromReport('/Users/sydneyjodon/Documents/GitHub/over_react_codemod/lib/src/boilerplate_suggestors/test.json');

  exitCode = runInteractiveCodemodSequence(
    query,
    <Suggestor>[
      PropsAndStateClassesMigrator(helper),
    ].map((s) => Ignoreable(s)),
    args: args,
    defaultYes: true,
    changesRequiredOutput: _changesRequiredOutput,
  );
}

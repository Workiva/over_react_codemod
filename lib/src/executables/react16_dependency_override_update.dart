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
import 'package:over_react_codemod/src/ignoreable.dart';
import 'package:over_react_codemod/src/react16_suggestors/dependency_override_updater.dart';
import 'package:path/path.dart' as p;

const _changesRequiredOutput = """
  To update your pubspec, run the following commands:
  pub global activate over_react_codemod
  pub global run over_react_codemod:react16_dependency_override_update
Then, review the the changes and commit.
""";

void main(List<String> args) {
  final pubspecYamlQuery = FileQuery.dir(
    pathFilter: (path) => p.basename(path) == 'pubspec.yaml',
    recursive: true,
  );

  exitCode = runInteractiveCodemod(
    pubspecYamlQuery,
    Ignoreable(DependencyOverrideUpdater()),
    args: args,
    defaultYes: true,
    changesRequiredOutput: _changesRequiredOutput,
  );
}

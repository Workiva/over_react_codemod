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
import 'package:over_react_codemod/src/react16_suggestors/consumer_overlay_migrator.dart';

const _changesRequiredOutput = """
  To update your code, run the following commands in your repository:
  pub global activate over_react_codemod
  pub global run over_react_codemod:react16_consumer_overlays_update
  pub run dart_dev format (If you format this repository).
Then, review the the changes, address any FIXMEs, and commit.
""";

void main(List<String> args) {
  final query = FileQuery.dir(
    pathFilter: isDartFile,
    recursive: true,
  );
  exitCode = runInteractiveCodemodSequence(
    query,
    [
      ConsumerOverlayMigrator(),
    ],
    args: args,
    defaultYes: true,
    changesRequiredOutput: _changesRequiredOutput,
  );
}

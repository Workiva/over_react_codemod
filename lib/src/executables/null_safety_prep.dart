// Copyright 2024 Workiva Inc.
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
import 'package:over_react_codemod/src/dart3_suggestors/null_safety_prep/dom_callback_null_args.dart';
import 'package:over_react_codemod/src/dart3_suggestors/null_safety_prep/fn_prop_null_aware_call_suggestor.dart';
import 'package:over_react_codemod/src/dart3_suggestors/null_safety_prep/use_ref_init_migration.dart';
import 'package:over_react_codemod/src/util.dart';

import '../dart3_suggestors/null_safety_prep/callback_ref_hint_suggestor.dart';

const _changesRequiredOutput = """
  To update your code, run the following commands in your repository:
  pub global activate over_react_codemod
  pub global run over_react_codemod:null_safety_prep
""";

/// Codemods in this executable should be changes that teams
/// can make ahead of moving forward with their null-safety migration.
///
/// Codemods that do things like add nullability "hints" should be placed
/// within `null_safety_migrator_companion` - and run only when a team is
/// ready to move forward with a null-safety migration.
void main(List<String> args) async {
  final parser = ArgParser.allowAnything();

  final parsedArgs = parser.parse(args);
  final dartPaths = allDartPathsExceptHiddenAndGenerated();

  exitCode = await runInteractiveCodemod(
    dartPaths,
    aggregate([
      UseRefInitMigration(),
      FnPropNullAwareCallSuggestor(),
      DomCallbackNullArgs(),
    ]),
    defaultYes: true,
    args: parsedArgs.rest,
    additionalHelpOutput: parser.usage,
    changesRequiredOutput: _changesRequiredOutput,
  );
}

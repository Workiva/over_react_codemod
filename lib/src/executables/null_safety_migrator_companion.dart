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
import 'package:over_react_codemod/src/dart3_suggestors/null_safety_prep/class_component_required_initial_state.dart';
import 'package:over_react_codemod/src/util.dart';

import '../dart3_suggestors/null_safety_prep/callback_ref_hint_suggestor.dart';
import '../dart3_suggestors/null_safety_prep/state_mixin_suggestor.dart';
import '../util/package_util.dart';

const _changesRequiredOutput = """
  To update your code, run the following commands in your repository:
  dart pub global activate over_react_codemod
  dart pub global run over_react_codemod:null_safety_migrator_companion
""";

/// Codemods in this executable add nullability "hints" to assist with a
/// null-safety migration.
///
/// If it has not already been run, the `null_safety_prep` codemod should
/// also be run when migrating to null-safety.
void main(List<String> args) async {
  final parser = ArgParser.allowAnything();

  final parsedArgs = parser.parse(args);
  final packageRoot = findPackageRootFor('.');
  await runPubGetIfNeeded(packageRoot);
  final dartPaths = allDartPathsExceptHiddenAndGenerated();

  exitCode = await runInteractiveCodemodSequence(
    dartPaths,
    [
      CallbackRefHintSuggestor(),
    ],
    defaultYes: true,
    args: parsedArgs.rest,
    additionalHelpOutput: parser.usage,
    changesRequiredOutput: _changesRequiredOutput,
  );

  if (exitCode != 0) return;

  exitCode = await runInteractiveCodemodSequence(
    dartPaths,
    [
      ClassComponentRequiredInitialStateMigrator(),
    ],
    defaultYes: true,
    args: parsedArgs.rest,
    additionalHelpOutput: parser.usage,
    changesRequiredOutput: _changesRequiredOutput,
  );

  if (exitCode != 0) return;

  exitCode = await runInteractiveCodemodSequence(
    dartPaths,
    [
      StateMixinSuggestor(),
    ],
    defaultYes: true,
    args: parsedArgs.rest,
    additionalHelpOutput: parser.usage,
    changesRequiredOutput: _changesRequiredOutput,
  );
}

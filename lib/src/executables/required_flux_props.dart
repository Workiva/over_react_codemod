// Copyright 2023 Workiva Inc.
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
import 'package:logging/logging.dart';
import 'package:over_react_codemod/src/dart3_suggestors/null_safety_prep/required_flux_props.dart';
import 'package:over_react_codemod/src/ignoreable.dart';
import 'package:over_react_codemod/src/util.dart';
import 'package:over_react_codemod/src/util/package_util.dart';

const _changesRequiredOutput = """
  To update your code, run the following commands in your repository:
  pub global activate over_react_codemod
  pub global run over_react_codemod:required_flux_props
""";

final _log = Logger('orcm.required_flux_props');

Future<void> pubGetForAllPackageRoots(Iterable<String> files) async {
  _log.info(
      'Running `pub get` if needed so that all Dart files can be resolved...');
  final packageRoots = files.map(findPackageRootFor).toSet();
  for (final packageRoot in packageRoots) {
    await runPubGetIfNeeded(packageRoot);
  }
}

void main(List<String> args) async {
  final parser = ArgParser.allowAnything();

  final parsedArgs = parser.parse(args);
  final dartPaths = allDartPathsExceptHidden();

  await pubGetForAllPackageRoots(dartPaths);

  exitCode = await runInteractiveCodemod(
    dartPaths,
    aggregate([
      RequiredFluxProps(),
    ].map((s) => ignoreable(s))),
    defaultYes: true,
    args: parsedArgs.rest,
    additionalHelpOutput: parser.usage,
    changesRequiredOutput: _changesRequiredOutput,
  );
}

// Copyright 2021 Workiva Inc.
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
import 'package:glob/glob.dart';
import 'package:logging/logging.dart';
import 'package:over_react_codemod/src/dependency_validator_suggestors/v1_updater.dart';
import 'package:over_react_codemod/src/dependency_validator_suggestors/v2_updater.dart';
import 'package:over_react_codemod/src/util.dart';
import 'package:pub_semver/pub_semver.dart';

const _dependency = 'dependency';

void main(List<String> args) async {
  final parser = ArgParser()
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Prints this help output')
    ..addFlag('verbose',
        abbr: 'v',
        negatable: false,
        help: 'Outputs all logging to stdout/stderr.')
    ..addFlag(
      'yes-to-all',
      negatable: false,
      help: 'Forces all patches accepted without prompting the user. '
          'Useful for scripts.',
    )
    ..addSeparator('Dependency Validator Updater Options')
    ..addOption(_dependency,
        abbr: 'd',
        mandatory: true,
        help: 'The dependency that should be updated.');

  final parsedArgs = parser.parse(args);

  if (parsedArgs['help'] == true) {
    stderr.writeln(parser.usage);
    return;
  }

  final logger = Logger('over_react_codemod.dependency_validator_updater');

  logger.onRecord.listen((rec) {
    // ignore severe messages here because stderr will print it
    if (rec.message.isNotEmpty && rec.level != Level.SEVERE) {
      print('[${rec.level}] ${rec.message}');
    }
    if (rec.error != null) {
      print(rec.error);
    }
    if (rec.stackTrace != null) {
      print(rec.stackTrace);
    }
  });

  final String dependencyToUpdate = parsedArgs[_dependency];
  final rootPubspec = File('pubspec.yaml');
  final VersionRange? dependencyValidatorVersion = getDependencyVersion(
      rootPubspec.readAsStringSync(), 'dependency_validator');
  final majorVersion = dependencyValidatorVersion?.min?.major;

  if (majorVersion == null) {
    exit(0);
  }

  int exitCode = 0;

  logger.info(
      'Detected dependency_validator version $dependencyValidatorVersion');

  switch (majorVersion) {
    case 1:
      exitCode = await runInteractiveCodemod([
        // Run on files because because there isn't a real limit to witch file
        // types may include the command
        ...filePathsFromGlob(Glob('**', recursive: true)),
      ], V1DependencyValidatorUpdater(dependencyToUpdate));
      break;
    case 2:
      exitCode = await runInteractiveCodemod(
          [rootPubspec.path], V2DependencyValidatorUpdater(dependencyToUpdate));
      break;
    case 3:
      break;
    default:
      throw UnsupportedError(
          'Unexpected version for dependency_validator detected: $majorVersion');
  }

  exit(exitCode);
}
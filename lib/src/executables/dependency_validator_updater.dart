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

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:args/args.dart';
import 'package:codemod/codemod.dart';
import 'package:glob/glob.dart';
import 'package:logging/logging.dart';
import 'package:over_react_codemod/src/dart2_9_suggestors/dart2_9_constants.dart';
import 'package:over_react_codemod/src/dart2_9_suggestors/factory_and_config_ignore_comment_remover.dart';
import 'package:over_react_codemod/src/dart2_9_suggestors/factory_config_migrator.dart';
import 'package:over_react_codemod/src/dart2_9_suggestors/generated_factory_migrator.dart';
import 'package:over_react_codemod/src/dart2_9_suggestors/latest_boilerplate_visitor.dart';
import 'package:over_react_codemod/src/dart2_suggestors/pubspec_over_react_upgrader.dart';
import 'package:over_react_codemod/src/util.dart';
import 'package:pub_semver/pub_semver.dart';

import '../ignoreable.dart';

const _dependency = 'check-for-transitioning';
const _changesRequiredOutput = """
  To update your code, run the following commands in your repository:
  pub global activate over_react_codemod
  pub global run over_react_codemod:dart2_9_upgrade
  pub run dart_dev format (If you format this repository).
""";

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
}

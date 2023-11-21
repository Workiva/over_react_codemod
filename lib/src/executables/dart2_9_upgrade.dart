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

const _checkForTransitioning = 'check-for-transitioning';
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
    ..addSeparator('Boilerplate Upgrade Options:')
    ..addFlag(_checkForTransitioning,
        negatable: false,
        help:
            'Checks to see if this repo already has some components using the latest boilerplate and sets'
            'the codemod to fail on changes.');

  final parsedArgs = parser.parse(args);
  final checkForTransitioning = parsedArgs[_checkForTransitioning] ?? false;

  if (parsedArgs['help'] == true) {
    stderr.writeln(parser.usage);
    return;
  }

  final logger = Logger('over_react_codemod.dart2_9_upgrade');

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

  if (checkForTransitioning) {
    logger.info('Checking for the presence of the latest boilerplate...');

    final latestBoilerplateVisitor = LatestBoilerplateVisitor();

    latestBoilerplateVisitor.inspectAllPaths(
      allDartPathsExceptHidden(),
      shortCircuitTest: () =>
          latestBoilerplateVisitor.detectedLatestBoilerplate,
      logger: logger,
    );

    if (!latestBoilerplateVisitor.detectedLatestBoilerplate) {
      logger.info(
          'Did not detect the latest boilerplate. This repo is not transitioning. Exiting codemod.');
      exitCode = 0;
      return;
    } else {
      logger.info(
          'Detected the latest boilerplate. Continuing codemod and setting --fail-on-changes.');
      args.add('--fail-on-changes');
    }
  }

  final overReactVersionConstraint =
      VersionConstraint.parse(overReactVersionRange);

  // If we're checking for transitioning and got to the point (i.e. there was
  // new boilerplate), ignore the pubspec.
  if (!checkForTransitioning) {
    exitCode = await runInteractiveCodemod(
      pubspecYamlPaths(),
      aggregate([
        PubspecOverReactUpgrader(overReactVersionConstraint as VersionRange,
            shouldAddDependencies: false),
      ].map((s) => ignoreable(s))),
      // Only pass valid low level codemod flags
      args: args.where((a) => !a.contains(_checkForTransitioning)),
      defaultYes: true,
      changesRequiredOutput: _changesRequiredOutput,
    );

    if (exitCode != 0) return;
  }

  exitCode = await runInteractiveCodemodSequence(
    allDartPathsExceptHidden(),
    [
      FactoryAndConfigIgnoreCommentRemover('invalid_assignment'),
      FactoryAndConfigIgnoreCommentRemover('argument_type_not_assignable'),
      GeneratedFactoryMigrator(),
      FactoryConfigMigrator(),
    ],
    // Only pass valid low level codemod flags
    args: args.where((a) => !a.contains(_checkForTransitioning)),
    defaultYes: true,
    changesRequiredOutput: _changesRequiredOutput,
  );

  if (checkForTransitioning && exitCode == 1) {
    logger.severe(
        'This repo is transitioning and has both the new factory syntax and the old.');
  }
}

extension on RecursiveAstVisitor {
  /// Iterates over all the files provided and inspects them.
  void inspectAllPaths(Iterable<String> files,
      {bool Function()? shortCircuitTest, required Logger logger}) {
    for (final filePath in files) {
      if (shortCircuitTest?.call() ?? false) continue;

      final file = File(filePath);
      String sourceText;
      ParseStringResult result;

      try {
        sourceText = file.readAsStringSync();
      } catch (e, stack) {
        logger.warning(
            'Failed to read file: ${file.path} - More details: https://wiki.atl.workiva.net/display/FEF/Codemod+Exception+Handling',
            e,
            stack);
        continue;
      }

      try {
        result = parseString(content: sourceText);

        // It's not expected for this catch to be hit frequently. The need to add this
        // arose from over_react's analyzer_plugin invalid code example.
        //
        // Therefore, it seems the best path is to just catch and continue.
      } catch (e, stack) {
        logger.warning('Failed to parse file: ${file.path}', e, stack);
        continue;
      }

      result.unit.accept(this);

      if (shortCircuitTest?.call() ?? false) {
        logger.info(
            'Inspection complete and will now short circuit after inspecting ${file.path}');
      }
    }
  }
}

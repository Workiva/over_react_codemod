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

import 'package:logging/logging.dart';
import 'package:codemod/codemod.dart';
import 'package:over_react_codemod/src/react16_suggestors/constants.dart';
import 'package:over_react_codemod/src/react16_suggestors/react_dom_render_migrator.dart';
import 'package:over_react_codemod/src/react16_suggestors/react_style_maps_updater.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:yaml/yaml.dart';

const _changesRequiredOutput = """
  To update your code, change your `react` dependency version in `pubspec.yaml` to `^5.0.0` and run the following commands:
  pub get
  pub global activate over_react_codemod ^1.1.0
  pub global run over_react_codemod:react16_upgrade
Then, review the the changes, address any FIXMEs, and commit.
""";

const String react16CodemodName = 'React16 Codemod';

YamlMap pubspecYaml;

Map<String, List<VersionConstraint>> packagesToCheckFor = {
  'react': [
    VersionConstraint.parse('^4.0.0'),
    VersionConstraint.parse('^5.0.0')
  ],
  'over_react': [
    VersionConstraint.parse('^2.0.0'),
    VersionConstraint.parse('^3.0.0')
  ]
};

VersionConstraint getDependencyVersion(String packageName) {
  try {
    if (pubspecYaml.containsKey('dependencies') &&
        pubspecYaml['dependencies'].containsKey(packageName)) {
      return VersionConstraint.parse(pubspecYaml['dependencies'][packageName]);
    } else if (pubspecYaml.containsKey('dev_dependencies') &&
        pubspecYaml['dev_dependencies'].containsKey(packageName)) {
      return VersionConstraint.parse(
          pubspecYaml['dev_dependencies'][packageName]);
    }
  } catch (e, st) {
    print(e);
    print(st);
    return null;
  }
  return null;
}

void main(List<String> args) {
  Map<String, bool> inTransition = {};
  bool foundReactOrOverReact = false;

  final react16CodemodLogger = Logger('over_react_codemod.react16');
  react16CodemodLogger.onRecord.listen((rec) {
    // These need to use `print`, not stdio, so that they are picked up properly
    // by the `test` package's custom print handler.
    // Otherwise, these logs interfere with parsing test's JSON output.
    if (rec.message != '') {
      final prefix = '[${rec.level}] ${rec.loggerName}: ';
      print('$prefix${rec.message}');
    }
    if (rec.error != null) {
      print(rec.error.toString());
    }
    if (rec.stackTrace != null) {
      print(rec.stackTrace.toString());
    }
  });
  react16CodemodLogger
      .info('Checking if project needs to run $react16CodemodName...');
  try {
    pubspecYaml = loadYaml(File('pubspec.yaml').readAsStringSync());
  } catch (e, stackTrace) {
    if (e is FileSystemException) {
      react16CodemodLogger.warning(
          'Could not find pubspec.yaml, exiting codemod.', e, stackTrace);
    } else if (e is YamlException) {
      react16CodemodLogger.warning(
          'pubspec.yaml is unable to be parsed, exiting codemod.',
          e,
          stackTrace);
    } else {
      react16CodemodLogger.warning(
          'pubspec.yaml is unable to be parsed, exiting codemod.',
          e,
          stackTrace);
    }
  }
  for (var package in packagesToCheckFor.entries) {
    var constraint = getDependencyVersion(package.key);
    if (constraint != null) {
      foundReactOrOverReact = true;
      react16CodemodLogger
          .info('Found ${package.key} with version ${constraint}');
      // Found it so lets add it to the in transition list to false until its
      // validated that we know it is in transtition.
      inTransition[package.key] = false;
    }
    if (constraint != null &&
        !constraint.isAny &&
        constraint.allowsAny(package.value[0]) &&
        constraint.allowsAny(package.value[1])) {
      inTransition[package.key] = true;
    }
  }
  if (foundReactOrOverReact) {
    if (inTransition.isNotEmpty && inTransition.values.every((val) => val)) {
      react16CodemodLogger.info('Starting $react16CodemodName...');
      final query = FileQuery.dir(
        pathFilter: isDartFile,
        recursive: true,
      );
      exitCode = runInteractiveCodemodSequence(
        query,
        [
          ReactDomRenderMigrator(),
          ReactStyleMapsUpdater(),
        ],
        args: args,
        defaultYes: true,
        changesRequiredOutput: _changesRequiredOutput,
      );

      final logger = Logger('over_react_codemod.fixmes');
      for (var dartFile in query.generateFilePaths()) {
        final dartSource = File(dartFile).readAsStringSync();
        if (dartSource.contains('[ ] $manualValidationCommentSubstring')) {
          logger.severe(
              'over_react_codemod validation comments are unaddressed in $dartFile');
          exitCode = 1;
        }
      }
      react16CodemodLogger.info('Finished Running $react16CodemodName!');
    } else {
      react16CodemodLogger.warning(
          'pubspec.yaml does not have transition versions of react or over_react; exiting codemod.\n' +
              'if you would like to run the react 16 codemod first run ' +
              '`pub global run over_react_codemod:react16_pubspec_upgrade`');
      exitCode = 0;
    }
  } else {
    react16CodemodLogger.warning(
        'Could not find react or over_react in pubspec; exiting codemod.');
    exitCode = 0;
  }
  react16CodemodLogger.info('We are all done here, Byeee!');
}

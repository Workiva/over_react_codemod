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

YamlMap pubspecYaml;

Map packagesToCheckFor = {
  'react': ['^4.0.0', '^5.0.0'],
  'over_react': ['^2.0.0', '^3.0.0']
};

getDependencyVersion(String packageName) {
  if (pubspecYaml.containsKey('dependencies') &&
      pubspecYaml['dependencies'].containsKey(packageName)) {
    return VersionConstraint.parse(pubspecYaml['dependencies'][packageName]);
  } else if (pubspecYaml.containsKey('dev_dependencies') &&
      pubspecYaml['dev_dependencies'].containsKey(packageName)) {
    return VersionConstraint.parse(
        pubspecYaml['dev_dependencies'][packageName]);
  }
  return null;
}

void main(List<String> args) {
  String constraintPackage;
  VersionConstraint constraint;
  final entrylogger = Logger('over_react_codemod.precheck');
  try {
    pubspecYaml = loadYaml(File('pubspec.yaml').readAsStringSync());
  } catch (e) {
    entrylogger.fine('This repo does not have a pubspec.yaml');
    exitCode = 0;
  }
  try {
    for (var package in packagesToCheckFor.entries) {
      constraint = getDependencyVersion(package.key);
      if (constraint != null) {
        constraintPackage = package.key;
        break;
      }
    }
    if (constraint != null) {
      if (!constraint.isAny &&
          constraint.allowsAny(VersionConstraint.parse(
              packagesToCheckFor[constraintPackage][0])) &&
          constraint.allowsAny(VersionConstraint.parse(
              packagesToCheckFor[constraintPackage][1]))) {
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
      } else {
        entrylogger
            .fine('This repo does not appear to be in React 16 transition.');
        exitCode = 0;
      }
    } else {
      entrylogger.fine('This repo does not use React.');
      exitCode = 0;
    }
  } catch (e) {
    entrylogger.fine(e);
    exitCode = 0;
  }
}

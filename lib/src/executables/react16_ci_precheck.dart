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
import 'package:logging/logging.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

final ciLogger = Logger('over_react_codemod.react16_ci_preheck');

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

VersionConstraint getDependencyVersion(
    YamlMap pubspecYaml, String packageName) {
  if (pubspecYaml == null) return null;

  try {
    if (pubspecYaml['dependencies'] != null &&
        pubspecYaml['dependencies'][packageName] != null) {
      return VersionConstraint.parse(pubspecYaml['dependencies'][packageName]);
    } else if (pubspecYaml['dev_dependencies'] != null &&
        pubspecYaml['dev_dependencies'][packageName] != null) {
      return VersionConstraint.parse(
          pubspecYaml['dev_dependencies'][packageName]);
    }
  } catch (e, stackTrace) {
    ciLogger.severe('Unexpected error parsing dependencies.', e, stackTrace);
  }
  return null;
}

const transitionalMessage = 'transitional react/over_react constraints';

void main(List<String> args) {
  ciLogger.onRecord.listen((rec) {
    if (rec.message != '') {
      print('[${rec.level}] ${rec.message}');
    }
    if (rec.error != null) {
      print(rec.error);
    }
    if (rec.stackTrace != null) {
      print(rec.stackTrace);
    }
  });
  ciLogger.info('Checking if project needs to run React 16 codemod...');

  final pubspecYamlQuery = FileQuery.dir(
    pathFilter: (path) => p.basename(path) == 'pubspec.yaml',
    recursive: true,
  );

  List<String> paths;
  try {
    paths = pubspecYamlQuery.generateFilePaths().toList();
  } catch (e, st) {
    ciLogger.severe('Error listing pubspec.yaml files.', e, st);
    return;
  }

  if (paths.isEmpty) {
    ciLogger.warning('No pubspec.yaml files found.'
        '\nThe React 16 codemod should not be run.');
  } else {
    ciLogger.info('Found pubspec.yaml files: $paths');
    if (paths.any(isInTransition)) {
      // If there is any pubspec in transition, set the exit code.
      // We want anyone attempting to be in transition to ensure all of their
      // pubspec.yaml files are also in transition.
      ciLogger.info(
          'At least one pubspec includes transitional react/over_react constraints.'
          '\nThe React 16 codemod should be run.');
      exitCode = 1;
    } else {
      ciLogger.warning(
          'No pubspec.yaml files found that contain transitional react/over_react constraints.'
          '\nThe React 16 codemod should not be run.');
    }
  }
}

bool isInTransition(String pubspecYamlPath) {
  ciLogger.info('Checking $pubspecYamlPath');

  YamlMap pubspecYaml;
  try {
    pubspecYaml = loadYaml(File(pubspecYamlPath).readAsStringSync());
  } catch (e, st) {
    if (e is FileSystemException) {
      ciLogger.severe('Could not read pubspec.yaml.', e);
    } else if (e is YamlException) {
      ciLogger.severe('Could not parse pubspec.yaml.', e, st);
    } else {
      ciLogger.severe('Unexpected error loading pubspec.yaml.', e, st);
    }
    return false;
  }

  final inTransition = <String, bool>{};
  for (var package in packagesToCheckFor.entries) {
    var constraint = getDependencyVersion(pubspecYaml, package.key);
    if (constraint != null) {
      ciLogger.fine('Found ${package.key} with version ${constraint}');
      // Found it so lets add it to the in transition list to false until its
      // validated that we know it is in transtition.
      inTransition[package.key] = (!constraint.isAny &&
          constraint.allowsAny(package.value[0]) &&
          constraint.allowsAny(package.value[1]));
    }
  }
  if (inTransition.isNotEmpty) {
    if (inTransition.values.every((val) => val)) {
      ciLogger
          .info('Pubspec contains transitional react/over_react constraints.');
      return true;
    } else {
      ciLogger.info(
          'Pubspec contains non-transitional react/over_react constraints.'
          ' To run the React 16 codemod, which will add transitional constraints, run:'
          '\n    pub global run over_react_codemod:react16_upgrade');
    }
  } else {
    ciLogger.info('Pubspec does contain react or over_react constraints.');
  }

  return false;
}

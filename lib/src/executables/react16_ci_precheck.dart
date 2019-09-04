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

final ciLogger = Logger('over_react_codemod.react16_ci_check');

const String CI_CHECK_NAME = 'React16 CI Precheck';
const String react16CodemodName = 'React16 Codemod';

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
    ciLogger.warning('Unexpected Error.', e, stackTrace);
  }
  return null;
}

void main(List<String> args) {
  ciLogger.onRecord.listen((rec) {
    if (rec.message != '') {
      final prefix = '[${rec.level}] $CI_CHECK_NAME: ';
      print('$prefix${rec.message}');
    }
    if (rec.error != null) {
      print(rec.error);
    }
    if (rec.stackTrace != null) {
      print(rec.stackTrace);
    }
  });
  ciLogger.info('Checking if project needs to run React16 codemod...');

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
    ciLogger.warning('No pubspec.yaml files found; exiting codemod.');
  } else {
    ciLogger.info('Found pubspec.yaml files:\n'
        '${paths.map((path) => '- $path').join('\n')}');
    if (paths.any(isInTransition)) {
      // If there is any pubspec in transition, set the exit code.
      // We want anyone attempting to be in transition to ensure all of their
      // pubspec.yaml files are also in transition.
      ciLogger.info(
          'At least one pubspec is in transition! The React 16 codemod should run.');
      exitCode = 1;
    } else {
      ciLogger.warning('No pubspec.yaml files are in transition.');
    }
  }

  ciLogger.info('We are all done here, Byeee!');
}

bool isInTransition(String pubspecYamlPath) {
  ciLogger.info('Checking $pubspecYamlPath');

  YamlMap pubspecYaml;
  try {
    pubspecYaml = loadYaml(File(pubspecYamlPath).readAsStringSync());
  } catch (e, stackTrace) {
    if (e is FileSystemException) {
      ciLogger.warning('Could not find pubspec.yaml; exiting codemod.', e);
      return false;
    } else if (e is YamlException) {
      ciLogger.warning('pubspec.yaml is unable to be parsed; exiting codemod.',
          e, stackTrace);
      return false;
    } else {
      ciLogger.warning('pubspec.yaml is unable to be parsed; exiting codemod.',
          e, stackTrace);
      return false;
    }
  }

  final inTransition = <String, bool>{};
  for (var package in packagesToCheckFor.entries) {
    var constraint = getDependencyVersion(pubspecYaml, package.key);
    if (constraint != null) {
      ciLogger.info('Found ${package.key} with version ${constraint}');
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
          .info('Pubspec is in transition! The React 16 codemod should run.');
      return true;
    } else {
      ciLogger.warning(
          'pubspec.yaml does not have transition versions of react or over_react; exiting codemod.\n' +
              'If you would like to run the React 16 codemod, first run ' +
              '`pub global run over_react_codemod:react16_upgrade`');
    }
  } else {
    ciLogger.warning(
        'Could not find react or over_react in pubspec; exiting codemod.');
  }

  return false;
}

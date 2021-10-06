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
import 'package:meta/meta.dart';
import 'package:over_react_codemod/src/dependency_validator_suggestors/ignore_updaters/v1_updater.dart';
import 'package:over_react_codemod/src/dependency_validator_suggestors/ignore_updaters/v2_updater.dart';
import 'package:over_react_codemod/src/dependency_validator_suggestors/ignore_updaters/v3_updater.dart';
import 'package:over_react_codemod/src/util.dart';
import 'package:pub_semver/pub_semver.dart';

/// The flag for the dependency that will be ignored.
const _dependency = 'dependency';

/// Adds an a dependency to the "ignore" section of a dependency validator
/// config.
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
        help: 'The dependency that should be ignored.');

  final parsedArgs = parser.parse(args);

  if (parsedArgs['help'] == true) {
    stderr.writeln(parser.usage);
    return;
  }

  final logger = Logger('over_react_codemod.dependency_validator_ignore');

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

  final dependencyToUpdate = parsedArgs[_dependency] as String;
  final pubspecs = pubspecYamlPaths();

  var exitCode = 0;

  for (final pubspec in pubspecs) {
    final pubspecFile = File(pubspec);
    final VersionRange? dependencyValidatorVersion =
        getNonHostedDependencyVersion(
            pubspecFile.readAsStringSync(), 'dependency_validator');
    final majorVersion = dependencyValidatorVersion?.min?.major;

    // This means that either there is no dependency on `dependency_validator`
    // or the version couldn't be parsed.
    if (majorVersion == null) {
      continue;
    }

    if (exitCode == 1) {
      continue;
    }

    logger.info(
        'Detected dependency_validator version $dependencyValidatorVersion');

    // It is necessary to check the major version and handle each one
    // differently because each major has a different method to identify
    // dependencies to ignore.
    switch (majorVersion) {
      // V1 config docs: https://github.com/Workiva/dependency_validator/blob/9554150b6473a7f822be65c863642b94653ea0d0/README.md
      case 1:
        exitCode = await runInteractiveCodemod([
          ...filePathsFromGlob(Glob('**.yaml', recursive: true)),
          ...filePathsFromGlob(Glob('**.dart', recursive: true)),
          ...filePathsFromGlob(Glob('**.sh', recursive: true)),
          ...filePathsFromGlob(Glob('**.txt', recursive: true)),
          ...filePathsFromGlob(Glob('**Dockerfile', recursive: true)),
        ], V1DependencyValidatorUpdater(dependencyToUpdate));
        break;

      // V2 config docs: https://github.com/Workiva/dependency_validator/blob/40e148b78ccb667c633f9b0e7044da10df18052c/README.md
      case 2:
        exitCode = await runInteractiveCodemod([pubspecFile.path],
            V2DependencyValidatorUpdater(dependencyToUpdate));
        break;

      // V3 config docs: https://github.com/Workiva/dependency_validator/blob/a296309ad75741215d19d2186e71c1a2406507ab/README.md
      case 3:
        final configFiles = [
          ...filePathsFromGlob(Glob('**/dart_dependency_validator.yaml'))
        ];

        if (configFiles.isEmpty) {
          final configFile = File('dart_dependency_validator.yaml');
          configFile.createSync();
          configFiles.add(configFile.path);
        }

        exitCode = await runInteractiveCodemod(
            configFiles, V3DependencyValidatorUpdater(dependencyToUpdate));
        break;
      default:
        throw UnsupportedError(
            'Unexpected version of dependency_validator detected: $majorVersion');
    }
  }

  exit(exitCode);
}

/// Finds a dependency within a pubspec and returns the [VersionRange].
///
/// NOTE: This logic is not very flexible and doesn't work for hosted dependencies.
@visibleForTesting
VersionRange? getNonHostedDependencyVersion(
    String pubspecContent, String dependency) {
  final dependencyValidatorRegex =
      RegExp('^ {2,}$dependency: *(.+)\$', multiLine: true);
  final dependencyMatch = dependencyValidatorRegex.firstMatch(pubspecContent);
  if (dependencyMatch == null) return null;

  final versionString = dependencyMatch.group(1);

  if (versionString == null) return null;

  return parseVersionRange(versionString.replaceAll(RegExp("'|\""), ''));
}

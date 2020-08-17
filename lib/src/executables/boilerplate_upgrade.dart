// Copyright 2020 Workiva Inc.
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
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:over_react_codemod/src/boilerplate_suggestors/annotations_remover.dart';
import 'package:over_react_codemod/src/boilerplate_suggestors/boilerplate_utilities.dart';
import 'package:over_react_codemod/src/boilerplate_suggestors/constants.dart';
import 'package:over_react_codemod/src/boilerplate_suggestors/factory_ignore_comment_mover.dart';
import 'package:over_react_codemod/src/boilerplate_suggestors/props_meta_migrator.dart';
import 'package:over_react_codemod/src/boilerplate_suggestors/simple_props_and_state_class_migrator.dart';
import 'package:over_react_codemod/src/boilerplate_suggestors/advanced_props_and_state_class_migrator.dart';
import 'package:over_react_codemod/src/boilerplate_suggestors/props_mixins_migrator.dart';
import 'package:over_react_codemod/src/boilerplate_suggestors/stubbed_props_and_state_class_remover.dart';
import 'package:over_react_codemod/src/dart2_suggestors/generated_part_directive_ignore_remover.dart';
import 'package:over_react_codemod/src/ignoreable.dart';
import 'package:over_react_codemod/src/util.dart';
import 'package:over_react_codemod/src/util/pubspec_upgrader.dart';
import 'package:prompts/prompts.dart' as prompts;
import 'package:pub_semver/pub_semver.dart';

const _convertedClassesWithExternalSuperclassFlag =
    'convert-classes-with-external-superclasses';
const _treatAllComponentsAsPrivateFlag = 'treat-all-components-as-private';
const _overReactVersionRangeOption = 'over_react-version-range';
const _overReactTestVersionRangeOption = 'over_react_test-version-range';
const _changesRequiredOutput = '''
  To update your code, run the following commands in your repository:
  pub global activate over_react_codemod
  pub global run over_react_codemod:boilerplate_upgrade

  Or you can specify one or more paths or globs to run the codemod on only some files:
  pub global run over_react_codemod:boilerplate_upgrade path/to/your/file.dart another/file.dart
  pub global run over_react_codemod:boilerplate_upgrade lib/**.dart
  
  pub run dart_dev format (if you format this repository).
  Then, review the the changes, address any FIXMEs, and commit.
''';

void main(List<String> args) {
  final parser = ArgParser()
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Prints this help output')
    ..addSeparator('Boilerplate Upgrade Options:')
    ..addFlag(_convertedClassesWithExternalSuperclassFlag,
        help: 'Converts classes with external superclasses')
    ..addFlag(_treatAllComponentsAsPrivateFlag,
        help: 'Treats all components as private')
    ..addSeparator('Dependency Version Updates:')
    ..addOption(_overReactVersionRangeOption,
        defaultsTo: overReactVersionRange,
        help: 'Sets over_react version range')
    ..addOption(_overReactTestVersionRangeOption,
        defaultsTo: overReactTestVersionRange,
        help: 'Sets over_react_test version range');

  final parsedArgs = parser.parse(args);

  final logger = Logger('over_react_codemod.boilerplate_upgrade');

  if (parsedArgs['help'] == true) {
    stderr.writeln(parser.usage);
    return;
  }

  exitCode = upgradeReactVersions(
    overReactVersionRange: parsedArgs[_overReactVersionRangeOption],
    overReactTestVersionRange: parsedArgs[_overReactTestVersionRangeOption],
  );

  if (exitCode != 0) {
    return;
  }

  final convertClassesWithExternalSuperclass =
      parsedArgs[_convertedClassesWithExternalSuperclassFlag] == true;
  final shouldTreatAllComponentsAsPrivate =
      parsedArgs[_treatAllComponentsAsPrivateFlag] == true;

  final pathArgs = parsedArgs.rest.isNotEmpty ? parsedArgs.rest : null;
  // If a path or multiple paths are provided as a basic arg, get file paths for them.
  Iterable<String> filePaths = [];
  if (pathArgs != null) {
    filePaths = pathArgs.toSet();
    logger?.info("Codemod will run on these files: ${filePaths}");
  } else {
    filePaths = allDartPathsExceptHiddenAndGenerated();
    logger?.info(
        "Codemod will run on all Dart files except hidden and generated ones");
  }

  final classToMixinConverter = ClassToMixinConverter();

  final semverHelper = getSemverHelper('semver_report.json',
      shouldTreatAllComponentsAsPrivate: shouldTreatAllComponentsAsPrivate);

  exitCode = runInteractiveCodemodSequence(
    filePaths,
    <Suggestor>[
      // We need this to run first so that the AdvancedPropsAndStateClassMigrator
      // can check for duplicate mixin names before creating one.
      PropsMixinMigrator(classToMixinConverter, semverHelper),
      SimplePropsAndStateClassMigrator(classToMixinConverter, semverHelper),
      AdvancedPropsAndStateClassMigrator(
        classToMixinConverter,
        semverHelper,
        // When we visit these nodes the first time around, we can't assume that
        // they come from an external lib just because they do not
        // appear within `ClassToMixinConverter.visitedClassNames`
        treatUnvisitedClassesAsExternal: false,
      ),
      // NOTE: The convertClassesWithExternalSuperclass is intentionally only set
      // based on the CLI flag value the second time around.
      AdvancedPropsAndStateClassMigrator(
        classToMixinConverter,
        semverHelper,
        convertClassesWithExternalSuperclass:
            convertClassesWithExternalSuperclass,
        // Now that we have visited all of the nodes once, we can assume that
        // they come from an external lib if they do not
        // appear within `ClassToMixinConverter.visitedClassNames`
        treatUnvisitedClassesAsExternal: true,
      ),
      PropsMetaMigrator(classToMixinConverter),
      // Run this last so that the decision about whether to migrate the class is based on
      // the final migrated / un-migrated state of the class after the simple/advanced class
      // migrators have finished, but before the annotations are removed.
      StubbedPropsAndStateClassRemover(classToMixinConverter),
      AnnotationsRemover(classToMixinConverter),
      GeneratedPartDirectiveIgnoreRemover(),
      FactoryIgnoreCommentMover(),
    ].map((s) => Ignoreable(s)),
    defaultYes: true,
    args: [],
    changesRequiredOutput: _changesRequiredOutput,
  );

  if (semverHelper.warning != null) {
    logger?.warning(
        '${semverHelper.warning} Assuming all components are public and thus will not be migrated.');
    exitCode = 1;
  }
}

int upgradeReactVersions({
  @required String overReactVersionRange,
  @required String overReactTestVersionRange,
}) {
  var ranges = {
    'over_react': overReactVersionRange,
    'over_react_test': overReactTestVersionRange,
    'workiva_analysis_options': '^1.1.0',
  };
  final isDev = {
    'over_react': false,
    'over_react_test': true,
    'workiva_analysis_options': true,
  };
  assert(UnorderedIterableEquality().equals(ranges.keys, isDev.keys));

  print('\n\nAbout to set dependency ranges:');
  print(ranges.entries
      .map((entry) => '- ${entry.key}: ${entry.value}')
      .join('\n'));

  final useDefaultRanges =
      prompts.getBool('Are these ranges correct?', defaultsTo: true);
  if (!useDefaultRanges) {
    ranges = ranges.map((name, range) {
      final newRange = prompts.get('$name version range', defaultsTo: range);
      return MapEntry(name, newRange);
    });
  }

  return runInteractiveCodemod(
    pubspecYamlPaths(),
    AggregateSuggestor(ranges.entries
        .map((entry) => PubspecUpgrader(
              entry.key,
              VersionConstraint.parse(entry.value),
              shouldAddDependencies: false,
              isDevDependency: isDev[entry.key],
            ))
        .map((s) => Ignoreable(s))),
    args: [],
    defaultYes: true,
    changesRequiredOutput: _changesRequiredOutput,
  );
}

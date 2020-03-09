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

import 'package:codemod/codemod.dart';
import 'package:logging/logging.dart';
import 'package:over_react_codemod/src/boilerplate_suggestors/annotations_remover.dart';
import 'package:over_react_codemod/src/boilerplate_suggestors/boilerplate_utilities.dart';
import 'package:over_react_codemod/src/boilerplate_suggestors/props_meta_migrator.dart';
import 'package:over_react_codemod/src/boilerplate_suggestors/simple_props_and_state_class_migrator.dart';
import 'package:over_react_codemod/src/boilerplate_suggestors/advanced_props_and_state_class_migrator.dart';
import 'package:over_react_codemod/src/boilerplate_suggestors/props_mixins_migrator.dart';
import 'package:over_react_codemod/src/boilerplate_suggestors/stubbed_props_and_state_class_remover.dart';
import 'package:over_react_codemod/src/ignoreable.dart';

const _convertedClassesWithExternalSuperclassFlag =
    '--convert-classes-with-external-superclasses';
const _treatAllComponentsAsPrivateFlag = '--treat-all-components-as-private';
const _changesRequiredOutput = '''
  To update your code, run the following commands in your repository:
  pub global activate over_react_codemod
  pub global run over_react_codemod:boilerplate_upgrade
  pub run dart_dev format (if you format this repository).
  Then, review the the changes, address any FIXMEs, and commit.
''';

void main(List<String> args) {
  final logger = Logger('over_react_codemod.boilerplate_upgrade');

  final convertClassesWithExternalSuperclass =
      args.contains(_convertedClassesWithExternalSuperclassFlag);
  args.removeWhere((arg) => arg == _convertedClassesWithExternalSuperclassFlag);

  final shouldTreatAllComponentsAsPrivate =
      args.contains(_treatAllComponentsAsPrivateFlag);
  args.removeWhere((arg) => arg == _treatAllComponentsAsPrivateFlag);

  final query = FileQuery.dir(
    pathFilter: (path) {
      return isDartFile(path) && !isGeneratedDartFile(path);
    },
    recursive: true,
  );

  final classToMixinConverter = ClassToMixinConverter();

  final semverHelper = getSemverHelper('semver_report.json',
      shouldTreatAllComponentsAsPrivate: shouldTreatAllComponentsAsPrivate);

  exitCode = runInteractiveCodemodSequence(
    query,
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
    ].map((s) => Ignoreable(s)),
    args: args,
    defaultYes: true,
    changesRequiredOutput: _changesRequiredOutput,
  );

  if (semverHelper.warning != null) {
    logger?.warning(
        '${semverHelper.warning} Assuming all components are public and thus will not be migrated.');
    exitCode = 1;
  }
}

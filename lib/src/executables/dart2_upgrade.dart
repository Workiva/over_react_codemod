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

import 'package:args/args.dart';
import 'package:codemod/codemod.dart';
import 'package:path/path.dart' as p;

import '../dart2_suggestors/component_default_props_migrator.dart';
import '../dart2_suggestors/dollar_prop_keys_migrator.dart';
import '../dart2_suggestors/dollar_props_migrator.dart';
import '../dart2_suggestors/needs_over_react_library_collector.dart';
import '../dart2_suggestors/orcm_ignore_remover.dart';
import '../dart2_suggestors/generated_part_directive_adder.dart';
import '../dart2_suggestors/generated_part_directive_ignore_remover.dart';
import '../dart2_suggestors/props_and_state_classes_renamer.dart';
import '../dart2_suggestors/props_and_state_companion_class_adder.dart';
import '../dart2_suggestors/props_and_state_companion_class_remover.dart';
import '../dart2_suggestors/props_and_state_mixin_meta_adder.dart';
import '../dart2_suggestors/props_and_state_mixin_meta_remover.dart';
import '../dart2_suggestors/props_and_state_mixin_usage_consolidator.dart';
import '../dart2_suggestors/props_and_state_mixin_usage_doubler.dart';
import '../dart2_suggestors/pubspec_over_react_upgrader.dart';
import '../dart2_suggestors/ui_factory_ignore_comment_remover.dart';
import '../dart2_suggestors/ui_factory_initializer.dart';
import '../ignoreable.dart';
import '../util.dart';

const _backwardsCompatFlag = '--backwards-compat';
const _helpFlag = '--help';
const _helpFlagAbbr = '-h';
const _changesRequiredOutput = """
To update your code, switch to Dart 2.1.0 and run the following commands:
  pub global activate over_react_codemod ^1.0.1
  pub global run over_react_codemod:dart2_upgrade --backwards-compat
Then, review and commit the changes.
""";

void main(List<String> args) {
  // Whether or not backwards-compatibility (with Dart 1) is desired will
  // determine the set of suggestors that are run and how they are configured.
  final backwardsCompat = args.contains(_backwardsCompatFlag);
  args.removeWhere((arg) => arg == _backwardsCompatFlag);

  // Parse the --comment-prefix option if present. This also removes those
  // options from the args list so that they don't cause a parsing error within
  // [runInteractiveCodemodSequence].
  final commentPrefix = parseAndRemoveCommentPrefixArg(args);

  // Phase 1: Upgrade the over_react dependency in any `pubspec.yaml` files.
  final pubspecYamlQuery = FileQuery.dir(
    pathFilter: (path) => p.basename(path) == 'pubspec.yaml',
  );
  exitCode = runInteractiveCodemod(
    pubspecYamlQuery,
    PubspecOverReactUpgrader(
      backwardsCompat
          ? PubspecOverReactUpgrader.dart1And2Constraint
          : PubspecOverReactUpgrader.dart2Constraint,
    ),
    args: args,
    defaultYes: true,
    additionalHelpOutput: argParser.usage,
    changesRequiredOutput: _changesRequiredOutput,
  );

  if (exitCode > 0 ||
      args.contains(_helpFlag) ||
      args.contains(_helpFlagAbbr)) {
    return;
  }

  final needsOverReactLibraryCollector = NeedsOverReactLibraryCollector();
  final phaseTwoSuggestors = <Suggestor>[
    needsOverReactLibraryCollector,
    UiFactoryInitializer(includeIgnore: backwardsCompat),
    ComponentDefaultPropsMigrator(),
    DollarPropsMigrator(),
    DollarPropKeysMigrator(),
    PropsAndStateClassesRenamer(renameMixins: !backwardsCompat),
  ]..addAll(backwardsCompat
      ? [
          PropsAndStateCompanionClassAdder(commentPrefix: commentPrefix),
          PropsAndStateMixinMetaAdder(),
          PropsAndStateMixinUsageDoubler(),
        ]
      : [
          UiFactoryIgnoreCommentRemover(),
          PropsAndStateMixinMetaRemover(),
          PropsAndStateMixinUsageConsolidator(),
          GeneratedPartDirectiveIgnoreRemover(),
          OrcmIgnoreRemover(),
        ]);

  final phaseThreeSuggestors = <Suggestor>[
    Ignoreable(
      GeneratedPartDirectiveAdder(
        needsOverReactLibraryCollector,
      ),
    ),
  ];
  if (!backwardsCompat) {
    phaseThreeSuggestors.add(PropsAndStateCompanionClassRemover());
  }

  exitCode = runInteractiveCodemodSequence(
    FileQuery.dir(
      pathFilter: isDartFile,
      recursive: true,
    ),
    [
      AggregateSuggestor(
        phaseTwoSuggestors.map((s) => Ignoreable(s)),
      ),
      AggregateSuggestor(
        phaseThreeSuggestors.map((s) => Ignoreable(s)),
      )
    ],
    args: args,
    defaultYes: true,
    changesRequiredOutput: _changesRequiredOutput,
  );
}

final argParser = ArgParser()
  ..addFlag(
    'backwards-compat',
    negatable: false,
    help: 'Maintain backwards-compatibility with Dart 1.',
  );

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

import '../ignoreable.dart';
import 'suggestors/component_default_props_migrator.dart';
import 'suggestors/dollar_prop_keys_migrator.dart';
import 'suggestors/dollar_props_migrator.dart';
import 'suggestors/needs_over_react_library_collector.dart';
import 'suggestors/over_react_generated_part_directive_adder.dart';
import 'suggestors/props_and_state_classes_renamer.dart';
import 'suggestors/props_and_state_companion_class_adder.dart';
import 'suggestors/props_and_state_mixin_meta_adder.dart';
import 'suggestors/props_and_state_mixin_usage_updater.dart';
import 'suggestors/pubspec_over_react_upgrader.dart';
import 'suggestors/ui_factory_initializer.dart';

final _commentPrefixParser = ArgParser()..addOption('comment-prefix');

void main(List<String> args) {
  // Parse the --comment-prefix option if present. This also removes those
  // options from the args list so that they don't cause a parsing error within
  // [runInteractiveCodemodSequence].
  final commentPrefixArgs = <String>[];
  for (var i = 0; i < args.length; i++) {
    if (args[i].startsWith('--comment-prefix')) {
      if (args[i].contains('=')) {
        commentPrefixArgs.add(args[i]);
        args.removeAt(i);
      } else if (i + 1 < args.length) {
        commentPrefixArgs..add(args[i])..add(args[i + 1]);
        args..removeAt(i)..removeAt(i + 1);
      }
      break;
    }
  }

  var commentPrefix;
  if (commentPrefixArgs.isNotEmpty) {
    final parsedCommentPrefixArgs =
        _commentPrefixParser.parse(commentPrefixArgs);
    commentPrefix = parsedCommentPrefixArgs['comment-prefix'];
  }

  // Phase 1: Upgrade the over_react dependency in any `pubspec.yaml` files.
  final pubspecYamlQuery = FileQuery.dir(
    pathFilter: (path) => p.basename(path) == 'pubspec.yaml',
  );
  exitCode = runInteractiveCodemod(
    pubspecYamlQuery,
    PubspecOverReactUpgrader(),
    args: args,
    defaultYes: true,
  );

  if (exitCode > 0) {
    return;
  }

  final dartFileQuery = FileQuery.dir(
    pathFilter: isDartFile,
    recursive: true,
  );
  final needsOverReactLibraryCollector = NeedsOverReactLibraryCollector();

  exitCode = runInteractiveCodemodSequence(
    dartFileQuery,
    [
      // Phase 2: All single-file codemods and the library collector that needs a
      // full pass over all files before [AddOverReactGeneratedPartDirectiveSuggestor]
      // can run successfully.
      AggregateSuggestor([
        needsOverReactLibraryCollector,
        Ignoreable(UiFactoryInitializer()),
        Ignoreable(PropsAndStateClassesRenamer()),
        Ignoreable(
            PropsAndStateCompanionClassAdder(commentPrefix: commentPrefix)),
        Ignoreable(PropsAndStateMixinMetaAdder()),
        Ignoreable(PropsAndStateMixinUsageUpdater()),
        Ignoreable(ComponentDefaultPropsMigrator()),
        Ignoreable(DollarPropKeysMigrator()),
        Ignoreable(DollarPropsMigrator()),
      ]),
      // Phase 3: just the generated part directive suggestor which needed the
      // library collector from phase 1 to determine which files need it.
      Ignoreable(
          OverReactGeneratedPartDirectiveAdder(needsOverReactLibraryCollector)),
    ],
    args: args,
    defaultYes: true,
  );
}

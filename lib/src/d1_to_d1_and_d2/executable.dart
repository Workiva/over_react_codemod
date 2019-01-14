import 'dart:io';

import 'package:codemod/codemod.dart';

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
import 'suggestors/ui_factory_initializer.dart';

void main(List<String> args) {
  // Parse the --comment-prefix option if present. This also removes those
  // options from the args list so that they don't cause a parsing error within
  // [runInteractiveCodemodSequence].
  var commentPrefix;
  for (var i = 0; i < args.length; i++) {
    if (args[i].startsWith('--comment-prefix')) {
      if (args[i].contains('=')) {
        commentPrefix = args[i].split('=')[1];
        args.removeAt(i);
      } else if (i + 1 < args.length) {
        commentPrefix = args[i + 1];
        args..removeAt(i)..removeAt(i + 1);
      }
      break;
    }
  }

  final query = FileQuery.dir(
    pathFilter: isDartFile,
    recursive: true,
  );
  final needsOverReactLibraryCollector = NeedsOverReactLibraryCollector();

  exitCode = runInteractiveCodemodSequence(
    query,
    [
      // Phase 1: All single-file codemods and the library collector that needs a
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
      // Phase 2: just the generated part directive suggestor which needed the
      // library collector from phase 1 to determine which files need it.
      Ignoreable(
          OverReactGeneratedPartDirectiveAdder(needsOverReactLibraryCollector)),
    ],
    args: args,
    defaultYes: true,
  );
}

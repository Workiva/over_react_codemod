import 'package:codemod/codemod.dart';

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
  final needsOverReactLibraryCollector = NeedsOverReactLibraryCollector();
  runInteractiveCodemodSequence(
    FileQuery.cwd(
      pathFilter: isDartFile,
      recursive: true,
    ),
    [
      // Phase 1: All single-file codemods and the library collector that needs
      // a full pass over all files before [AddOverReactGeneratedPartDirectiveSuggestor]
      // can run successfully.
      AggregateSuggestor([
        needsOverReactLibraryCollector,
        UiFactoryInitializer(),
        PropsAndStateClassesRenamer(),
        PropsAndStateCompanionClassAdder(),
        PropsAndStateMixinMetaAdder(),
        PropsAndStateMixinUsageUpdater(),
        ComponentDefaultPropsMigrator(),
        DollarPropKeysMigrator(),
        DollarPropsMigrator(),
      ]),
      // Phase 2: just the generated part directive suggestor which needed the
      // library collector from phase 1 to determine which files need it.
      OverReactGeneratedPartDirectiveAdder(needsOverReactLibraryCollector),
    ],
    args: args,
  );
}

import 'package:over_react_codemod/src/mui_suggestors/constants.dart';
import 'package:over_react_codemod/src/mui_suggestors/mui_button_migrator.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:over_react_codemod/src/util/component_usage_migrator.dart';

class MuiButtonGroupMigrator extends Object
    with ClassSuggestor, ComponentUsageMigrator, ButtonDisplayPropsMigrator {
  @override
  MigrationDecision shouldMigrateUsage(FluentComponentUsage usage) =>
      usesWsdFactory(usage, 'ButtonGroup')
          ? MigrationDecision.shouldMigrate
          : MigrationDecision.notApplicable;

  @override
  void migrateUsage(FluentComponentUsage usage) {
    super.migrateUsage(usage);

    yieldPatchOverNode('$muiNs.ButtonGroup', usage.factory!);

    migratePropsByName(usage, migratorsByName: {
      'isJustified': (p) {
        yieldPropPatch(p, newName: 'fullWidth');
      },
      'isVertical': (p) {
        yieldPropPatch(p, newName: 'orientation', newRhs: "'vertical'");
      },
      'size': migrateButtonSize,
    });
  }
}

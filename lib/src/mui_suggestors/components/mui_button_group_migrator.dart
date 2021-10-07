import 'package:over_react_codemod/src/mui_suggestors/constants.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:over_react_codemod/src/util/component_usage_migrator.dart';

class MuiButtonGroupMigrator with ClassSuggestor, ComponentUsageMigrator {
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
      'size': migrateSize,
    });
  }

  void migrateSize(PropAssignment prop) {
    final sizeFromWsdSize = mapWsdConstant(prop.rightHandSide, const {
      'ButtonGroupSize.XXSMALL': '$muiNs.ButtonSize.xxsmall',
      'ButtonGroupSize.XSMALL': '$muiNs.ButtonSize.xsmall',
      'ButtonGroupSize.SMALL': '$muiNs.ButtonSize.small',
      'ButtonGroupSize.DEFAULT': '$muiNs.ButtonSize.medium',
      'ButtonGroupSize.LARGE': '$muiNs.ButtonSize.large',
    });
    if (sizeFromWsdSize != null) {
      yieldPropPatch(prop, newRhs: sizeFromWsdSize);
      return;
    }

    yieldPropManualMigratePatch(prop);
  }
}

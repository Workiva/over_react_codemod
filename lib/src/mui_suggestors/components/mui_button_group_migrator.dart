import 'package:analyzer/dart/ast/ast.dart';
import 'package:over_react_codemod/src/mui_suggestors/constants.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:over_react_codemod/src/util/component_usage_migrator.dart';

class MuiButtonGroupMigrator with ClassSuggestor, ComponentUsageMigrator {
  @override
  ShouldMigrateDecision shouldMigrateUsage(FluentComponentUsage usage) =>
      usesWsdFactory(usage, 'ButtonGroup')
          ? ShouldMigrateDecision.yes
          : ShouldMigrateDecision.no;

  @override
  void migrateUsage(FluentComponentUsage usage) {
    super.migrateUsage(usage);

    yieldPatchOverNode('$muiNs.ButtonGroup', usage.factory!);

    handleCascadedPropsByName(usage, {
      'isJustified': (p) => yieldPropPatch(p, newName: 'fullWidth'),
      'isVertical': migrateIsVertical,
      'size': migrateSize,
    });
  }

  void migrateIsVertical(PropAssignment prop) {
    const horizontalOrientation = "$muiNs.ButtonGroupOrientation.horizontal";
    const verticalOrientation = "$muiNs.ButtonGroupOrientation.vertical";

    final rhs = prop.rightHandSide;
    if (rhs is BooleanLiteral) {
      yieldPropPatch(prop,
          newName: 'orientation',
          newRhs: rhs.value ? verticalOrientation : horizontalOrientation);
    } else {
      // Change
      //     ..isVertical = expression
      // to
      //     ..orientation = expression ? mui.ButtonGroupOrientation.vertical : mui.ButtonGroupOrientation.horizontal
      yieldPropPatch(prop, newName: 'orientation');
      yieldInsertionPatch(
          ' ? $verticalOrientation : $horizontalOrientation', rhs.end);
    }
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

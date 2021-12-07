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

import 'package:analyzer/dart/ast/ast.dart';
import 'package:over_react_codemod/src/mui_suggestors/components/chip/shared.dart';
import 'package:over_react_codemod/src/mui_suggestors/components/shared_props_migrators/color_props.dart';
import 'package:over_react_codemod/src/mui_suggestors/components/shared_props_migrators/hit_area.dart';
import 'package:over_react_codemod/src/mui_suggestors/constants.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:over_react_codemod/src/util/component_usage_migrator.dart';

import '../mui_migrator.dart';

class BadgeToMuiChipMigrator extends ComponentUsageMigrator
    with
        MuiMigrator,
        ChipDisplayPropsMigrator,
        MuiChipPropsMigrator,
        HitAreaPropMigrators,
        ColorPropMigrators {
  @override
  bool shouldMigrateUsage(FluentComponentUsage usage) =>
      usesWsdFactory(usage, 'Badge');

  @override
  void migrateUsage(FluentComponentUsage usage) {
    super.migrateUsage(usage);

    yieldPatchOverNode('$muiNs.Chip', usage.factory!);
    migrateChildrenToLabelProp(usage);

    handleCascadedPropsByName(usage, {
      'align': migrateBadgeAlignProp,
      'backgroundColor': (p) => migrateColorPropsBackgroundColor(usage, p),
      'borderColor': yieldUseSxFixmePatch,
      'isDisabled': (p) {
        yieldPropFixmePatch(p,
            'if this badge has mouse handlers that should fire when disabled or needs to show a tooltip/overlay when disabled, add a wrapper element');
        yieldPropPatch(p, newName: 'disabled');
      },
      'isOutline': (p) => migrateBadgeOutlineProp(usage, p),
      'textColor': yieldUseSxFixmePatch,

      // HitArea Props
      'allowedHandlersWhenDisabled': yieldPropManualMigratePatch,
      'role': (p) => yieldPropPatch(p, newName: 'dom.role'),
      'target': (p) => yieldPropPatch(p, newName: 'dom.target'),
      'type': (p) => yieldPropPatch(p, newName: 'dom.type'),
    });

    migrateTooltipProps(usage);
    yieldAddPropPatch(usage, '..variant = $muiNs.ChipVariant.wsdBadge');
  }
}

mixin ChipDisplayPropsMigrator on ComponentUsageMigrator {
  void migrateBadgeOutlineProp(
      FluentComponentUsage usage, PropAssignment prop) {
    final rhs = prop.rightHandSide;

    if (usage.cascadedProps
        .any((prop) => prop.name.name == 'backgroundColor')) {
      yieldUsageFixmePatch(usage,
          'Both `isOutline` and `backgroundColor` attempt to set the `color` prop. This should be manually verified.');
    }

    if (rhs is BooleanLiteral) {
      if (rhs.value) {
        yieldPropPatch(prop,
            newName: 'color', newRhs: '$muiNs.ChipColor.wsdBadgeOutlined');
      } else {
        yieldRemovePropPatch(prop);
      }
    } else {
      // Change
      //     ..isOutline = expression
      // to
      //     ..color = expression ? mui.ChipColor.wsdBadgeOutlined : mui.ChipColor.default_
      yieldPropPatch(prop, newName: 'color');
      yieldInsertionPatch(
          ' ? $muiNs.ChipColor.wsdBadgeOutlined : $muiNs.ChipColor.default_',
          rhs.end);
    }
  }

  void migrateBadgeAlignProp(PropAssignment prop) {
    final rhs = prop.rightHandSide;
    String? message;

    message = mapWsdConstant(rhs, const {
      'BadgeAlign.LEFT':
          'Manually verify. BadgeAlign.LEFT is the default and may be able to be removed. Otherwise, `sx` can be used like so: ..sx = {\'marginRight\': (mui.Theme theme) => mui.themeSpacingAsRem(.5, theme)}',
      'BadgeAlign.RIGHT':
          'Instead of align, move the badge to be after its siblings and add `sx` like so: ..sx = {\'marginLeft\': (mui.Theme theme) => mui.themeSpacingAsRem(.5, theme), \'mr\': 0}',
      'BadgeAlign.PULL_RIGHT':
          'Instead of align, move the badge to be after its siblings and add `sx` like so: ..sx = {\'float\': \'right\', \'mr\': 0}',
      'BadgeAlign.PULL_LEFT':
          'Instead of align, `sx` can be used like so: ..sx = {\'float\': \'left\', \'mr\': 0}',
    });

    if (message == null) {
      message = 'Cannot migrate the `align` prop. Use `sx` instead.';
    }

    yieldPropFixmePatch(prop, message);
  }
}

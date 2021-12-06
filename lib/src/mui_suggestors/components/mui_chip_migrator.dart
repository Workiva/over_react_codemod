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
import 'package:collection/collection.dart';
import 'package:over_react_codemod/src/mui_suggestors/components/utils/hit_area.dart';
import 'package:over_react_codemod/src/mui_suggestors/constants.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:over_react_codemod/src/util/component_usage_migrator.dart';
import 'package:over_react_codemod/src/util.dart';

import 'mui_migrator.dart';

class MuiChipMigrator extends ComponentUsageMigrator
    with MuiMigrator, ChipDisplayPropsMigrator, HitAreaPropsMigrators {
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
      'backgroundColor': (p) => migrateBadgeAndLabelBackgroundColor(usage, p),
      'borderColor': yieldPropManualMigratePatch,
      'isDisabled': (p) {
        yieldPropFixmePatch(p,
            'if this badge has mouse handlers that should fire when disabled or needs to show a tooltip/overlay when disabled, add a wrapper element');
        yieldPropPatch(p, newName: 'disabled');
      },
      'isOutline': (p) => migrateBadgeOutlineProp(usage, p),
      'textColor': yieldPropManualMigratePatch,

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

  void migrateBadgeAndLabelBackgroundColor(
      FluentComponentUsage usage, PropAssignment prop) {
    final rhs = prop.rightHandSide;

    const docTypeColors = [
      'BackgroundColor.DOC_TYPE_BLUE',
      'BackgroundColor.DOC_TYPE_LIGHT_BLUE',
      'BackgroundColor.DOC_TYPE_TEAL',
      'BackgroundColor.DOC_TYPE_GRAY',
      'BackgroundColor.DOC_TYPE_RED',
      'BackgroundColor.DOC_TYPE_GREEN',
      'BackgroundColor.DOC_TYPE_PURPLE',
      'BackgroundColor.DOC_TYPE_ORANGE',
    ];

    // Verify that a badge is not being set to a DOC_TYPE color.
    //
    // This may happen because a WSD badge _could_ be set to a DOC_TYPE color and
    // the badge would be styled. However, with a MUI chip, the component
    // will not have a background color at all.
    if (usesWsdFactory(usage, 'Badge') &&
        docTypeColors.any((constant) => isWsdStaticConstant(rhs, constant))) {
      yieldPropFixmePatch(prop,
          'A MUI chip with the badge variant cannot be set to a DOC_TYPE color. Use the `sx` prop and theme palette instead.');
      return;
    }

    final colorFromWsdBackgroundColor = mapWsdConstant(rhs, const {
      'BackgroundColor.DANGER': '$muiNs.ChipColor.error',
      'BackgroundColor.ALTERNATE': '$muiNs.ChipColor.secondary',
      'BackgroundColor.DEFAULT': '$muiNs.ChipColor.inherit',
      'BackgroundColor.SUCCESS': '$muiNs.ChipColor.success',
      'BackgroundColor.WARNING': '$muiNs.ChipColor.warning',
      'BackgroundColor.DOC_TYPE_BLUE': '$muiNs.ChipColor.wsdLabelBlue',
      'BackgroundColor.DOC_TYPE_LIGHT_BLUE':
          '$muiNs.ChipColor.wsdLabelLightBlue',
      'BackgroundColor.DOC_TYPE_TEAL': '$muiNs.ChipColor.wsdLabelTeal',
      'BackgroundColor.DOC_TYPE_GRAY': '$muiNs.ChipColor.wsdLabelGray',
      'BackgroundColor.DOC_TYPE_RED': '$muiNs.ChipColor.wsdLabelRed',
      'BackgroundColor.DOC_TYPE_GREEN': '$muiNs.ChipColor.wsdLabelGreen',
      'BackgroundColor.DOC_TYPE_PURPLE': '$muiNs.ChipColor.wsdLabelPurple',
      'BackgroundColor.DOC_TYPE_ORANGE': '$muiNs.ChipColor.wsdLabelOrange',
    });

    if (colorFromWsdBackgroundColor != null) {
      yieldPropPatch(
        prop,
        newName: 'color',
        newRhs: colorFromWsdBackgroundColor,
      );
      return;
    }

    /// A list of background colors that have a RMUI counterpart
    ///
    /// Note that GREEN_ALT and GREEN_ALT_2 are excluded because their hexcodes
    /// are not attached to a publicly exported palette value.
    const mappableZestyCrayonColors = [
      'BackgroundColor.GREEN',
      'BackgroundColor.BLUE',
      'BackgroundColor.ORANGE',
      'BackgroundColor.RED',
      'BackgroundColor.GRAY'
    ];

    if (mappableZestyCrayonColors
        .any((constant) => isWsdStaticConstant(rhs, constant))) {
      yieldRemovePropPatch(prop);
      const colorToSxMapping = {
        'BackgroundColor.GREEN':
            "..sx = {'backgroundColor': ($muiNs.Theme theme) => theme.palette.green.main, 'color': ($muiNs.Theme theme) => theme.palette.common.white,}",
        'BackgroundColor.BLUE':
            "..sx = {'backgroundColor': ($muiNs.Theme theme) => theme.palette.blue.main, 'color': ($muiNs.Theme theme) => theme.palette.common.white,}",
        'BackgroundColor.ORANGE':
            "..sx = {'backgroundColor': ($muiNs.Theme theme) => theme.palette.orange.main, 'color': ($muiNs.Theme theme) => theme.palette.common.white,}",
        'BackgroundColor.RED':
            "..sx = {'backgroundColor': ($muiNs.Theme theme) => theme.palette.red.main, 'color': ($muiNs.Theme theme) => theme.palette.common.white,}",
        'BackgroundColor.GRAY':
            "..sx = {'backgroundColor': ($muiNs.Theme theme) => theme.palette.gray.main, 'color': ($muiNs.Theme theme) => theme.palette.common.white,}",
      };

      // Ensure the `colorToSxMapping` isn't missing a mappable color.
      assert(ListEquality().equals(mappableZestyCrayonColors.sorted(),
          colorToSxMapping.keys.toList().sorted()));
      final sxFromColor = mapWsdConstant(rhs, colorToSxMapping);

      // It's not expected for `sxFromColor` to ever be `null` because the `if` conditional
      // is attempting to assert that a constant mapping will be found.
      if (sxFromColor != null) {
        yieldAddPropPatch(usage, sxFromColor);
        return;
      }
    }

    // This may be hit if a badge or label reference the alt green Zesty Crayon colors
    // (https://github.com/Workiva/web_skin_dart/blob/845601bd8ccbcca44e4bcf354f5b4f8dc996d27a/lib/src/ui_components/shared/constants.dart#L123-L127)
    //
    // But because there are currently no usages of it (according to the SG query below),
    // the manual migration comment is lazy and doesn't try to provide a solution.
    //
    // (https://sourcegraph.wk-dev.wdesk.org/search?q=BackgroundColor%5C.%28GREEN_ALT%7CGREEN_ALT_2%29+lang:dart+-repo:web_skin_dart+-repo:web_skin_docs+-repo:dart_storybook&patternType=regexp)
    yieldPropManualMigratePatch(prop);
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

  void migrateChildrenToLabelProp(FluentComponentUsage usage) {
    final flagChildren = (String fixmePrefix) => yieldChildFixmePatch(
        usage.children.first,
        '$fixmePrefix Manually migrate the children into the `label` prop.');

    if (usage.children.isEmpty) return;
    if (usage.children.length > 1) {
      flagChildren('Multiple children detected.');
      return;
    }

    final child = usage.children.first;

    if (child is! ExpressionComponentChild) {
      flagChildren('Complex expression logic detected.');
      return;
    }

    final typeCategory = typeCategoryForReactNode(child.node);

    if (typeCategory == ReactNodeTypeCategory.unknown ||
        typeCategory == ReactNodeTypeCategory.other) {
      flagChildren('Unknown child type detected.');
      return;
    }

    yieldAddPropPatch(usage, '..label = ${context.sourceFor(child.node)}');
    yieldRemoveChildPatch(child.node);
  }
}

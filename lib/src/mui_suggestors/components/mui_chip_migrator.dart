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
    yieldAddPropPatch(usage, '..variant = $muiNs.ChipVariant.wsdBadge');
    migrateChildrenToLabel(usage);

    handleCascadedPropsByName(usage, {
      'isDisabled': (p) {
        yieldPropFixmePatch(p,
            'if this badge has mouse handlers that should fire when disabled or needs to show a tooltip/overlay when disabled, add a wrapper element');
        yieldPropPatch(p, newName: 'disabled');
      },
      // TODO what to do with align?
      'isOutline': (p) => migrateBadgeOutlineProp(usage, p),
      'backgroundColor': migrateBadgeBackgroundColor,
      'align': migrateBadgeAlignProp,

      // HitArea Props
      // TODO do we need logic to check if we should do this?
      'allowedHandlersWhenDisabled': yieldPropManualMigratePatch,
      'role': (p) => yieldPropPatch(p, newName: 'dom.role'),
      'target': (p) => yieldPropPatch(p, newName: 'dom.target'),
      // TODO does `dom.type` work out of the box here?
      'type': (p) => yieldPropPatch(p, newName: 'dom.type'),
    });

    migrateTooltipProps(usage);
  }
}

mixin ChipDisplayPropsMigrator on ComponentUsageMigrator {
  void migrateBadgeOutlineProp(
      FluentComponentUsage usage, PropAssignment prop) {
    yieldRemovePropPatch(prop);

    yieldAddPropPatch(usage, '..color = $muiNs.ChipColor.wsdBadgeOutlined');
  }

  void migrateBadgeBackgroundColor(PropAssignment prop) {
    final rhs = prop.rightHandSide;

    // TODO handle doc tpy colors
    // final docTypeColors = ['DOC_TYPE_BLUE',
    //   'DOC_TYPE_LIGHT_BLUE',
    //   'DOC_TYPE_TEAL',
    //   'DOC_TYPE_GRAY',
    //   'DOC_TYPE_RED',
    //   'DOC_TYPE_GREEN',
    //   'DOC_TYPE_PURPLE',
    //   'DOC_TYPE_ORANGE',
    //   'DOC_TYPE_MAGENTA',
    // ];

    final colorFromWsdBackgroundColor = mapWsdConstant(rhs, const {
      'BackgroundColor.DANGER': '$muiNs.ChipColor.error',
      'BackgroundColor.ALTERNATE': '$muiNs.ChipColor.secondary',
      'BackgroundColor.DEFAULT': '$muiNs.ChipColor.inherit',
      'BackgroundColor.SUCCESS': '$muiNs.ChipColor.success',
      'BackgroundColor.WARNING': '$muiNs.ChipColor.warning',
    });

    if (colorFromWsdBackgroundColor != null) {
      yieldPropPatch(
        prop,
        newName: 'color',
        newRhs: colorFromWsdBackgroundColor,
      );
      return;
    }

    // For other values, manual migration is safest.
    yieldPropManualMigratePatch(prop);
  }

  void migrateBadgeAlignProp(PropAssignment prop) {
    final rhs = prop.rightHandSide;
    String? message;

    message = mapWsdConstant(rhs, const {
      'BadgeAlign.LEFT':
          'Manually verify. BadgeAlign.LEFT is the default and may be able to be removed. Otherwise, `sx` can be used like so: ..sx = {\'marginRight\': \'.5em\'}',
      'BadgeAlign.RIGHT':
          'Instead of align, move the badge to be after its siblings and add `sx` like so: ..sx = {\'marginLeft\': \'.5em\', \'mr\': 0}',
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

  void migrateChildrenToLabel(FluentComponentUsage usage) {
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

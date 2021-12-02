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
import 'package:meta/meta.dart';
import 'package:over_react_codemod/src/mui_suggestors/constants.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:over_react_codemod/src/util/component_usage_migrator.dart';
import 'package:over_react_codemod/src/util.dart';

import 'mui_migrator.dart';

class MuiChipMigrator extends ComponentUsageMigrator with MuiMigrator {
  @override
  bool shouldMigrateUsage(FluentComponentUsage usage) =>
      usesWsdFactory(usage, 'Badge');

  void migrateBadgeOutlineProp(FluentComponentUsage usage, PropAssignment prop) {
    yieldRemovePropPatch(prop);

    yieldAddPropPatch(usage, '...color = $muiNs.ChipColor.wsdBadgeOutlined');
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
      'BadgeAlign.LEFT': 'Manually verify. BadgeAlign.LEFT is the default and may be able to be removed. Otherwise, `sx` can be used like so: ..sx = {\'marginRight\': \'.5em\'}',
      'BadgeAlign.RIGHT': 'Instead of align, `sx` can be used like so: ..sx = {\'marginLeft\': \'.5em\', \'mr\': 0}',
      'BadgeAlign.PULL_RIGHT': 'Instead of align, `sx` can be used like so: ..sx = {\'float\': \'right\', \'mr\': 0}',
      'BadgeAlign.PULL_LEFT': 'Instead of align, `sx` can be used like so: ..sx = {\'float\': \'left\', \'mr\': 0}',
    });

    if (message == null) {
      message = 'Cannot migrate the `align` prop. Use `sx` instead.';
    }

    yieldPropFixmePatch(
        prop,
        message);
  }

  @override
  void migrateUsage(FluentComponentUsage usage) {
    super.migrateUsage(usage);

    yieldPatchOverNode('$muiNs.Chip', usage.factory!);
    yieldAddPropPatch(usage, '...variant = $muiNs.ChipVariant.wsdBadge');

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



  /// Returns a string that can be used to add the props from the right-hand
  /// side of [assignment] (assuming the prop is a Map prop) to a factory
  /// matching [destinationFactoryName].
  ///
  /// If the map prop value is a typed map constructed from [destinationFactoryName],
  /// then just the cascades will be returned.
  ///
  /// For example, for the assignment:
  /// ```dart
  /// ..fooProps = (Foo()
  ///   ..bar = 'bar'
  ///   ..id = foo
  /// )
  /// ```
  /// then `_cascadeFromMapPropValue(assignment, 'Foo')`
  /// would yield the string:
  /// ```
  /// ..bar = 'bar'
  /// ..id = 'foo'
  /// ```
  ///
  /// Non-matching values are handled using `.addProps`, so
  /// `_cascadeFromMapPropValue(assignment, 'Bar')`
  /// would yield the string:
  /// ```
  /// ..addProps(Foo()
  ///   ..bar = 'bar'
  ///   ..id = 'foo'
  /// )
  /// ```
  ///
  /// Non-typed-map values are also handled using `.addProps`.
  ///
  /// For example, for the assignment:
  /// ```dart
  /// ..fooProps = someValue
  /// ```
  /// then `_cascadeFromMapPropValue(assignment, 'Foo')`
  /// would yield the string:
  /// ```
  /// ..addProps(someValue)
  /// ```
  /// TODO this is copypastad from button. Can it be shared?
  String _cascadeFromMapPropValue(PropAssignment? assignment,
      {required String destinationFactoryName}) {
    if (assignment == null) return '';

    // If the RHS is a maps view using destinationFactoryName,
    // then we can just return that cascade directly.
    final value = assignment.rightHandSide.unParenthesized;
    if (value is CascadeExpression) {
      final function = value.target.tryCast<InvocationExpression>()?.function;
      if (function.tryCast<SimpleIdentifier>()?.name ==
          destinationFactoryName ||
          function.tryCast<PrefixedIdentifier>()?.identifier.name ==
              destinationFactoryName) {
        return context.sourceFile.getText(value.target.end, value.end);
      }
    }

    return '..addProps(${context.sourceFor(value)})';
  }

  /// Migrate usages of tooltipContent/overlayTriggerProps to a wrapper OverlayTrigger.
  /// TODO this is copypastad from button. Can it be shared?
  void migrateTooltipProps(FluentComponentUsage usage) {
    final tooltipContentProp = getFirstPropWithName(usage, 'tooltipContent');
    if (tooltipContentProp == null) return;

    final tooltipContentSource =
    context.sourceFor(tooltipContentProp.rightHandSide);
    yieldRemovePropPatch(tooltipContentProp);

    final overlayTriggerPropsProp =
    getFirstPropWithName(usage, 'overlayTriggerProps');
    final overlayTriggerCascadeToAdd = _cascadeFromMapPropValue(
        overlayTriggerPropsProp,
        destinationFactoryName: 'OverlayTrigger');
    if (overlayTriggerPropsProp != null) {
      yieldRemovePropPatch(overlayTriggerPropsProp);
    }

    final tooltipPropsProp = getFirstPropWithName(usage, 'tooltipProps');
    final tooltipCascadeToAdd = _cascadeFromMapPropValue(tooltipPropsProp,
        destinationFactoryName: 'Tooltip');
    if (tooltipPropsProp != null) {
      yieldRemovePropPatch(tooltipPropsProp);
    }

    final overlaySource =
        '${tooltipCascadeToAdd.isEmpty ? 'Tooltip()' : '(Tooltip()$tooltipCascadeToAdd)'}($tooltipContentSource)';

    yieldInsertionPatch(
        '(OverlayTrigger()\n'
        // Put this comment here instead of on OverlayTrigger since that might not format nicely
            '  ${lineComment('$fixmePrefix - tooltip props - manually verify this new Tooltip and wrapper OverlayTrigger')}'
            '..overlay2 = $overlaySource'
            '$overlayTriggerCascadeToAdd'
            ')(',
        usage.node.offset);
    yieldInsertionPatch(',)', usage.node.end);
  }
}

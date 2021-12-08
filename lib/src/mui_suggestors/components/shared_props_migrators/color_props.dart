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

import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:over_react_codemod/src/util/component_usage_migrator.dart';
import 'package:collection/collection.dart';

import '../../constants.dart';

/// Shared migrators for components that are migrating a component that mixes in
/// `ColorPropsMixin`.
mixin ColorPropMigrators on ComponentUsageMigrator {
  /// Migrator for props that have a RHS typing of `wsd.BackgroundColor`.
  void migrateColorPropsBackgroundColor(
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
    // the badge would get some styling. However, with a MUI chip, adding a label color
    // does not change the background color.
    if (usesWsdFactory(usage, 'Badge') &&
        docTypeColors.any((constant) => isWsdStaticConstant(rhs, constant))) {
      yieldPropFixmePatch(prop,
          'A MUI chip with the badge variant cannot be set to a DOC_TYPE color. Use the `sx` prop and theme palette instead.');
      return;
    }

    // This excludes any of the Zesty Crayon colors because they do not have a
    // named counterpart
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

    /// A list of Zesty Crayon background colors that have a RMUI counterpart
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
            "..sx = {'backgroundColor': ($muiNs.Theme theme) => theme.palette.green.main, 'color': '#fff'}",
        'BackgroundColor.BLUE':
            "..sx = {'backgroundColor': ($muiNs.Theme theme) => theme.palette.blue.main, 'color': '#fff'}",
        'BackgroundColor.ORANGE':
            "..sx = {'backgroundColor': ($muiNs.Theme theme) => theme.palette.orange.main, 'color': '#fff'}",
        'BackgroundColor.RED':
            "..sx = {'backgroundColor': ($muiNs.Theme theme) => theme.palette.red.main, 'color': '#fff'}",
        'BackgroundColor.GRAY':
            "..sx = {'backgroundColor': ($muiNs.Theme theme) => theme.palette.grey.main, 'color': '#fff'}",
      };

      // Ensure the `colorToSxMapping` isn't missing a mappable Zesty Crayon color.
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
}

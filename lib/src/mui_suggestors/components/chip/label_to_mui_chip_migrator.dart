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
import 'package:over_react_codemod/src/mui_suggestors/components/shared_props_migrators/color_props.dart';
import 'package:over_react_codemod/src/mui_suggestors/components/shared_props_migrators/hit_area.dart';
import 'package:over_react_codemod/src/mui_suggestors/constants.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:over_react_codemod/src/util/component_usage_migrator.dart';

import '../mui_migrator.dart';
import 'shared.dart';

class LabelToMuiChipMigrator extends ComponentUsageMigrator
    with
        MuiMigrator,
        LabelToMuiChipPropsMigrator,
        MuiChipPropsMigrator,
        HitAreaPropMigrators,
        ColorPropMigrators {
  @override
  bool shouldMigrateUsage(FluentComponentUsage usage) =>
      usesWsdFactory(usage, 'Label');

  @override
  void migrateUsage(FluentComponentUsage usage) {
    super.migrateUsage(usage);

    yieldPatchOverNode('$muiNs.Chip', usage.factory!);
    migrateChildrenToLabelProp(usage);

    handleCascadedPropsByName(usage, {
      'backgroundColor': (p) => migrateColorPropsBackgroundColor(usage, p),
      'borderColor': yieldUseSxFixmePatch,
      'isStatus': isStatusMigrator,
      'textColor': yieldUseSxFixmePatch,
    });

    final allIsStatusProps =
        usage.cascadedProps.where((prop) => prop.name.name == 'isStatus');

    // the `isStatus` migrator will set the variant, so it should only be added
    // here if there is no `isStatus` prop.
    if (allIsStatusProps.isEmpty) {
      yieldAddPropPatch(usage, '..variant = $muiNs.ChipVariant.wsdLabel');
    }
  }
}

mixin LabelToMuiChipPropsMigrator on ComponentUsageMigrator {
  void isStatusMigrator(PropAssignment prop) {
    final rhs = prop.rightHandSide;

    if (rhs is BooleanLiteral) {
      if (rhs.value) {
        yieldPropPatch(prop,
            newName: 'variant', newRhs: '$muiNs.ChipVariant.wsdLabelStatus');
      } else {
        yieldPropPatch(prop,
            newName: 'variant', newRhs: '$muiNs.ChipVariant.wsdLabel');
      }
    } else {
      // Change
      //     ..isStatus = expression
      // to
      //     ..variant = expression ? mui.ChipColor.wsdLabelStatus : mui.ChipColor.wsdLabel
      yieldPropPatch(prop, newName: 'variant');
      yieldInsertionPatch(
          ' ? $muiNs.ChipVariant.wsdLabelStatus : $muiNs.ChipVariant.wsdLabel',
          rhs.end);
    }
  }
}

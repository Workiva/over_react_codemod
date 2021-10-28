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
import 'package:over_react_codemod/src/mui_suggestors/constants.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:over_react_codemod/src/util/component_usage_migrator.dart';

import 'mui_migrator.dart';

class MuiButtonGroupMigrator extends ComponentUsageMigrator with MuiMigrator {
  @override
  bool shouldMigrateUsage(FluentComponentUsage usage) =>
      usesWsdFactory(usage, 'ButtonGroup');

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
      'ButtonGroupSize.XXSMALL': '$muiNs.ButtonGroupSize.xxsmall',
      'ButtonGroupSize.XSMALL': '$muiNs.ButtonGroupSize.xsmall',
      'ButtonGroupSize.SMALL': '$muiNs.ButtonGroupSize.small',
      'ButtonGroupSize.DEFAULT': '$muiNs.ButtonGroupSize.medium',
      'ButtonGroupSize.LARGE': '$muiNs.ButtonGroupSize.large',
    });
    if (sizeFromWsdSize != null) {
      yieldPropPatch(prop, newRhs: sizeFromWsdSize);
      return;
    }

    // For other values, manual migration is safest.
    yieldPropManualMigratePatch(prop);
  }
}

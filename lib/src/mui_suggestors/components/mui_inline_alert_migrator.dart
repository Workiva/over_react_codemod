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

import 'package:over_react_codemod/src/util.dart';
import 'package:over_react_codemod/src/mui_suggestors/constants.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:over_react_codemod/src/util/component_usage_migrator.dart';

import 'mui_migrator.dart';

class MuiInlineAlertMigrator extends ComponentUsageMigrator
    with MuiMigrator, AlertDisplayPropsMigrator {
  static const toastAlertProps = [
    'dismissAfter',
    'initiallyShown',
    'isDismissible',
    'onDidHide',
    'onDidShow',
    'onWillHide',
    'onWillShow',
    'transition',
    'transitionCount',
    'transitionInCount',
    'transitionOutCount',
  ];

  @override
  bool shouldMigrateUsage(FluentComponentUsage usage) =>
      usesWsdFactory(usage, 'Alert') &&
      // If the alert has props related to the `toast` variant, don't try to
      // migrate it.
      !usage.cascadedProps
          .any((prop) => toastAlertProps.contains(prop.name.name));

  @override
  void migrateUsage(FluentComponentUsage usage) {
    super.migrateUsage(usage);

    yieldPatchOverNode('$muiNs.Alert', usage.factory!);

    handleCascadedPropsByName(usage, {
      'heading': (p) => migrateAlertHeading(usage, p),
      'headingProps': yieldPropManualMigratePatch,
      'skin': migrateAlertSkin,
      'size': migrateAlertSize,
    });
  }
}

mixin AlertDisplayPropsMigrator on ComponentUsageMigrator {
  void migrateAlertSkin(PropAssignment prop) {
    final rhs = prop.rightHandSide;

    final severityFromWsdSkin = mapWsdConstant(rhs, const {
      'AlertSkin.DEFAULT': '$muiNs.AlertSeverity.info',
      'AlertSkin.SUCCESS': '$muiNs.AlertSeverity.success',
      'AlertSkin.WARNING': '$muiNs.AlertSeverity.warning',
      'AlertSkin.DANGER': '$muiNs.AlertSeverity.error',
    });

    if (severityFromWsdSkin != null) {
      yieldPropPatch(
        prop,
        newName: 'severity',
        newRhs: severityFromWsdSkin,
      );
      return;
    }

    final usesInverseSkin =
        isWsdStaticConstant(prop.rightHandSide, 'AlertSkin.INVERSE');
    var migrateVariantToGray = usesInverseSkin ||
        isWsdStaticConstant(prop.rightHandSide, 'AlertSkin.GRAY');

    if (migrateVariantToGray) {
      if (usesInverseSkin) {
        yieldPropFixmePatch(prop,
            'this prop was converted from the INVERSE skin and should be double checked');
      }

      yieldPropPatch(
        prop,
        newName: 'variant',
        newRhs: '$muiNs.AlertVariant.wsdGray',
      );
      return;
    }

    yieldPropManualMigratePatch(prop);
  }

  void migrateAlertHeading(FluentComponentUsage usage, PropAssignment prop) {
    final propValue = prop.rightHandSide;

    yieldRemovePropPatch(prop);
    yieldAddChildPatch(
        usage, '$muiNs.AlertTitle()(${context.sourceFor(propValue)})');
  }

  void migrateAlertSize(PropAssignment prop) {
    final rhs = prop.rightHandSide;

    final sizeFromWsdAlertSize = mapWsdConstant(rhs, const {
      'AlertSize.DEFAULT': '$muiNs.AlertSize.medium',
      'AlertSize.SMALL': '$muiNs.AlertSize.small',
      'AlertSize.XSMALL': '$muiNs.AlertSize.xsmall',
    });

    if (sizeFromWsdAlertSize != null) {
      yieldPropPatch(
        prop,
        newRhs: sizeFromWsdAlertSize,
      );
      return;
    }

    yieldPropManualMigratePatch(prop);
  }
}

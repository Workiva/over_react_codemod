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

class MuiInlineAlertMigrator extends ComponentUsageMigrator with MuiMigrator {
  // TODO alphabetize these
  static const toastAlertProps = [
    'initiallyShown',
    'dismissAfter',
    'isDismissible',
    'transition',
    'transitionCount',
    'transitionInCount',
    'transitionOutCount',
    'onWillHide',
    'onDidHide',
    'onWillShow',
    'onDidShow',
  ];

  @override
  bool shouldMigrateUsage(FluentComponentUsage usage) =>
      usesWsdFactory(usage, 'Alert') &&
      !usage.cascadedProps
          .any((prop) => toastAlertProps.contains(prop.name.name));

  @override
  void migrateUsage(FluentComponentUsage usage) {
    super.migrateUsage(usage);

    yieldPatchOverNode('$muiNs.Alert', usage.factory!);

    handleCascadedPropsByName(usage, {});
  }
}

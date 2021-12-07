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
import 'package:over_react_codemod/src/util.dart';

mixin MuiChipPropsMigrator on ComponentUsageMigrator {
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

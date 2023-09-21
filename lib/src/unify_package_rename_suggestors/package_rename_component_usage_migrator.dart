// Copyright 2023 Workiva Inc.
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
import 'package:over_react_codemod/src/unify_package_rename_suggestors/constants.dart';
import 'package:over_react_codemod/src/util.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:over_react_codemod/src/util/component_usage_migrator.dart';
import 'package:over_react_codemod/src/util/element_type_helpers.dart';

class PackageRenameComponentUsageMigrator extends ComponentUsageMigrator {
  @override
  String get fixmePrefix => 'FIXME(unify_package_rename)';

  @override
  bool shouldMigrateUsage(FluentComponentUsage usage) => true;

  @override
  void migrateUsage(FluentComponentUsage usage) {
    super.migrateUsage(usage);

    final factoryElement = usage.factoryTopLevelVariableElement;
    if (factoryElement == null) return;

    if (factoryElement.isDeclaredInPackage('react_material_ui')) {
      // Replace 'mui' namespaces usage with 'unify'.
      final prefix = usage.factory.tryCast<PrefixedIdentifier>()?.prefix;
      final newPrefixName = rmuiToUnifyNamespaces[prefix?.name];
      if (prefix != null && newPrefixName != null) {
        yieldPatch(newPrefixName, prefix.offset, prefix.end);
      }

      // todo add fixme comment for things that should be updated - Wsd prefixed things

      // todo remove mui prefix for Wsd prefixed components or make new prefix for import to find (unify_wsd)

      // Update components that were renamed in unify_ui.
      final identifier = usage.factory.tryCast<SimpleIdentifier>() ??
          usage.factory.tryCast<PrefixedIdentifier>()?.identifier;
      final newComponentName = rmuiToUnifyComponentNames[identifier?.name];
      if (identifier != null && newComponentName != null) {
        yieldPatch(newComponentName, identifier.offset, identifier.end);
      }

      // Add comments for components that need manual verification.
      if (identifier?.name == 'Badge' || identifier?.name == 'LinearProgress') {
        yieldUsageFixmePatch(usage,
            'Check what theme provider is wrapping this component: if it is a UnifyThemeProvider, remove this FIXME - no action is required; otherwise, migrate this component back to Web Skin Dart.');
      }
    }
  }
}

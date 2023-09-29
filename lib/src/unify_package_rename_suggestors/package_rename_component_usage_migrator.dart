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
import 'package:collection/collection.dart';
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

  // todo update to skip all flags
  @override
  bool get shouldFlagUnsafeMethodCalls => false;
  @override
  bool get shouldFlagUntypedSingleProp => false;
  @override
  bool get shouldFlagExtensionMembers => false;
  @override
  bool get shouldFlagPrefixedProps => false;
  @override
  bool get shouldFlagRefProp => false;
  @override
  bool get shouldFlagClassName => false;

  @override
  void migrateUsage(FluentComponentUsage usage) {
    super.migrateUsage(usage);

    final factoryElement = usage.factoryTopLevelVariableElement;
    if (factoryElement == null) return;

    if (factoryElement.isDeclaredInPackage('react_material_ui')) {
      // Save the import namespace to later replace with a unify version.
      final importNamespace = usage.factory.tryCast<PrefixedIdentifier>()?.prefix;
      final newImportNamespace = importsToUpdate
          .where((import) =>
              importNamespace?.name != null &&
              (import.possibleMuiNamespaces?.contains(importNamespace?.name) ?? false))
          .singleOrNull
          ?.namespace;

      // Update components that were renamed in unify_ui.
      final identifier = usage.factory.tryCast<SimpleIdentifier>() ??
          usage.factory.tryCast<PrefixedIdentifier>()?.identifier;
      final newComponentName = rmuiToUnifyComponentNames[identifier?.name];
      final isFromWsdEntrypoint = newComponentName?.startsWith('Wsd') ?? false;
      if (identifier != null && newComponentName != null) {
        if (isFromWsdEntrypoint) {
          // Overwrite or add import namespace for components that will be imported from the separate
          // unify_ui/components/wsd.dart entrypoint so we can keep the namespace of the import
          // we add consistent with the components that use it.
          final factory = usage.factory.tryCast<PrefixedIdentifier>() ?? identifier;
          yieldPatch('$unifyWsdNamespace.$newComponentName', factory.offset, factory.end);
        } else {
          yieldPatch(newComponentName, identifier.offset, identifier.end);
        }
      }

      // Replace 'mui' namespaces usage with 'unify'.
      if (importNamespace != null && newImportNamespace != null && !isFromWsdEntrypoint) {
        yieldPatch(newImportNamespace, importNamespace.offset, importNamespace.end);
      }

      // Add comments for components that need manual verification.
      if (identifier?.name == 'Badge' || identifier?.name == 'LinearProgress') {
        yieldUsageFixmePatch(usage,
            'Check what theme provider is wrapping this component: if it is a UnifyThemeProvider, remove this FIXME - no action is required; otherwise, migrate this component back to Web Skin Dart.');
      }
    }
  }
}

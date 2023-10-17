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
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:codemod/codemod.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';

import '../util.dart';
import '../util/class_suggestor.dart';
import '../util/element_type_helpers.dart';
import 'constants.dart';

final _log = Logger('UnifyRenameSuggestor');

/// Suggestor that performs all the updates needed to migrate from the react_material_ui package
/// to the unify_ui package:
///
/// - Rename specific components and objects
/// - Update WSD ButtonColor usages
/// - Rename import namespaces 'mui' => 'unify'
/// - Add fix me comments for manual checks
///
/// Also see migration guide: https://github.com/Workiva/react_material_ui/tree/master/react_material_ui#how-to-migrate-from-reactmaterialui-to-unifyui
class UnifyRenameSuggestor extends GeneralizingAstVisitor with ClassSuggestor {
  UnifyRenameSuggestor();

  @override
  visitMethodInvocation(MethodInvocation node) {
    super.visitMethodInvocation(node);

    // Replace 'mui' namespaces usage with 'unify' for method invocations.
    final uri = node.methodName.staticElement?.source?.uri;
    if (uri != null &&
        (isUriWithinPackage(uri, 'react_material_ui') || isUriWithinPackage(uri, 'unify_ui'))) {
      final importNamespace = node.target;
      if (importNamespace != null) {
        final newImportNamespace = rmuiImportsToUpdate
            .where((import) =>
                import.possibleMuiNamespaces?.contains(importNamespace.toSource()) ?? false)
            .singleOrNull
            ?.namespace;
        if (newImportNamespace != null) {
          yieldPatch(newImportNamespace, importNamespace.offset, importNamespace.end);
        }
      }
    }
  }

  @override
  visitIdentifier(Identifier node) {
    super.visitIdentifier(node);

    // Check that the parent isn't a prefixed identifier to avoid conflicts if the parent was already updated.
    if (node.parent is PrefixedIdentifier) {
      return;
    }

    final identifier =
        node.tryCast<SimpleIdentifier>() ?? node.tryCast<PrefixedIdentifier>()?.identifier;
    final uri = identifier?.staticElement?.source?.uri;
    final prefix = node.tryCast<PrefixedIdentifier>()?.prefix;

    if (uri != null &&
        (isUriWithinPackage(uri, 'react_material_ui') || isUriWithinPackage(uri, 'unify_ui'))) {
      // Update components and objects that were renamed in unify_ui.
      final newName = rmuiToUnifyIdentifierRenames[identifier?.name];
      var isFromWsdEntrypoint = newName?.startsWith('Wsd') ?? false;
      if (identifier != null && newName != null) {
        if (isFromWsdEntrypoint) {
          // Overwrite or add import namespace for components that will be imported from the separate
          // unify_ui/components/wsd.dart entrypoint so we can keep the namespace of the import
          // we add consistent with the components that use it.
          yieldPatch('$unifyWsdNamespace.$newName', node.offset, node.end);
        } else {
          yieldPatch(newName, identifier.offset, identifier.end);
        }
      }

      // Update WSD ButtonColor and AlertSize usages.
      {
        // Update WSD constant properties objects to use the WSD versions if applicable.
        yieldWsdRenamePatchIfApplicable(Expression node, String? objectName, String? propertyName) {
          if (objectName == 'ButtonColor' && (propertyName?.startsWith('wsd') ?? false)) {
            isFromWsdEntrypoint = true;
            yieldPatch('$unifyWsdNamespace.WsdButtonColor.$propertyName', node.offset, node.end);
          } else if (objectName == 'AlertSize') {
            isFromWsdEntrypoint = true;
            yieldPatch('$unifyWsdNamespace.WsdAlertSize.$propertyName', node.offset, node.end);
          }
        }

        final parent = node.parent;
        // Check for non-namespaced `ButtonColor.wsd...` usage.
        yieldWsdRenamePatchIfApplicable(node, prefix?.name, identifier?.name);
        // Check for namespaced `mui.ButtonColor.wsd...` usage.
        if (node is PrefixedIdentifier && parent is PropertyAccess) {
          yieldWsdRenamePatchIfApplicable(parent, identifier?.name, parent.propertyName.name);
        }
      }

      // Replace 'mui' namespaces usage with 'unify'.
      final newNamespace = rmuiImportsToUpdate
          .where((import) => import.possibleMuiNamespaces?.contains(prefix?.name) ?? false)
          .singleOrNull
          ?.namespace;
      if (prefix != null && newNamespace != null && !isFromWsdEntrypoint) {
        yieldPatch(newNamespace, prefix.offset, prefix.end);
      }

      // Add comments for components that need manual verification.
      if (identifier?.name == 'Badge' || identifier?.name == 'LinearProgress') {
        yieldInsertionPatch(
            lineComment(
                'FIXME(unify_package_rename) Check what theme provider is wrapping this component: if it is a UnifyThemeProvider, remove this FIXME - no action is required; otherwise, migrate this component back to Web Skin Dart.'),
            node.offset);
      }
    }
  }

  @override
  Future<void> generatePatches() async {
    _log.info('Resolving ${context.relativePath}...');

    final result = await context.getResolvedUnit();
    if (result == null) {
      throw Exception('Could not get resolved result for "${context.relativePath}"');
    }
    result.unit.visitChildren(this);
  }

  @override
  bool shouldSkip(FileContext context) => hasParseErrors(context.sourceText);
}

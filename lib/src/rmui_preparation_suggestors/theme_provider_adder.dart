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
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:codemod/codemod.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:over_react_codemod/src/util/component_usage.dart';

const checkTypingFixmeComment =
    '// FIXME: Verify the return value of react_dom.render is unused, since the wrapper ThemeProvider has no component instance. If a component instance is needed, set a ref on the child component.';

/// Suggestor that wraps the contents of `react_dom.render` calls in a ThemeProvider.
class ThemeProviderAdder extends GeneralizingAstVisitor
    with AstVisitingSuggestor {
  /// The theme that will be added to the ThemeProvider.
  final String theme;

  ThemeProviderAdder(this.theme);

  @override
  visitMethodInvocation(MethodInvocation node) {
    super.visitMethodInvocation(node);

    // Don't update if [node] is not a render call or the file is in a test directory.
    final filePath = context.relativePath.split('/');
    if (node.methodName.name != 'render' ||
        // Some test directories are nested, but we still want to update
        // files in lib directories.
        (filePath.contains('test') && !filePath.contains('lib'))) {
      return;
    }

    final imports = node
        .thisOrAncestorOfType<CompilationUnit>()!
        .directives
        .whereType<ImportDirective>()
        .toList();

    final isPartOf = node
        .thisOrAncestorOfType<CompilationUnit>()!
        .directives
        .whereType<PartOfDirective>()
        .toList()
        .isNotEmpty;

    final themeProviderImport = imports.lastWhereOrNull((dir) =>
        dir.uri.stringValue ==
        'package:react_material_ui/styles/theme_provider.dart');

    final reactDomImport = imports.lastWhereOrNull((dir) =>
        (dir.uri.stringValue == 'package:react/react_dom.dart' ||
            dir.uri.stringValue == 'package:over_react/react_dom.dart'));

    // Don't update if no `react_dom.dart` import is found in the file or if
    // the namespace of the render call does not match the namespace of the
    // found import. If it is a `part of` file, assume the namespace is
    // `react_dom` because there will not be an import in the file.
    final namespace = node.realTarget?.toSource();
    if ((!isPartOf &&
            (reactDomImport == null ||
                namespace != reactDomImport.prefix?.name)) ||
        (isPartOf && namespace != 'react_dom')) {
      return;
    }

    // Add `theme_provider.dart` import if it is not already there or in a `part of` file.
    if (!isPartOf && themeProviderImport == null) {
      if (reactDomImport == null) {
        throw StateError(
            '`reactDomImport` should never be null here unless `isPartOf == true`');
      }
      yieldPatch(
        '\nimport \'package:react_material_ui/styles/theme_provider.dart\';',
        reactDomImport.end,
        reactDomImport.end,
      );
    }

    FluentComponentUsage? usage;
    final renderFirstArg = node.argumentList.arguments.first;

    // Check if the first argument is already wrapped in a ThemeProvider or an
    // ErrorBoundary containing a ThemeProvider.
    if (renderFirstArg is InvocationExpression) {
      usage = getComponentUsage(renderFirstArg);

      if (usage?.componentName == 'ThemeProvider') {
        return;
      } else if (usage?.componentName == 'ErrorBoundary') {
        final errorBoundaryChild = renderFirstArg.argumentList.arguments.first;
        if (errorBoundaryChild is InvocationExpression &&
            getComponentUsage(errorBoundaryChild)?.componentName ==
                'ThemeProvider') {
          return;
        }
      }
    }

    // Wrap the first argument of render in a ThemeProvider.
    final patch = '(ThemeProvider()..theme = $theme)(';
    if (renderFirstArg is InvocationExpression &&
        usage?.componentName == 'ErrorBoundary') {
      // If there is an ErrorBoundary, put the ThemeProvider inside it.
      yieldPatch(
        patch,
        renderFirstArg.argumentList.leftParenthesis.end,
        renderFirstArg.argumentList.leftParenthesis.end,
      );
    } else {
      final parent = node.parent;
      if (parent is! ExpressionStatement) {
        // Add a comment to verify the typing if the return value
        // of react_dom.render could be used.
        yieldPatch(' $checkTypingFixmeComment\n', node.offset, node.offset);
      }

      yieldPatch(patch, renderFirstArg.offset, renderFirstArg.offset);
    }
    yieldPatch(')', renderFirstArg.end, renderFirstArg.end);
  }
}

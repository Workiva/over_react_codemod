// Copyright 2019 Workiva Inc.
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
import 'package:over_react_codemod/src/react16_suggestors/constants.dart';
import 'package:over_react_codemod/src/react16_suggestors/react16_utilities.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';

/// Suggestor that migrates `react_dom.render` usages to be compatible with
/// React 16 and inserts comments in situations where validation is required.
class ReactDomRenderMigrator extends GeneralizingAstVisitor
    with AstVisitingSuggestor {
  @override
  visitMethodInvocation(MethodInvocation node) {
    super.visitMethodInvocation(node);

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

    final libraryDirective = node
        .thisOrAncestorOfType<CompilationUnit>()!
        .directives
        .whereType<LibraryDirective>()
        .toList();

    final overReactImport = imports.lastWhereOrNull((dir) =>
        dir.uri.stringValue == 'package:over_react/over_react.dart' ||
        // These tests strings are split by web_skin_dart to work around issues with dependency_validator.
        dir.uri.stringValue == 'package:' 'web_skin_dart/ui_core.dart');

    final reactDomImport = imports.lastWhereOrNull((dir) =>
        (dir.uri.stringValue == 'package:react/react_dom.dart' ||
            dir.uri.stringValue == 'package:over_react/react_dom.dart'));

    String? reactDomImportNamespace;
    bool isWrappedWithErrorBoundary = false;

    if (reactDomImport == null) {
      reactDomImportNamespace = 'react_dom';
    } else {
      reactDomImportNamespace = reactDomImport.prefix?.name;
    }

    final testAncestor = node.thisOrAncestorMatching((ancestor) =>
        ancestor is MethodInvocation &&
        const {'test', 'group'}.contains(ancestor.methodName.name));
    final inTest = testAncestor != null;

    if (node.methodName.name != 'render' ||
        reactDomImportNamespace != node.realTarget?.toSource() ||
        inTest) {
      return;
    }

    FluentComponentUsage? usage;
    final renderFirstArg = node.argumentList.arguments.first;

    // Get function declaration to determine return value type.
    FunctionDeclaration? functionDecl = node.thisOrAncestorMatching((ancestor) {
      return ancestor is FunctionDeclaration;
    });

    void addOverReactPatch([int? offset]) {
      if (offset == null && imports.isNotEmpty) {
        offset = imports.last.offset;
      } else if (libraryDirective.isNotEmpty) {
        offset = libraryDirective.first.end;
      } else {
        offset = 0;
      }
      if (!isPartOf) {
        yieldPatch(
            'import \'package:over_react/over_react.dart\';\n', offset, offset);
      }
    }

    if (renderFirstArg is InvocationExpression) {
      usage = getComponentUsage(renderFirstArg);
      if (usage?.componentName == 'ErrorBoundary' ||
          renderFirstArg.toSource().startsWith('ErrorBoundary')) {
        isWrappedWithErrorBoundary = true;
      }
    }

    // Wrap render in ErrorBoundary.
    if (!isWrappedWithErrorBoundary) {
      if (overReactImport == null) {
        addOverReactPatch(reactDomImport?.offset);
      }
      yieldPatch(
        'ErrorBoundary()(',
        renderFirstArg.offset,
        renderFirstArg.offset,
      );
      yieldPatch(
        ')',
        renderFirstArg.end,
        renderFirstArg.end,
      );
    } else if (isWrappedWithErrorBoundary && overReactImport == null) {
      addOverReactPatch(reactDomImport?.offset);
    }

    String? comment;
    if (usage == null) {
      comment =
          '\n // [ ] Check this box upon manual validation that the component '
          'rendered by this expression uses a ref safely.'
          '$willBeRemovedCommentSuffix\n';
    }

    final parent = node.parent;
    if (parent is VariableDeclaration || parent is AssignmentExpression) {
      String refVariableName;

      // Edit assignment
      if (parent is VariableDeclaration) {
        // Instances of this class are always children of the class [VariableDeclarationList]
        yieldPatch(
          ';',
          parent.equals!.offset,
          parent.equals!.end,
        );

        // Add this on the render call and not before the parent so that dupe
        // comments aren't added on subsequent runs.
        yieldPatch(
          comment ??
              '\n // [ ] Check this box upon manual validation of this ref and '
                  'its typing.$willBeRemovedCommentSuffix\n',
          node.realTarget!.offset,
          node.realTarget!.offset,
        );

        refVariableName = parent.name.lexeme;
      } else if (parent is AssignmentExpression) {
        yieldPatch(
          '',
          parent.offset,
          parent.rightHandSide.offset,
        );

        // Add this on the render call and not before the parent so that dupe
        // comments aren't added on subsequent runs.
        yieldPatch(
          comment ??
              '// [ ] Check this box upon manual validation of this ref.'
                  '$willBeRemovedCommentSuffix\n',
          parent.rightHandSide.offset,
          parent.rightHandSide.offset,
        );

        refVariableName = parent.leftHandSide.toSource();
      } else {
        throw StateError('should never get here');
      }

      if (usage != null && !renderFirstArg.toSource().contains('..ref')) {
        // Add the ref
        final builderExpression = usage.node.function;

        if (builderExpression is! ParenthesizedExpression) {
          yieldPatch(
            '(',
            builderExpression.offset,
            builderExpression.offset,
          );
        }

        yieldPatch(
          '\n  ..ref = (ref) { $refVariableName = ref; }\n',
          usage.builder.end,
          usage.builder.end,
        );

        if (builderExpression is! ParenthesizedExpression) {
          yieldPatch(
            ')',
            builderExpression.end,
            builderExpression.end,
          );
        }
      }
    } else if (parent is ArgumentList &&
        !hasValidationComment(node, context.sourceFile)) {
      // Add comment to manually update if return value of `react_dom.render` is
      // used as an argument.
      yieldPatch(
        '\n// [ ] Check this box upon manually updating this argument to use a '
        'callback ref instead of the return value of `react_dom.render`.'
        '$willBeRemovedCommentSuffix\n',
        node.realTarget!.offset,
        node.realTarget!.offset,
      );
    } else if ((parent is ReturnStatement ||
            parent is ExpressionFunctionBody) &&
        functionDecl?.returnType?.toSource() != 'void' &&
        !hasValidationComment(node, context.sourceFile)) {
      // Add comment to manually update if return value of `react_dom.render` is
      // used in a return statement (including non-void arrow functions).
      yieldPatch(
        '// [ ] Check this box upon manually updating this variable to be set using a '
        'callback ref instead of the return value of `react_dom.render`.'
        '$willBeRemovedCommentSuffix\n',
        node.realTarget!.offset,
        node.realTarget!.offset,
      );
    } else {
      if (!hasValidationComment(node, context.sourceFile) &&
          renderFirstArg.toSource().contains('..ref')) {
        yieldPatch(
          comment ??
              '// [ ] Check this box upon manual validation of this ref.'
                  '$willBeRemovedCommentSuffix\n',
          node.realTarget!.offset,
          node.realTarget!.offset,
        );
      }
    }
  }
}

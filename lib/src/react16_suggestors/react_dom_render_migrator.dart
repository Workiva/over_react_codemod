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

import 'package:analyzer/analyzer.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:codemod/codemod.dart';
import 'package:over_react_codemod/src/react16_suggestors/constants.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:source_span/source_span.dart';

/// Suggestor that migrates `react_dom.render` usages to be compatible with
/// React 16 and inserts comments in situations where validation is required.
class ReactDomRenderMigrator extends GeneralizingAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  @override
  visitMethodInvocation(MethodInvocation node) {
    super.visitMethodInvocation(node);

    final parent = node.parent;

    if (node.methodName.name != 'render' ||
        !const ['react_dom', 'reactDom']
            .contains(node.realTarget?.toSource?.call()) ||
        !isInLifecycleMethod(node)) {
      return;
    }

    FluentComponentUsage usage;
    final renderFirstArg = node.argumentList.arguments.first;

    // Wrap render in ErrorBoundary
    if (!renderFirstArg.toString().startsWith('ErrorBoundary')) {
      yieldPatch(
          renderFirstArg.offset, renderFirstArg.offset, 'ErrorBoundary()(');
      yieldPatch(renderFirstArg.end, renderFirstArg.end, ')');
    }

    if (renderFirstArg is InvocationExpression) {
      usage = getComponentUsage(renderFirstArg);
    }

    String comment;
    if (usage == null) {
      comment =
          '\n // [ ] Check this box upon manual validation that the component rendered by this expression uses a ref safely.$willBeRemovedCommentSuffix\n';
    }

    if (parent is VariableDeclaration || parent is AssignmentExpression) {
      String refVariableName;

      // Edit assignment
      if (parent is VariableDeclaration) {
        // > Instances of this class are always children of the class [VariableDeclarationList]
        yieldPatch(parent.equals.offset, parent.equals.end, ';');
        // Add this on the render call and not before the parent so that dupe comments aren't added on subsequent runs.
        yieldPatch(
            node.realTarget.offset,
            node.realTarget.offset,
            comment ??
                '\n // [ ] Check this box upon manual validation of this ref and its typing.$willBeRemovedCommentSuffix\n');
        refVariableName = parent.name.name;
      } else if (parent is AssignmentExpression) {
        yieldPatch(parent.offset, parent.rightHandSide.offset, '');
        // Add this on the render call and not before the parent so that dupe comments aren't added on subsequent runs.
        yieldPatch(
            parent.rightHandSide.offset,
            parent.rightHandSide.offset,
            comment ??
                '// [ ] Check this box upon manual validation of this ref.$willBeRemovedCommentSuffix\n');
        refVariableName = parent.leftHandSide.toSource();
      } else {
        throw StateError('should never get here');
      }

      if (usage != null && !renderFirstArg.toString().contains('..ref')) {
        // add the ref
        final builderExpression = usage.node.function;
        if (builderExpression is! ParenthesizedExpression) {
          yieldPatch(builderExpression.offset, builderExpression.offset, '(');
        }
        yieldPatch(usage.builder.end, usage.builder.end,
            '\n  ..ref = (ref) { $refVariableName = ref; }\n');
        if (builderExpression is! ParenthesizedExpression) {
          yieldPatch(builderExpression.end, builderExpression.end, ')');
        }
      }
      // TODO remove? this case doesn't seem necessary
      // else {
      //   // add a space after newline so that comment gets indented by dartfmt
      //   yieldPatch(node.offset, node.offset,
      //       '\n // [ ] Check this box upon manual validation that the component rendered by this expression uses a ref safely.$willBeRemovedCommentSuffix\n');
      // }
    } else if (parent is ArgumentList && !hasValidationComment(node, sourceFile)) {
      yieldPatch(
          node.realTarget.offset,
          node.realTarget.offset,
          manualUpdateComment);
    } else {
      if (!hasValidationComment(node, sourceFile) &&
          renderFirstArg.toString().contains('..ref')) {
        yieldPatch(
            node.realTarget.offset,
            node.realTarget.offset,
            comment ??
                '// [ ] Check this box upon manual validation of this ref.$willBeRemovedCommentSuffix\n');
      }
    }
  }
}

bool hasValidationComment(AstNode node, SourceFile sourceFile) {
  final line = sourceFile.getLine(node.offset);

  // Find the comment associated with this line; doesn't work with visitor for some reason.
  String commentText;
  for (var comment in allComments(node.root.beginToken)) {
    final commentLine = sourceFile.getLine(comment.end);
    if (commentLine == line || commentLine == line - 1) {
      commentText = sourceFile.getText(comment.offset, comment.end);
      break;
    }
  }

  return commentText?.contains(manualValidationCommentSubstring) ?? false;
}

/// Returns an iterable of all the comments from [beginToken] to the end of the
/// file.
///
/// Comments are part of the normal stream, and need to be accessed via
/// [Token.precedingComments], so it's difficult to iterate over them without
/// this method.
Iterable allComments(Token beginToken) sync* {
  var currentToken = beginToken;
  while (!currentToken.isEof) {
    var currentComment = currentToken.precedingComments;
    while (currentComment != null) {
      yield currentComment;
      currentComment = currentComment.next;
    }
    currentToken = currentToken.next;
  }
  ;
}

bool isInLifecycleMethod(AstNode node) {
  final lifecycleMethods = [
    'componentWillMount',
    'componentWillReceiveProps',
    'componentWillUpdate',
    'getDerivedStateFromError',
    'getDerivedStateFromProps',
    'getSnapshotBeforeUpdate',
    'shouldComponentUpdate',
    'render',
    'componentDidMount',
    'componentDidUpdate',
    'componentWillUnmount',
    'componentDidCatch'
  ];

  if (node == null) {
    return false;
  } else if (node is MethodDeclaration &&
      node.name != null &&
      lifecycleMethods.contains(node.name.toString())) {
    return true;
  } else {
    return isInLifecycleMethod(node.parent);
  }
}

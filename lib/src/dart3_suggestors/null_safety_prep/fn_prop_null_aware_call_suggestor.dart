// Copyright 2024 Workiva Inc.
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

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:over_react_codemod/src/util.dart';
import 'package:over_react_codemod/src/util/class_suggestor.dart';

/// Suggestor that replaces conditional calls to functions declared in props
/// with inline null-aware property access.
///
/// This is helpful for null-safety migrations because the conditional
/// function calls will otherwise get migrated with `!` modifiers.
///
/// **Before:**
///
/// ```dart
/// if (props.someCallback != null) {
///   props.someCallback(someValue);
/// }
///
/// // Will be migrated to:
/// if (props.someCallback != null) {
///   props.someCallback!(someValue);
/// }
/// ```
///
/// **After:**
///
/// ```dart
/// // This will require no changes during a null-safety migration.
/// props.someCallback?.call(someValue);
/// ```
class FnPropNullAwareCallSuggestor extends RecursiveAstVisitor
    with ClassSuggestor {
  ResolvedUnitResult? _result;

  @override
  visitExpressionStatement(ExpressionStatement node) {
    super.visitExpressionStatement(node);

    if (node.expression is! BinaryExpression) return;

    final relevantExprStatement =
        _getPropFunctionExpressionBeingCalledConditionally(
            node.expression as BinaryExpression);
    final inlineBinaryExpr =
        // This cast is safe due to the type checks within `_getPropFunctionExpressionBeingCalledConditionally`.
        relevantExprStatement?.expression as BinaryExpression?;
    if (inlineBinaryExpr == null) return;
    final relevantFnExpr =
        // This cast is safe due to the type checks within `_getPropFunctionExpressionBeingCalledConditionally`.
        inlineBinaryExpr.rightOperand as FunctionExpressionInvocation;
    // This cast is safe due to the type checks within `_getPropFunctionExpressionBeingCalledConditionally`.
    final fn = relevantFnExpr.function as PropertyAccess;

    yieldPatch(
        '${fn.target}.${fn.propertyName}?.call${relevantFnExpr.argumentList};',
        node.offset,
        node.end);
  }

  @override
  visitIfStatement(IfStatement node) {
    super.visitIfStatement(node);

    if (node.condition is! BinaryExpression) return;

    final relevantFnExprStatement =
        _getPropFunctionExpressionBeingCalledConditionally(
            node.condition as BinaryExpression);
    final relevantFnExpr =
        // This cast is safe due to the type checks within `_getPropFunctionExpressionBeingCalledConditionally`.
        relevantFnExprStatement?.expression as FunctionExpressionInvocation?;
    if (relevantFnExpr == null) return;
    // This cast is safe due to the type checks within `_getPropFunctionExpressionBeingCalledConditionally`.
    final fn = relevantFnExpr.function as PropertyAccess?;
    if (fn == null) return;

    yieldPatch(
        '${fn.target}.${fn.propertyName}?.call${relevantFnExpr.argumentList};',
        node.offset,
        node.end);
  }

  /// Returns the function expression (e.g. `props.onClick(event)`) being called
  /// after the null condition is checked.
  ExpressionStatement? _getPropFunctionExpressionBeingCalledConditionally(
      BinaryExpression condition) {
    final parent = condition.parent;
    if (parent is! IfStatement) return null;

    final propFunctionBeingNullChecked =
        _getPropFunctionBeingNullChecked(condition);
    final ifStatement = parent;
    if (ifStatement.elseStatement != null) return null;
    if (ifStatement.parent?.tryCast<IfStatement>()?.elseStatement ==
        ifStatement) {
      // ifStatement is an else-if
      return null;
    }
    final thenStatement = ifStatement.thenStatement;
    if (thenStatement is Block && thenStatement.statements.length == 1) {
      if (_isMatchingConditionalPropFunctionCallStatement(
          thenStatement.statements.single, propFunctionBeingNullChecked)) {
        return thenStatement.statements.single as ExpressionStatement?;
      }
    } else if (thenStatement is ExpressionStatement) {
      if (_isMatchingConditionalPropFunctionCallStatement(
          thenStatement, propFunctionBeingNullChecked)) {
        return thenStatement;
      }
    }
    return null;
  }

  bool _isMatchingConditionalPropFunctionCallStatement(
      Statement statementWithinThenStatement,
      SimpleIdentifier? propFunctionBeingNullChecked) {
    if (statementWithinThenStatement is! ExpressionStatement) return false;
    final expression = statementWithinThenStatement.expression;
    if (expression is! FunctionExpressionInvocation) return false;
    final fn = expression.function;
    if (fn is! PropertyAccess) return false;
    final target = fn.target;
    if (target is! SimpleIdentifier) return false;
    if (target.name != 'props') return false;
    return fn.propertyName.staticElement?.declaration ==
        propFunctionBeingNullChecked?.staticElement?.declaration;
  }

  /// Returns the identifier for the function that is being
  /// null checked before being called.
  SimpleIdentifier? _getPropFunctionBeingNullChecked(
      BinaryExpression condition) {
    if (condition.leftOperand is! PrefixedIdentifier) {
      return null;
    }
    final leftOperand = condition.leftOperand as PrefixedIdentifier;
    final prefix = leftOperand.prefix;
    if (prefix.name != 'props') {
      return null;
    }
    if (leftOperand.identifier.staticType is! FunctionType) {
      return null;
    }
    if (condition.operator.stringValue != '!=' &&
        condition.operator.next?.keyword != Keyword.NULL) {
      return null;
    }
    return leftOperand.identifier;
  }

  @override
  Future<void> generatePatches() async {
    _result = await context.getResolvedUnit();
    if (_result == null) {
      throw Exception(
          'Could not get resolved result for "${context.relativePath}"');
    }
    _result!.unit.accept(this);
  }
}

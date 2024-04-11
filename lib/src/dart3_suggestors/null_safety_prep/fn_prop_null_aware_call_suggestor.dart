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
import 'package:collection/collection.dart';
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
    if (condition.parent is IfStatement) {
      //
      // Handles conditions of the form:
      // if (props.fn != null) { ... }
      //

      final propFunctionBeingNullChecked =
          _getPropFunctionBeingNullChecked(condition);
      final ifStatement = condition.parent! as IfStatement;
      if (ifStatement.elseStatement != null) return null;
      if (ifStatement.parent
              ?.thisOrAncestorOfType<IfStatement>()
              ?.elseStatement !=
          null) {
        // There is an else-if statement present
        return null;
      }

      return (ifStatement.thenStatement as Block)
          .statements
          .singleWhereOrNull((element) {
        if (element is! ExpressionStatement) return false;
        final expression = element.expression;
        if (expression is! FunctionExpressionInvocation) return false;
        final fn = expression.function;
        if (fn is! PropertyAccess) return false;
        final target = fn.target;
        if (target is! SimpleIdentifier) return false;
        if (target.name != 'props') return false;
        final matches = fn.propertyName.staticElement?.declaration ==
            propFunctionBeingNullChecked?.staticElement?.declaration;
        return matches;
      }) as ExpressionStatement?;
    } else if (condition.parent is ExpressionStatement &&
        condition.leftOperand is BinaryExpression) {
      //
      // Handles conditions of the form:
      // props.fn != null && ...
      //
      final propFunctionBeingNullChecked = _getPropFunctionBeingNullChecked(
          condition.leftOperand as BinaryExpression);
      if (propFunctionBeingNullChecked == null) return null;

      if (condition.rightOperand is! FunctionExpressionInvocation) return null;
      final fn =
          (condition.rightOperand as FunctionExpressionInvocation).function;
      if (fn is! PropertyAccess) return null;
      final target = fn.target;
      if (target is! SimpleIdentifier) return null;
      if (target.name != 'props') return null;
      final matches = fn.propertyName.staticElement?.declaration ==
          propFunctionBeingNullChecked.staticElement?.declaration;
      if (!matches) return null;
      return condition.parent as ExpressionStatement?;
    }

    return null;
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

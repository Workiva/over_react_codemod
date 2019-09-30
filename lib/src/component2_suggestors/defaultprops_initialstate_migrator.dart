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
import 'package:meta/meta.dart';
import 'package:over_react_codemod/src/component2_suggestors/component2_utilities.dart';

/// Abstract suggestor with visitor that can migrate `getDefaultProps`
/// or `getInitialState`.
///
/// Use [GetDefaultPropsMigrator] or [GetInitialStateMigrator].
abstract class DefaultPropsInitialStateMigrator extends GeneralizingAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  final bool allowPartialUpgrades;
  final bool shouldUpgradeAbstractComponents;
  final String methodToMigrate;
  final String migrateTo;

  DefaultPropsInitialStateMigrator({
    @required this.methodToMigrate,
    @required this.migrateTo,
    this.allowPartialUpgrades = true,
    this.shouldUpgradeAbstractComponents = false,
  });

  @override
  visitMethodDeclaration(MethodDeclaration node) {
    super.visitMethodDeclaration(node);

    var containingClass = node.parent;

    if ((!allowPartialUpgrades &&
            !fullyUpgradableToComponent2(containingClass)) ||
        (!shouldUpgradeAbstractComponents &&
            canBeExtendedFrom(containingClass))) {
      return;
    }

    if (extendsComponent2(containingClass) &&
        node.name.name == methodToMigrate) {
      // Remove return type.
      if (node.returnType != null) {
        yieldPatch(
          node.returnType.offset,
          node.returnType.end,
          '',
        );
      }

      // Replace with getter.
      yieldPatch(
        node.name.offset,
        node.parameters.end,
        'get $migrateTo',
      );

      if (node.body is BlockFunctionBody) {
        var methodBody = (node.body as BlockFunctionBody).block;

        if (methodBody.statements.length == 1 &&
            methodBody.statements.single is ReturnStatement) {
          var returnStatement = methodBody.statements.single as ReturnStatement;

          updateSuperCalls(returnStatement.returnKeyword.end,
              returnStatement.semicolon.offset);

          // Convert to arrow function if method body is a single return.
          yieldPatch(
            methodBody.leftBracket.offset,
            returnStatement.returnKeyword.end,
            '=> (',
          );
          yieldPatch(
            returnStatement.semicolon.offset,
            returnStatement.semicolon.offset,
            '\n)',
          );
          yieldPatch(
            methodBody.rightBracket.offset,
            methodBody.rightBracket.end,
            '',
          );
        } else {
          updateSuperCalls(
              methodBody.leftBracket.end, methodBody.rightBracket.offset);
        }
      } else if (node.body is ExpressionFunctionBody) {
        var expression = (node.body as ExpressionFunctionBody).expression;

        updateSuperCalls(expression.offset, expression.end);

        String subMethod;
        if (methodToMigrate == 'getDefaultProps') {
          subMethod = 'newProps';
        } else {
          subMethod = 'newState';
        }

        // Add parenthesis if needed.
        if (expression is! ParenthesizedExpression &&
            expression is CascadeExpression &&
            expression.target is MethodInvocation &&
            (expression.target as MethodInvocation).methodName.name ==
                subMethod) {
          yieldPatch(
            expression.offset,
            expression.offset,
            '(',
          );
          yieldPatch(
            expression.end,
            expression.end,
            '\n)',
          );
        }
      }
    }
  }

  /// Updates all super calls to [methodToMigrate] from [start] to [end].
  void updateSuperCalls(int start, int end) {
    var methodBodyString = sourceFile.getText(start, end);
    if (methodBodyString.contains('super.$methodToMigrate()')) {
      methodBodyString = methodBodyString.replaceAll(
        'super.$methodToMigrate()',
        'super.$migrateTo',
      );
      yieldPatch(start, end, methodBodyString);
    }
  }
}

/// Suggestor that replaces `getDefaultProps` method with getter `defaultProps`.
class GetDefaultPropsMigrator extends DefaultPropsInitialStateMigrator
    implements Suggestor {
  GetDefaultPropsMigrator({
    bool allowPartialUpgrades = true,
    bool shouldUpgradeAbstractComponents = false,
  }) : super(
          methodToMigrate: 'getDefaultProps',
          migrateTo: 'defaultProps',
          allowPartialUpgrades: allowPartialUpgrades,
          shouldUpgradeAbstractComponents: shouldUpgradeAbstractComponents,
        );
}

/// Suggestor that replaces `getInitialState` method with getter `initialState`.
class GetInitialStateMigrator extends DefaultPropsInitialStateMigrator
    implements Suggestor {
  GetInitialStateMigrator({
    bool allowPartialUpgrades = true,
    bool shouldUpgradeAbstractComponents = false,
  }) : super(
          methodToMigrate: 'getInitialState',
          migrateTo: 'initialState',
          allowPartialUpgrades: allowPartialUpgrades,
          shouldUpgradeAbstractComponents: shouldUpgradeAbstractComponents,
        );
}

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
import 'package:over_react_codemod/src/component2_suggestors/component2_utilities.dart';

/// Suggestor that replaces `getDefaultProps` with the getter `defaultProps`.
class GetDefaultPropsMigrator extends GeneralizingAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  final bool allowPartialUpgrades;
  final bool shouldUpgradeAbstractComponents;

  GetDefaultPropsMigrator({
    this.allowPartialUpgrades = true,
    this.shouldUpgradeAbstractComponents = false,
  });

  @override
  visitMethodDeclaration(MethodDeclaration node) {
    super.visitMethodDeclaration(node);

    ClassDeclaration containingClass = node.parent;

    if ((!allowPartialUpgrades &&
            !fullyUpgradableToComponent2(containingClass)) ||
        (!shouldUpgradeAbstractComponents &&
            canBeExtendedFrom(containingClass))) {
      return;
    }

    if (extendsComponent2(containingClass)) {
      if (node.name.name == 'getDefaultProps') {
        // Remove return type.
        if (node.returnType != null) {
          yieldPatch(
            node.returnType.offset,
            node.returnType.end,
            '',
          );
        }

        // Update super calls.
        var methodBodyString =
            sourceFile.getText(node.body.offset, node.body.end);
        if (methodBodyString.contains('super.getDefaultProps()')) {
          methodBodyString = methodBodyString.replaceAll(
            'super.getDefaultProps()',
            'super.defaultProps',
          );
          yieldPatch(node.body.offset, node.body.end, methodBodyString);
        }

        // Replace with getter.
        yieldPatch(
          node.name.offset,
          node.parameters.end,
          'get defaultProps',
        );

        if (node.body is BlockFunctionBody) {
          var methodBody = (node.body as BlockFunctionBody).block;

          // Convert to arrow function if method body is a single return.
          if (methodBody.statements.length == 1 &&
              methodBody.statements.single is ReturnStatement) {
            var returnStatement =
                (methodBody.statements.single as ReturnStatement);
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
          }
        } else if (node.body is ExpressionFunctionBody) {
          var expression = (node.body as ExpressionFunctionBody).expression;
          if (expression.beginToken.toString() != '(') {
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
  }
}

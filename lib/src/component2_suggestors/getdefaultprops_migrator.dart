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

//        var a;
//        if(node.body is ExpressionFunctionBody) {
//          a = (node.body as ExpressionFunctionBody).expression.childEntities;
//        }

        var methodBody = sourceFile.getText(node.body.offset, node.body.end);
        if(methodBody.contains('super.getDefaultProps()')) {
          methodBody = methodBody.replaceAll(
            'super.getDefaultProps()',
            'super.defaultProps',
          );
          yieldPatch(node.body.offset, node.body.end, methodBody);
        }

        // Replace with getter.
        yieldPatch(
          node.name.offset,
          node.parameters.end,
          'get defaultProps',
        );
      }
    }
  }
}

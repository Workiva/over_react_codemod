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
import 'package:over_react_codemod/src/react16_suggestors/react16_utilities.dart';

import 'component2_constants.dart';
import 'component2_utilities.dart';

/// Suggestor that transitions `componentWillMount` to `componentDidMount` to
/// be compatible with UiComponent2.
class ComponentWillMountMigrator extends GeneralizingAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  final bool allowPartialUpgrades;

  ComponentWillMountMigrator({this.allowPartialUpgrades = true});

  @override
  visitMethodDeclaration(MethodDeclaration node) {
    super.visitMethodDeclaration(node);

    ClassDeclaration containingClass = node.parent;

    if (!allowPartialUpgrades &&
        !fullyUpgradableToComponent2(containingClass)) {
      return;
    }

    MethodDeclaration componentDidMountMethodDecl =
        containingClass.members.firstWhere(
      (member) =>
          member is MethodDeclaration &&
          member.name.name == 'componentDidMount',
      orElse: () => null,
    );

    if (extendsComponent2(containingClass) &&
        node.name.name == 'componentWillMount') {
      if (componentDidMountMethodDecl != null) {
        if (node.body is BlockFunctionBody) {
          bool hasSuperCall = componentDidMountMethodDecl.body
              .toSource()
              .contains('super.componentDidMount();');
          String methodBody =
              (node.body as BlockFunctionBody).block.statements.join('\n');

          // Update or remove super call.
          if (methodBody.contains('super.componentWillMount();')) {
            methodBody = methodBody.replaceAll(
              'super.componentWillMount();\n',
              hasSuperCall ? '' : 'super.componentDidMount();\n',
            );
          }

          // Move body of `componentWillMount` to end of `componentDidMount`.
          yieldPatch(
            componentDidMountMethodDecl.body.endToken.offset,
            componentDidMountMethodDecl.body.endToken.offset,
            methodBody,
          );
        }

        // Copy any annotations not already present to `componentDidMount`.
        String annotationsToAdd = '';
        node.metadata.forEach((annotation) {
          if (!componentDidMountMethodDecl.metadata
              .toString()
              .contains(annotation.toSource())) {
            annotationsToAdd += annotation.toSource() + '\n';
          }
        });

        if (annotationsToAdd.isNotEmpty) {
          yieldPatch(
            componentDidMountMethodDecl.offset,
            componentDidMountMethodDecl.offset,
            annotationsToAdd,
          );
        }

        // Remove `componentWillMount` method.
        yieldPatch(
          node.offset,
          node.end,
          '',
        );
      } else {
        // Rename `componentWillMount` to `componentDidMount` and add comment
        // to check super calls.
        if (!hasComment(node, sourceFile, componentWillMountMessage)) {
          yieldPatch(
            node.offset,
            node.offset,
            '$componentWillMountMessage\n',
          );
        }
        yieldPatch(
          node.name.offset,
          node.name.end,
          'componentDidMount',
        );

        if (node.body is BlockFunctionBody) {
          NodeList statementList =
              (node.body as BlockFunctionBody).block.statements;

          statementList.forEach((statement) {
            if (statement
                .toSource()
                .startsWith('super.componentWillMount();')) {
              yieldPatch(
                statement.offset,
                statement.end,
                'super.componentDidMount();',
              );
            }
          });
        }
      }
    }
  }
}

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

import '../constants.dart';

/// Suggestor that migrates consumer overlay prop names in component usages.
class ConsumerOverlayMigrator extends GeneralizingAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  @override
  visitCascadeExpression(CascadeExpression node) {
    super.visitCascadeExpression(node);

    final containingClass = node.thisOrAncestorOfType<ClassDeclaration>();

    var extendsName = containingClass?.extendsClause?.superclass?.name;
    if (extendsName == null) {
      return;
    }

    String reactImportName =
        getImportNamespace(containingClass, 'package:react/react.dart');

    // Check if usage is in a component class.
    if (extendsName.name != '$reactImportName.Component' &&
        extendsName.name != '$reactImportName.Component2' &&
        !containingClass.metadata.any((m) =>
            overReact16ComponentAnnotationNamesToMigrate
                .contains(m.name.name) ||
            overReact16Component2AnnotationNames.contains(m.name.name))) {
      return;
    }

    // Update consumer overlay props.
    for (AssignmentExpression expression
        in node.cascadeSections.whereType<AssignmentExpression>()) {
      final leftHandSide = expression.leftHandSide;

      if (leftHandSide.toSource() == '..overlay' ||
          leftHandSide.toSource() == '..isOverlay') {
        yieldPatch(leftHandSide.end, leftHandSide.end, '2');
      } else if (leftHandSide.toSource() == '..useLegacyPositioning') {
        yieldPatch(expression.offset, expression.end, '');
      }
    }
  }
}

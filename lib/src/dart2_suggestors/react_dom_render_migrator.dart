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
import 'package:codemod/codemod.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';

/// Suggestor that migrates `react_dom.render` usages to be compatible with
/// React 16 and inserts comments in situations where validation is required.
class ReactDomRenderMigrator extends GeneralizingAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  @override
  visitMethodInvocation(MethodInvocation node) {
    final parent = node.parent;

    if (node.methodName.name == 'render' &&
        const ['react_dom', 'reactDom'].contains(node.realTarget.toSource()) &&
        (parent is VariableDeclaration || parent is AssignmentExpression)) {
      String refVariableName;

      // Edit assignment
      if (parent is VariableDeclaration) {
        // > Instances of this class are always children of the class [VariableDeclarationList]
        yieldPatch(parent.parent.offset, parent.parent.offset,
            '// TODO validate typing and safety of ref\n');
        yieldPatch(parent.equals.offset, parent.equals.end, ';');
        refVariableName = parent.name.name;
      } else if (parent is AssignmentExpression) {
        yieldPatch(parent.offset, parent.offset,
            '// TODO validate typing and safety of ref\n');
        yieldPatch(parent.offset, parent.rightHandSide.offset, '');
        refVariableName = parent.leftHandSide.toSource();
      } else {
        throw StateError('should never get here');
      }

      // add the ref
      FluentComponentUsage usage;

      final renderFirstArg = node.argumentList.arguments.first;
      if (renderFirstArg is InvocationExpression) {
        usage = getComponentUsage(renderFirstArg);
      }
      if (usage != null) {
        final builderExpression = usage.node.function;
        if (builderExpression is! ParenthesizedExpression) {
          yieldPatch(builderExpression.offset, builderExpression.offset, '(');
        }
        yieldPatch(usage.builder.end, usage.builder.end,
            '\n  ..ref = (ref) { $refVariableName = ref; }\n');
        if (builderExpression is! ParenthesizedExpression) {
          yieldPatch(builderExpression.end, builderExpression.end, ')');
        }

        // todo check for existing ref
      } else {
        yieldPatch(node.offset, node.offset,
            '// FIXME manually verify that ref is used on this component expreession \n');
      }
    }

    super.visitMethodInvocation(node);
  }
}

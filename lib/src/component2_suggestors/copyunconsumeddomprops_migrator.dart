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

import 'component2_utilities.dart';

/// Suggestor that updates `copyUnconsumedDomProps` and `copyUnconsumedProps` usages.
class CopyUnconsumedDomPropsMigrator extends GeneralizingAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  final bool shouldUpgradeAbstractComponents;

  CopyUnconsumedDomPropsMigrator({this.shouldUpgradeAbstractComponents = false});

  @override
  visitMethodInvocation(MethodInvocation node) {
    super.visitMethodInvocation(node);

    ClassDeclaration containingClass = node.thisOrAncestorMatching((ancestor) {
      return ancestor is ClassDeclaration;
    });

    if (extendsComponent2(containingClass)) {
      if (node.methodName.name == 'addProps') {
        var firstArg = node.argumentList.arguments.first;

        if (firstArg.toSource() == 'copyUnconsumedDomProps()' ||
            firstArg.toSource() == 'copyUnconsumedProps()') {
          // Update argument.
          yieldPatch(firstArg.offset, firstArg.end,
              'addUnconsumed${firstArg.toSource().contains('Dom') ? 'Dom' : ''}Props');

          // Rename `addProps` to `modifyProps`.
          yieldPatch(
              node.methodName.offset, node.methodName.end, 'modifyProps');
        }
      }
    }
  }
}

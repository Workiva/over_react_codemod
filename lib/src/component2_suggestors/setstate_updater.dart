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

import 'component2_utilities.dart';

/// Suggestor that updates a [setState] call to [setStateWithUpdater] in the
/// case that the first argument is a function.
class SetStateUpdater extends GeneralizingAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  final bool noPartialUpgrades;

  SetStateUpdater({this.noPartialUpgrades = false});

  @override
  visitMethodInvocation(MethodInvocation node) {
    super.visitMethodInvocation(node);

    ClassDeclaration containingClass = node.thisOrAncestorMatching((ancestor) {
      return ancestor is ClassDeclaration;
    });

    if(noPartialUpgrades && !canBeFullyUpgradedToComponent2(containingClass)) {
      return;
    }

    if (extendsComponent2(containingClass)) {
      if (node.argumentList.arguments.isEmpty) return;

      final firstArg = node.argumentList.arguments.first;

      if (node.methodName.name == 'setState') {
        if (firstArg is FunctionExpression) {
          yieldPatch(
            node.methodName.offset,
            node.methodName.end,
            'setStateWithUpdater',
          );
        }
      }
    }
  }
}

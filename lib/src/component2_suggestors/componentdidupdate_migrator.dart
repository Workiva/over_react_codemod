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

/// Suggestor that adds an optional `snapshot` argument to `componentDidUpdate`.
class ComponentDidUpdateMigrator extends GeneralizingAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  ComponentDidUpdateMigrator();

  @override
  visitMethodDeclaration(MethodDeclaration node) {
    super.visitMethodDeclaration(node);

    if (node.name.toString() == 'componentDidUpdate') {
      var lastArg =
          node.parameters.childEntities.lastWhere((t) => t.toString() != ')');

      if (lastArg.toString() != ']') {
        yieldPatch(lastArg.end, lastArg.end, ', [snapshot]');
      }
    }
  }
}

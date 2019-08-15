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

import './component2_constants.dart';
import '../constants.dart';
import '../util.dart';

/// Suggestor that adds a "fix me" comment prompting consumers to update
/// [componentWillReceiveProps] and [componentWillUpdate] to their respective
/// React 16 versions.
class DeprecatedLifecycleSuggestor extends GeneralizingAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  @override
  visitMethodDeclaration(MethodDeclaration node) {
    super.visitMethodDeclaration(node);
    ClassDeclaration containingClass = node.parent;
    if (containingClass.metadata
        .any((m) => overReact16AnnotationNames.contains(m.name.name))) {
      var deprecatedLifecycleMethods = [
        'componentWillUpdate',
        'componentWillReceiveProps',
      ];

      if (deprecatedLifecycleMethods.contains(node.name.name)) {
        if (!hasComment(node, sourceFile,
            'FIXME: [${node.name.name}] has been deprecated')) {
          yieldPatch(
            node.offset,
            node.offset,
            '${getDeperecationMessage(node.name.name)}\n',
          );
        }
      }
    }
  }
}

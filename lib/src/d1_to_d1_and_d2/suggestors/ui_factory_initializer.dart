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

import '../../constants.dart';
import '../../util.dart';

/// Suggestor that inserts the expected initializer value for all `UiFactory`
/// declarations.
class UiFactoryInitializer extends RecursiveAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  static final RegExp factoryAnnotationPattern =
      RegExp(r'^@Factory\(', multiLine: true);

  @override
  bool shouldSkip(String sourceFileContents) =>
      !factoryAnnotationPattern.hasMatch(sourceFileContents);

  @override
  visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    super.visitTopLevelVariableDeclaration(node);

    // Look for a top-level variable that is annotated with @Factory()
    if (!node.metadata.any((annotation) => annotation.name.name == 'Factory')) {
      return;
    }

    // There can only be one UiFactory per file.
    final factoryNode = node?.variables?.variables?.first;
    if (factoryNode == null) {
      // throw new
      return;
    }

    final targetInitializer =
        '${privateGeneratedPrefix}${factoryNode.name.name}';
    final targetInitializerWithComment = [
      // Insert a line break to avoid the situation where a dartfmt run may
      // separate the ignore comment from the initializer value.
      '\n',
      '    ${buildIgnoreComment(undefinedIdentifier: true)}\n'
          '    $targetInitializer',
    ].join();

    final currentInitializer = factoryNode.initializer?.toSource()?.trim();
    if (currentInitializer == targetInitializer) {
      // Already initalized to the expected value.
      return;
    }

    if (factoryNode.initializer != null) {
      // Initializer exits, but does not match the expected value.
      yieldPatch(
        factoryNode.equals.end,
        factoryNode.initializer.end,
        targetInitializerWithComment,
      );
    } else {
      // Initializer does not yet exist.
      yieldPatch(
        factoryNode.name.end,
        factoryNode.end,
        ' =' + targetInitializerWithComment,
      );
    }
  }
}

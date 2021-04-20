// Copyright 2020 Workiva Inc.
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

/// Suggestor that moves the `// ignore: ...` comment attached to each
/// over_react factory from the line before the initializer
/// to after the semicolon.
class FactoryIgnoreCommentMover extends RecursiveAstVisitor
    with AstVisitingSuggestor {
  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    final type = node.variables.type;
    if (!(type is NamedType && type.name.name == 'UiFactory')) {
      return;
    }

    final initializer = node.variables.variables.first.initializer;
    if (initializer == null) return;

    final comment = initializer.beginToken.precedingComments;
    if (comment == null) return;

    final commentText = context.sourceFile.getText(comment.offset, comment.end);
    if (commentText.contains('ignore: undefined_identifier')) {
      yieldPatch('', comment.offset, comment.end);
      yieldPatch(' // ignore: undefined_identifier', node.end, node.end);
    }
  }
}

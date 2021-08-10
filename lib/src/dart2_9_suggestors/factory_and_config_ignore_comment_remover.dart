// Copyright 2021 Workiva Inc.
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
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:codemod/codemod.dart';
import 'package:over_react_codemod/src/dart2_9_suggestors/dart2_9_utilities.dart';
import 'package:over_react_codemod/src/util.dart';

/// Suggestor that removes ignore comments from generated factory initializers
/// and factory config arguments.
class FactoryAndConfigIgnoreCommentRemover extends RecursiveAstVisitor
    with AstVisitingSuggestor {
  /// The name of the error that should be removed from ignore comments.
  ///
  /// Example: 'undefined_identifier'
  final String ignoreToRemove;

  /// Removes [ignoreToRemove] from ignore comments on component factory
  /// declarations and factory config arguments.
  FactoryAndConfigIgnoreCommentRemover(this.ignoreToRemove);

  @override
  visitArgumentList(ArgumentList node) {
    super.visitArgumentList(node);

    final generatedArg = getGeneratedFactoryConfigArg(node);
    if (generatedArg != null) {
      for (final comment in _findPossibleIgnoreComments(generatedArg)) {
        removeIgnoreComment(comment, ignoreToRemove, yieldPatch);
      }
    }
  }

  @override
  visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    super.visitTopLevelVariableDeclaration(node);

    if (isClassOrConnectedComponentFactory(node) &&
        !isLegacyFactoryDecl(node)) {
      final generatedFactory = getGeneratedFactory(node)!;
      for (final comment in _findPossibleIgnoreComments(generatedFactory)) {
        removeIgnoreComment(comment, ignoreToRemove, yieldPatch);
      }

      removeIgnoreComment(
          node.beginToken.precedingComments, ignoreToRemove, yieldPatch);
    }
  }

  @override
  bool shouldSkip(FileContext context) => hasParseErrors(context.sourceText);

  Iterable<Token> _findPossibleIgnoreComments(
      SimpleIdentifier generatedFactoryNode) sync* {
    final lineNumber = context.sourceFile.getLine(generatedFactoryNode.offset);
    for (var comment in allComments(generatedFactoryNode.root.beginToken)) {
      final commentLineNumber = context.sourceFile.getLine(comment.offset);
      final commentAppliesToNode =
          // EOL comments
          commentLineNumber == lineNumber ||
              // Comments on the previous line
              commentLineNumber == lineNumber - 1;
      if (commentAppliesToNode) {
        yield comment;
      }
    }
  }
}

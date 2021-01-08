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
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:codemod/codemod.dart';
import 'package:over_react_codemod/src/dart2_9_suggestors/dart2_9_utilities.dart';

import '../util.dart';

/// Suggestor that removes ignore comments from component factory declarations
/// and factory config arguments.
class FactoryAndConfigIgnoreCommentRemover extends RecursiveAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
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

    final generatedArg = getGeneratedArg(node);
    if (generatedArg != null) {
      // ```
      // Check comments before the config.
      // Example:
      // ```
      // final Foo = uiFunction<FooProps>(
      //   (props) {},
      //   // ignore: undefined_identifier
      //   $FooConfig,
      // );
      // ```
      removeIgnoreComment(
        generatedArg.token.precedingComments,
        ignoreToRemove,
        yieldPatch,
      );

      // Check comments after the config.
      // Example:
      // ```
      // final Foo = uiFunction<FooProps>(
      //   (props) {},
      //   $FooConfig, // ignore: undefined_identifier
      // );
      // ```
      if (generatedArg.token.next.lexeme == ',') {
        removeIgnoreComment(
          generatedArg.token.next?.next?.precedingComments,
          ignoreToRemove,
          yieldPatch,
        );
      }

      // Check comments after the type casted config.
      // Example:
      // ```
      // final Foo = uiFunction<FooProps>(
      //   (props) {},
      //   _$FooConfig as UiFactoryConfig<FooProps>, // ignore: undefined_identifier
      // );
      // ```
      if (generatedArg.parent is AsExpression &&
          generatedArg.parent.endToken.next?.lexeme == ',') {
        removeIgnoreComment(
          generatedArg.parent?.endToken?.next?.next?.precedingComments,
          ignoreToRemove,
          yieldPatch,
        );
      }

      // Check comments after the semicolon.
      // Example:
      // ```
      // final Foo = uiFunction<FooProps>(
      //   (props) {},
      //   $FooConfig); // ignore: undefined_identifier
      // ```
      if (node.rightParenthesis.next?.lexeme == ';') {
        removeIgnoreComment(
          node.rightParenthesis.next.next?.precedingComments,
          ignoreToRemove,
          yieldPatch,
        );
      }
    }
  }

  @override
  visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    super.visitTopLevelVariableDeclaration(node);

    final annotation = node.metadata?.firstWhere(
        (m) => m.toSource().startsWith('@Factory'),
        orElse: () => null);
    if (isClassComponentFactory(node) && annotation == null) {
      // Check comments after semicolon.
      // Example:
      // `UiFactory<FooProps> Foo = _$Foo; // ignore: undefined_identifier`
      removeIgnoreComment(
        node.semicolon?.next?.precedingComments,
        ignoreToRemove,
        yieldPatch,
      );

      // Check comments before generated initializer.
      // Example:
      // ```
      // UiFactory<FooProps> Foo =
      //    // ignore: undefined_identifier
      //    _$Foo;
      // ```
      removeIgnoreComment(
        node.variables?.variables?.first?.initializer?.beginToken
            ?.precedingComments,
        ignoreToRemove,
        yieldPatch,
      );

      // Check comments on previous line.
      // Example:
      // ```
      // // ignore: undefined_identifier
      // UiFactory<FooProps> Foo = _$Foo;
      // ```
      removeIgnoreComment(
        node.beginToken.precedingComments,
        ignoreToRemove,
        yieldPatch,
      );

      // Check comments after doc comments.
      // Example:
      // ```
      // /// This is a doc comment.
      // // ignore: undefined_identifier
      // UiFactory<FooProps> Foo = _$Foo;
      // ```
      removeIgnoreComment(
        node.documentationComment?.beginToken,
        ignoreToRemove,
        yieldPatch,
      );
    }
  }
}

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

/// Suggestor that removes `// ignore: undefined_identifier` comments from
/// component factory declarations and factory config arguments.
class UndefinedIdentifierIgnoreCommentRemover extends RecursiveAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  static const String _undefinedIdentifierComment = 'undefined_identifier';

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
      //   _$FooConfig,
      // );
      // ```
      removeIgnoreComment(
        generatedArg.token.precedingComments,
        _undefinedIdentifierComment,
        yieldPatch,
      );

      // Check comments after the config.
      // Example:
      // ```
      // final Foo = uiFunction<FooProps>(
      //   (props) {},
      //   _$FooConfig, // ignore: undefined_identifier
      // );
      // ```
      if (generatedArg.token.next.lexeme == ',') {
        removeIgnoreComment(
          generatedArg.token.next?.next?.precedingComments,
          _undefinedIdentifierComment,
          yieldPatch,
        );
      }

      // Check comments after the semicolon.
      // Example:
      // ```
      // final Foo = uiFunction<FooProps>(
      //   (props) {},
      //   _$FooConfig); // ignore: undefined_identifier
      // ```
      if (node.rightParenthesis.next?.lexeme == ';') {
        removeIgnoreComment(
          node.rightParenthesis.next.next?.precedingComments,
          _undefinedIdentifierComment,
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
        _undefinedIdentifierComment,
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
        _undefinedIdentifierComment,
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
        _undefinedIdentifierComment,
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
        _undefinedIdentifierComment,
        yieldPatch,
      );
    }
  }
}

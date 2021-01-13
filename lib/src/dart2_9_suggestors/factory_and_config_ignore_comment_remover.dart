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
import 'package:over_react_codemod/src/dart2_9_suggestors/dart2_9_constants.dart';
import 'package:over_react_codemod/src/dart2_9_suggestors/dart2_9_utilities.dart';

/// Suggestor that removes ignore comments from generated factory initializers
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

    final generatedArg =
        getGeneratedFactoryConfigArg(node) ?? getGeneratedFactoryArg(node);
    if (generatedArg != null) {
      final commentList = List<Token>();

      // Check comments before the generated argument.
      // Example:
      // ```
      // final Foo = uiFunction<FooProps>(
      //   (props) {},
      //   // ignore: undefined_identifier
      //   $FooConfig,
      // );
      // ```
      commentList.addIfNotNull(generatedArg.token.precedingComments);

      // Check comments after the comma.
      // Example:
      // ```
      // final Foo = uiFunction<FooProps>(
      //   (props) {},
      //   $FooConfig, // ignore: undefined_identifier
      // );
      // ```
      if (generatedArg.token.next.lexeme == ',') {
        commentList
            .addIfNotNull(generatedArg.token.next?.next?.precedingComments);
      }

      // Check comments after the semicolon.
      // Example:
      // ```
      // final Foo = uiFunction<FooProps>(
      //   (props) {},
      //   $FooConfig); // ignore: undefined_identifier
      // ```
      if (node.rightParenthesis.next?.lexeme == ';') {
        commentList
            .addIfNotNull(node.rightParenthesis.next.next?.precedingComments);
      }

      final method = generatedArg.thisOrAncestorOfType<MethodInvocation>();
      if (method?.methodName?.name == castFunctionName &&
          !generatedArg.name.endsWith('Config')) {
        // Check comments before the type cast function call.
        // Example:
        // ```
        // UiFactory<FooProps> Foo = connect<SomeState, FooProps>()(
        //   // ignore: undefined_identifier
        //   castUiFactory(_$Foo),
        // );
        // ```
        commentList.addIfNotNull(method.methodName.token.precedingComments);

        // Check comments after the type cast function call.
        // Example:
        // ```
        // UiFactory<FooProps> Foo = connect<SomeState, FooProps>()(
        //   castUiFactory(_$Foo), // ignore: undefined_identifier
        // );
        // ```
        if (method.endToken.next?.lexeme == ',') {
          commentList
              .addIfNotNull(method.endToken.next?.next?.precedingComments);
        }
      }

      for (final comment in commentList) {
        removeIgnoreComment(comment, ignoreToRemove, yieldPatch);
      }
    }
  }

  @override
  visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    super.visitTopLevelVariableDeclaration(node);

    if (isClassComponentFactory(node) && !isLegacyFactoryDecl(node)) {
      final commentList = List<Token>();

      // Check comments after semicolon.
      // Example:
      // `UiFactory<FooProps> Foo = _$Foo; // ignore: undefined_identifier`
      commentList.addIfNotNull(node.semicolon?.next?.precedingComments);

      // Check comments before generated initializer.
      // Example:
      // ```
      // UiFactory<FooProps> Foo =
      //    // ignore: undefined_identifier
      //    _$Foo;
      // ```
      commentList.addIfNotNull(node.variables?.variables?.first?.initializer
          ?.beginToken?.precedingComments);

      // Check comments on previous line.
      // Example:
      // ```
      // // ignore: undefined_identifier
      // UiFactory<FooProps> Foo = _$Foo;
      // ```
      commentList.addIfNotNull(node.beginToken.precedingComments);

      // Check comments after doc comments.
      // Example:
      // ```
      // /// This is a doc comment.
      // // ignore: undefined_identifier
      // UiFactory<FooProps> Foo = _$Foo;
      // ```
      commentList.addIfNotNull(node.documentationComment?.beginToken);

      for (final comment in commentList) {
        removeIgnoreComment(comment, ignoreToRemove, yieldPatch);
      }
    }
  }
}

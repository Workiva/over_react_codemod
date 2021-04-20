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

/// Suggestor that inserts the expected initializer value for all `UiFactory`
/// declarations.
class UiFactoryIgnoreCommentRemover extends RecursiveAstVisitor
    with AstVisitingSuggestor {
  static final RegExp factoryAnnotationPattern =
      RegExp(r'^@Factory\(', multiLine: true);

  static final RegExp ignorePattern = RegExp(
      r'\s*\/\/[ ]*ignore:[ ]*undefined_identifier[ ]*$',
      multiLine: true);

  List<int> _ignoreLines = [];

  @override
  bool shouldSkip(FileContext context) =>
      !factoryAnnotationPattern.hasMatch(context.sourceText);

  @override
  visitCompilationUnit(CompilationUnit node) {
    // Find all of the lines that have the specific ignore comment that we're
    // looking to remove. Also adding one to each of these line numbers since
    // it should always be targeting the next line.
    _ignoreLines = ignorePattern
        .allMatches(context.sourceText)
        .map((match) => context.sourceFile.getLine(match.end) + 1)
        .toList();

    super.visitCompilationUnit(node);
  }

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
      return;
    }

    // If there is no initializer, then there won't be an ignore comment either.
    if (factoryNode.initializer == null) {
      return;
    }

    // If an ignore line was found on the line before the initializer, then we
    // need to remove it. To do this, we just replace the entire initializer
    // with the same value, but without the comment.
    final initializerLineNum =
        context.sourceFile.getLine(factoryNode.initializer.offset);
    if (_ignoreLines.contains(initializerLineNum)) {
      final currentFactory = context.sourceFile
          .span(
            node.metadata.beginToken.offset,
            node.end,
          )
          .text;
      final updatedFactory = currentFactory.replaceFirst(ignorePattern, '');
      yieldPatch(
        updatedFactory,
        node.metadata.beginToken.offset,
        node.end,
      );
    }
  }
}

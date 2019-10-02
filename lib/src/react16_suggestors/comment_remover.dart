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
import 'package:over_react_codemod/src/react16_suggestors/react16_utilities.dart';

/// Suggestor that removes a block of comments based on the beginning and end
/// of the comments.
class CommentRemover extends GeneralizingAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  final Pattern startString;
  final Pattern endString;

  CommentRemover(this.startString, this.endString);

  @override
  visitCompilationUnit(CompilationUnit node) {
    super.visitCompilationUnit(node);

    int startingOffset;
    int endingOffset;

    for (var comment in allComments(node.root.beginToken)) {
      final commentText = sourceFile.getText(comment.offset, comment.end);

      if (commentText.contains(startString) && startingOffset == null) {
        startingOffset = comment.offset;
      }

      if (commentText.contains(endString) &&
          startingOffset != null &&
          endingOffset == null) {
        endingOffset = comment.end;
      }

      if (startingOffset != null && endingOffset != null) {
        try {
          yieldPatch(startingOffset, endingOffset, '');
          startingOffset = null;
          endingOffset = null;
        } catch (e, st) {
          throw StateError('$e\n$st');
        }
      }
    }
  }
}

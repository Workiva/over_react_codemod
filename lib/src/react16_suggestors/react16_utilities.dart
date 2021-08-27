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
import 'package:over_react_codemod/src/util.dart';
import 'package:source_span/source_span.dart';

import 'constants.dart';

export 'package:over_react_codemod/src/util.dart' show allComments;

/// Returns whether or not the source file contains the React 16 validation
/// required comment.
///
/// Related: [hasComment]
bool hasValidationComment(AstNode node, SourceFile sourceFile) {
  return hasComment(node, sourceFile, manualValidationCommentSubstring);
}

/// Returns whether or not the node passed in has the passed in comment above
/// or below it.
///
/// Can be used to determine whether or not the file has been modified
/// already. This is useful (in combination with [allComments] because the
/// visitor used for visiting comments does not work as expected, making it
/// difficult to iterate over comments.
bool hasComment(AstNode node, SourceFile sourceFile, String comment) {
  final line = sourceFile.getLine(node.offset);

  // Find the comment associated with this line.
  String? commentText;
  for (var comment in allComments(node.root.beginToken)) {
    final commentLine = sourceFile.getLine(comment.end);
    if (commentLine == line ||
        commentLine == line + 1 ||
        commentLine == line - 1) {
      commentText = sourceFile.getText(comment.offset, comment.end);
      break;
    }
  }

  return commentText?.contains(comment) ?? false;
}

/// Whether the [node] has a documentation comment that has
/// any lines that match lines found within the provided [comment].
bool hasMultilineDocComment(
    AnnotatedNode node, SourceFile sourceFile, String comment) {
  final nodeComments = nodeCommentSpan(node, sourceFile)
      .text
      .replaceAll('///', '')
      .split('\n')
      .map((line) => line.replaceAll('\n', '').trim())
      .toList()
        ..removeWhere((line) => line.isEmpty);
  final commentLines = comment
      .replaceAll('///', '')
      .trimLeft()
      .split('\n')
      .map((line) => line.replaceAll('\n', '').trim())
      .toList()
        ..removeWhere((line) => line.isEmpty);

  bool match = false;

  for (var i = 0; i < commentLines.length; i++) {
    final potentialMatch = commentLines[i];
    if (nodeComments.any((line) => line == potentialMatch)) {
      match = true;
      break;
    }
  }

  return match;
}

/// Returns the `SourceSpan` value of any comments on the provided [node] within the [sourceFile].
SourceSpan nodeCommentSpan(AnnotatedNode node, SourceFile sourceFile) {
  return sourceFile.span(
      node.beginToken.offset,
      node.metadata.beginToken?.offset ??
          node.firstTokenAfterCommentAndMetadata.offset);
}

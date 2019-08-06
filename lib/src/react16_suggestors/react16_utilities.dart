import 'package:analyzer/analyzer.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:source_span/source_span.dart';

import 'constants.dart';

/// Returns whether or not the source file contains the React 16 validation
/// required comment.
///
/// Can be used to determine whether or not the file has been modified
/// already. This is useful (in combination with [allComments] because the
/// visitor used for visiting comments does not work as expected, making it
/// difficult to iterate over comments.
bool hasValidationComment(AstNode node, SourceFile sourceFile) {
  final line = sourceFile.getLine(node.offset);

  // Find the comment associated with this line.
  String commentText;
  for (var comment in allComments(node.root.beginToken)) {
    final commentLine = sourceFile.getLine(comment.end);
    if (commentLine == line ||
        commentLine == line + 1 ||
        commentLine == line - 1) {
      commentText = sourceFile.getText(comment.offset, comment.end);
      break;
    }
  }

  return commentText?.contains(manualValidationCommentSubstring) ?? false;
}

/// Returns an iterable of all the comments from [beginToken] to the end of the
/// file.
///
/// Comments are part of the normal stream, and need to be accessed via
/// [Token.precedingComments], so it's difficult to iterate over them without
/// this method.
Iterable allComments(Token beginToken) sync* {
  var currentToken = beginToken;
  while (!currentToken.isEof) {
    var currentComment = currentToken.precedingComments;
    while (currentComment != null) {
      yield currentComment;
      currentComment = currentComment.next;
    }
    currentToken = currentToken.next;
  }
}

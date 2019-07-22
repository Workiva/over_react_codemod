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
import 'package:analyzer/dart/ast/token.dart';
import 'package:codemod/codemod.dart';
import 'package:over_react_codemod/src/react16_suggestors/constants.dart';
import 'package:source_span/source_span.dart';

/// Suggestor that migrates `react_dom.render` usages to be compatible with
/// React 16 and inserts comments in situations where validation is required.
class ReactStyleMapsUpdater extends GeneralizingAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {

  @override
  visitCascadeExpression(CascadeExpression node) {
    super.visitCascadeExpression(node);

    if (!hasValidationComment(node, sourceFile)) {
      for (Expression cascade in node.cascadeSections) {
        if (cascade.childEntities.first.toString().contains('style')) {

          dynamic styleMap = getStyles(cascade);
          Map newStyleMap = {};
          List<String> affectedValues = [];
          String cleanStyleMapString = '{\n';
          bool containsAVariable = false;
          bool isAVariable = false;

          if (styleMap is MapLiteral) {
            styleMap.entries.forEach((node) {
              String cleanedCssPropertyKey = cleanString(node.beginToken);
              String originalCssPropertyKey = node.beginToken.toString();
              String cleanedCssPropertyValue = '';

              List endToken = node.childEntities.toList();
              endToken.removeRange(0, 2);

              String originalCssKeyValue = endToken.join(" ");

              bool isAnExpression = nodeIsLikelyAnExpression(originalCssKeyValue);
              bool wasModified = false;

              if (isAnExpression) {

                originalCssKeyValue.split(' ').forEach((String property) {
                  String cleanPropertyValue = cleanString(property);

                  if (num.tryParse(cleanPropertyValue) != null) {
                    cleanedCssPropertyValue += '$cleanPropertyValue ';
                    wasModified = true;
                  } else {
                    cleanedCssPropertyValue += '$property ';
                  }

                  cleanedCssPropertyValue = cleanedCssPropertyValue.trim();
                });

                if (wasModified) {

                  newStyleMap.addAll({originalCssPropertyKey: cleanedCssPropertyValue});
                  affectedValues.add(cleanedCssPropertyKey);
                }
              } else if (nodeIsLikelyAVariable(originalCssKeyValue)) {

                containsAVariable = true;
                affectedValues.add(cleanedCssPropertyKey);
              }

              if (!isAnExpression) {
                newStyleMap.addAll({originalCssPropertyKey: originalCssKeyValue});
              }
            });
          } else if (styleMap is SimpleIdentifier) {
            isAVariable = true;
          } else {
            throw TypeError();
          }

          if (newStyleMap == null) return;

          if (isAVariable) {
            yieldPatch(cascade.beginToken.previous.end, cascade.offset, '''
            
              // [ ] Check this box upon manual validation that the style map is receiving a value that is a num for ${affectedValues.isNotEmpty
                ? 'for the following keys: ${affectedValues.join(', ')}.'
                : 'the keys that are simple string variables. For example, \'width\': '
                '\'40\'.'}$willBeRemovedCommentSuffix
            ''');
          }

          newStyleMap.forEach((key, value) {

            if ((value.toString()).contains("\'") || (value.toString()).contains("\"")) {
              String cleanValue = cleanString(value);

              if (num.tryParse(cleanValue) != null) {
                cleanStyleMapString += '${key.toString().replaceAll('"', "'")}: $cleanValue,\n';
                affectedValues.add(cleanString(key));
              } else {
                cleanStyleMapString += '$key: $value,\n';
              }
            } else {
              cleanStyleMapString += '$key: $value,\n';
            }
          });

          cleanStyleMapString += '}\n';

          if (containsAVariable) {
            yieldPatch(cascade.beginToken.previous.end, cascade.end, '''
            
              // [ ] Check this box upon manual validation that the style map is receiving a value that is a num ${affectedValues.isNotEmpty
                ? 'for the following keys: ${affectedValues.join(', ')}.'
                : 'for the keys that are simple string variables. For example, \'width\': \'40\'.'}$willBeRemovedCommentSuffix
              ..style = ${cleanStyleMapString}
            ''');
          } else {
            if (affectedValues.isNotEmpty) {
              yieldPatch(cascade.offset, cascade.end, '''
                // [ ] Check this box upon manual validation that this style map uses a valid num ${affectedValues.isNotEmpty
                      ? 'for the following keys: ${affectedValues.join(', ')}.'
                      : 'for the keys that are numbers.'}$willBeRemovedCommentSuffix
                ..style = ${cleanStyleMapString}
              ''');
            }
          }
          break;
        }
      }
    }
  }
}

String cleanString(dynamic elementToClean) {
  return elementToClean.toString().replaceAll("\'","").replaceAll("\"","");
}

bool nodeIsLikelyAnExpression(String node) {
  bool containsTernaryNotation = node.contains('?') && node.contains(':');
  bool containsNullNotation = node.contains('??');

  if (containsNullNotation || containsTernaryNotation) return true;

  return false;
}

bool nodeIsLikelyAVariable(String node) {
  bool isAString = node.contains('"') || node.contains('\'');
  bool isANumber = num.tryParse(node) != null;

  if (!isAString && !isANumber) return true;

  return false;
}

dynamic getStyles(Expression cascade) {
  List styleCascadeEntities = cascade.childEntities.toList();
  List cleanedChildEntities = List.from(styleCascadeEntities);

  cleanedChildEntities.removeRange(0, 2);

  return cleanedChildEntities.first;
}

bool hasValidationComment(AstNode node, SourceFile sourceFile) {
  final line = sourceFile.getLine(node.offset);

  // Find the comment associated with this line; doesn't work with visitor for some reason.
  String commentText;
  for (var comment in allComments(node.root.beginToken)) {
    final commentLine = sourceFile.getLine(comment.end);

    if (commentLine == line || commentLine == line + 1 || commentLine == line + 2) {
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
  };
}

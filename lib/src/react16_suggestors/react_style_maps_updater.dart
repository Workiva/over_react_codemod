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
          bool isAFunction = false;
          bool isInline = sourceFile.getLine(cascade.offset) ==
              sourceFile.getLine(cascade.parent.offset);

          if (styleMap is MapLiteral) {
            styleMap.entries.forEach((node) {
              String cleanedCssPropertyKey = cleanString(node.beginToken);
              String originalCssPropertyKey = node.beginToken.toString();
              String cleanedCssPropertyValue = '';

              List endToken = node.childEntities.toList();
              endToken.removeRange(0, 2);

              String originalCssKeyValue = endToken.join(" ");

              bool isAnExpression = nodeIsLikelyAnExpression(
                  originalCssKeyValue);
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

                newStyleMap.addAll(
                    {originalCssPropertyKey: cleanedCssPropertyValue});

                if (wasModified) {
                  affectedValues.add(cleanedCssPropertyKey);
                }
              }

              if (nodeIsLikelyAVariable(originalCssKeyValue)) {
                containsAVariable = true;
                affectedValues.add(cleanedCssPropertyKey);
              }

              if (!isAnExpression) {
                newStyleMap.addAll(
                    {originalCssPropertyKey: originalCssKeyValue});
              }
            });
          } else if (styleMap is SimpleIdentifier) {
            isAVariable = true;
          } else if (styleMap is MethodInvocation) {
            isAFunction = true;
          }

          if (newStyleMap == null) return;

          if (isAVariable || isAFunction) {
            yieldPatch(cascade.beginToken.previous.end, cascade.offset,
                getString(isAVariable: isAVariable, isAFunction: isAFunction,
                    affectedValues: affectedValues));
          }

          newStyleMap.forEach((key, value) {
            if ((value.toString()).contains("\'") ||
                (value.toString()).contains("\"")) {
              String cleanValue = cleanString(value);

              if (num.tryParse(cleanValue) != null) {
                cleanStyleMapString +=
                '${key.toString().replaceAll('"', "'")}: $cleanValue,\n';
                affectedValues.add(cleanString(key));
              } else {
                cleanStyleMapString += '$key: $value,\n';
              }
            } else {
              cleanStyleMapString += '$key: $value,\n';
            }
          });

          cleanStyleMapString += '}';
          cleanStyleMapString.trim();

          if (affectedValues.isNotEmpty) {
            yieldPatch(cascade.offset, cascade.end,
                getString(styleMap: cleanStyleMapString,
                    affectedValues: affectedValues,
                    addExtraLine: isInline,
                    containsAVariable: containsAVariable));
          }
        }
      }
    }
  }
}

String getString({String styleMap, List affectedValues = const [], bool
isAVariable = false, bool containsAVariable = false, bool isAFunction =
false, bool addExtraLine = false}) {
  String checkboxWithAffectedValues = '// [ ] Check this box upon manual '
      'validation that this style map uses a valid num for the following keys: ${affectedValues.join(', ')}.';

  String variableCheckbox = '// [ ] Check this box upon manual validation '
      'that the style map is receiving a value that is a num for the keys '
      'that are simple string variables. For example, \'width\': \'40\'.';

  String variableCheckboxWithAffectedValues = '// [ ] Check this box upon '
      'manual validation that the style map is receiving a value that is a '
      'num for the following keys: ${affectedValues.join(', ')}.';

  String willBeRemovedSuffix = '//$willBeRemovedCommentSuffix';

  String functionCheckbox =
  '''// [ ] Check this box upon manual validation that the method called to set the style prop returns nums instead of simple string literals without units. 
 
  // Incorrect: 'width': '40'
  // Correct: 'width': 40 or 'width': '40px' or 'width': '4em'
  ''';

  if (!isAVariable && !isAFunction && !containsAVariable && !addExtraLine) {
    return '''
    $checkboxWithAffectedValues
    $willBeRemovedSuffix
    ..style = $styleMap
    ''';
  } else if (!isAVariable && !isAFunction && !containsAVariable && addExtraLine) {
    return '''
    
    $checkboxWithAffectedValues
    $willBeRemovedSuffix
    ..style = $styleMap
    ''';
  } else if ((isAVariable || containsAVariable)) {
    if (affectedValues.isNotEmpty) {
      if (styleMap != null) {
        return '''
        $variableCheckboxWithAffectedValues
        $willBeRemovedSuffix
        ..style = $styleMap
        ''';
      } else {
        return '''
      
        $variableCheckboxWithAffectedValues
        $willBeRemovedSuffix
        ''';
      }
    } else {
      if (styleMap != null) {
        return '''
        
        $variableCheckbox
        $willBeRemovedSuffix
        ..style = $styleMap
        ''';
      } else {
        return '''
      
        $variableCheckbox
        $willBeRemovedSuffix
        ''';
      }
    }
  } else if (isAFunction) {
      return '''
       
       $functionCheckbox
       $willBeRemovedSuffix
       ''';
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

    if (commentLine == line || commentLine == line + 1 || commentLine == line
        + 2 || commentLine == line + 3) {
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

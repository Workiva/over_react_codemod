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

    for (Expression cascade in node.cascadeSections) {
      if (!hasValidationComment(node, sourceFile)) {
        if (cascade.toString().contains('style') && !cascade.toString().contains('setProperty')) {
          dynamic stylesObject = getStyles(cascade);

          List<String> affectedValues = [];
          bool styleMapContainsAVariable = false;
          bool isAVariable = false;
          bool isAFunction = false;

          if (stylesObject is MapLiteral) {
            stylesObject.entries.forEach((MapLiteralEntry node) {
              String originalCssPropertyKey = node.beginToken.toString();
              String cleanedCssPropertyKey = cleanString(originalCssPropertyKey);

              List endToken = node.childEntities.toList();
              endToken.removeRange(0, 2);
              String originalCssPropertyValue = endToken.join(" ");
              String cleanedCssPropertyValue = cleanString(originalCssPropertyValue);

              bool nodeContainsAVariable = nodeIsLikelyAVariable(originalCssPropertyValue);

              if (nodeContainsAVariable) {
                affectedValues.add(cleanedCssPropertyKey);

                if (!styleMapContainsAVariable) {
                  styleMapContainsAVariable = true;
                }
              }

              if (nodeIsLikelyAnExpression(originalCssPropertyValue)) {
                bool wasModified = false;
                cleanedCssPropertyValue  = '';

                originalCssPropertyValue.split(' ').forEach((String property) {
                  String cleanedPropertySubString = cleanString(property);

                  if (isANumber(cleanedPropertySubString)) {
                    cleanedCssPropertyValue += '$cleanedPropertySubString ';
                    wasModified = true;
                  } else {
                    cleanedCssPropertyValue += '$property ';
                  }

                  cleanedCssPropertyValue = cleanedCssPropertyValue.trim();
                });

                if (wasModified) {
                  affectedValues.add(cleanedCssPropertyKey);
                  cleanedCssPropertyValue += ',';
                  yieldPatch(node.offset, node.end + 1, '$originalCssPropertyKey:'
                      ' $cleanedCssPropertyValue');
                }
              } else {
                if (isAString(originalCssPropertyValue)) {
                  if (isANumber(cleanedCssPropertyValue)) {
                    num end = node.end;
                    cleanedCssPropertyValue += ',';

                    if (end + 1 != cascade.end) {
                      end += 1;
                    }

                    yieldPatch(node.offset, end, '$originalCssPropertyKey:'
                        ' $cleanedCssPropertyValue');

                    if (!affectedValues.contains(cleanedCssPropertyKey)) {
                      affectedValues.add(cleanedCssPropertyKey);
                    }
                  }
                }
              }
            });
          } else if (stylesObject is SimpleIdentifier) {
            isAVariable = true;
          } else if (stylesObject is MethodInvocation) {
            isAFunction = true;
          }

          if (affectedValues.isNotEmpty || isAVariable || isAFunction) {
            yieldPatch(cascade.offset, cascade.offset,
            getString(isAVariable: isAVariable,
                styleMapContainsAVariable: styleMapContainsAVariable,
                isAFunction:
                isAFunction,
                affectedValues: affectedValues, addExtraLine: sourceFile.getLine(cascade.offset) == sourceFile.getLine(cascade.parent.offset)));
          }
        }
      }
    }
  }
}

String getString({String styleMap, List affectedValues = const [], bool
isAVariable = false, bool styleMapContainsAVariable = false, bool isAFunction =
false, bool addExtraLine = false}) {
  String checkboxWithAffectedValues = '// [ ] Check this box upon manual '
      'validation that this style map uses a valid value for the following '
      'keys: ${affectedValues.join(', ')}.';

  String variableCheckbox = '// [ ] Check this box upon manual validation '
      'that this style map is receiving a value that is valid for the keys '
      'that are simple string variables.';

  String variableCheckboxWithAffectedValues = '// [ ] Check this box upon '
      'manual validation that this style map is receiving a value that is '
      'valid for the following keys: ${affectedValues.join(', ')}.';

  String willBeRemovedSuffix = '//$willBeRemovedCommentSuffix';

  String functionCheckbox = '// [ ] Check this box upon manual validation '
      'that the method called to set the style prop does not return any '
      'simple, unitless strings instead of nums.';

  if ((isAVariable || styleMapContainsAVariable)) {
    if (affectedValues.isNotEmpty) {
      return '''
      $variableCheckboxWithAffectedValues
      $styleMapExample
      $willBeRemovedSuffix
      ''';
    } else {
      return '''
      $variableCheckbox
      $styleMapExample
      $willBeRemovedSuffix
      ''';
    }
  } else if (isAFunction) {
      return '''
       $functionCheckbox
       $styleMapExample
       $willBeRemovedSuffix
       ''';
  } else {
    if (addExtraLine) {
      return '''
    
      $checkboxWithAffectedValues
      $styleMapExample
      $willBeRemovedSuffix
      ''';
    } else {
      return '''
      $checkboxWithAffectedValues
      $styleMapExample
      $willBeRemovedSuffix
      ''';
    }
  }
}

String cleanString(dynamic elementToClean) {
  return elementToClean.toString().replaceAll("\'","").replaceAll("\"","");
}

bool nodeIsLikelyAnExpression(String node) =>
    node.contains('?') && node.contains(':') || node.contains('??');

bool isANumber(String node) => num.tryParse(node) != null;

bool isAString(String node) => node.contains('"') || node.contains('\'');

bool nodeIsLikelyAVariable(String node) => !isAString(node) && !isANumber(node);

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

    if (commentLine == line || commentLine == line + 1) {
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

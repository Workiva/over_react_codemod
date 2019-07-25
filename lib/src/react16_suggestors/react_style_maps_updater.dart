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

/// Suggestor that updates to React 16's StyleMap standard.
///
/// Specifically, this suggestor looks for instances where a simple unitless
/// string literal is passed to a CSS property without a unit. React 16
/// specifies that such cases should be a num instead of a string.
class ReactStyleMapsUpdater extends GeneralizingAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  @override
  visitCascadeExpression(CascadeExpression node) {
    super.visitCascadeExpression(node);

    for (Expression cascade in node.cascadeSections) {
      if (!hasValidationComment(node, sourceFile)) {
        if (cascade.toString().contains('style') &&
            !cascade.toString().contains('setProperty')) {
          /// A style map, method invocation, or a variable
          dynamic stylesObject = getStyles(cascade);

          /// CSS properties that were modified by the script or need to be
          /// manually checked
          List<String> affectedValues = [];

          // Variables that affect the writing of the comment that goes above
          // the style prop. There are different messages patched based on
          // these booleans.
          bool styleMapContainsAVariable = false;
          bool isAVariable = false;
          bool isAFunction = false;
          bool isForCustomProps =
              cascade.toString().toLowerCase().contains('props');

          if (stylesObject is MapLiteral) {
            stylesObject.entries.forEach((MapLiteralEntry cssPropertyRow) {
              String originalCssPropertyKey =
                  cssPropertyRow.beginToken.toString();
              String cleanedCssPropertyKey =
                  cleanString(originalCssPropertyKey);

              // We cannot simply do `cssPropertyRow.endToken` because if the
              // "end token" is an expression, it only returns the last
              // value in the ternary. Removing the beginning token keeps the
              // ternary intact.
              List endToken = cssPropertyRow.childEntities.toList();
              endToken.removeRange(0, 2);
              String originalCssPropertyValue = endToken.join(" ");
              String cleanedCssPropertyValue =
                  cleanString(originalCssPropertyValue);

              bool rowContainsAVariable =
                  nodeIsLikelyAVariable(originalCssPropertyValue);

              num end = cssPropertyRow.end;

              // If the codemod does not override the commas originally in
              // the code, the formatting can be undesirable. As a result,
              // the codemod manually places a comma after a modified
              // property. To do this, the script needs to override the
              // already existing comma (one character after the row end)
              // without overriding the closing bracket (cascade.end).
              if (end + 1 != cascade.end) {
                end += 1;
              }

              if (rowContainsAVariable) {
                affectedValues.add(cleanedCssPropertyKey);

                if (!styleMapContainsAVariable) {
                  styleMapContainsAVariable = true;
                }
              }

              if (nodeIsLikelyAnExpression(originalCssPropertyValue)) {
                bool wasModified = false;
                cleanedCssPropertyValue = '';

                // Loop through each part of the ternary, keeping track if
                // any of the values are strings that should be nums.
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
                  yieldPatch(
                      cssPropertyRow.offset,
                      end,
                      '$originalCssPropertyKey:'
                      ' $cleanedCssPropertyValue');
                }
              } else {
                if (isAString(originalCssPropertyValue)) {
                  if (isANumber(cleanedCssPropertyValue)) {
                    cleanedCssPropertyValue += ',';

                    yieldPatch(
                        cssPropertyRow.offset,
                        end,
                        '$originalCssPropertyKey:'
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

          // Patch the comment at the top of the style map based upon the
          // edits made.
          if (affectedValues.isNotEmpty ||
              isAVariable ||
              isAFunction ||
              isForCustomProps) {
            yieldPatch(
                cascade.offset,
                cascade.offset,
                getString(
                    isAVariable: isAVariable,
                    styleMapContainsAVariable: styleMapContainsAVariable,
                    isAFunction: isAFunction,
                    affectedValues: affectedValues,
                    addExtraLine: sourceFile.getLine(cascade.offset) ==
                        sourceFile.getLine(cascade.parent.offset),
                    isForCustomProps: isForCustomProps));
          }
        }
      }
    }
  }
}

String getString({
  String styleMap,
  List affectedValues = const [],
  bool isAVariable = false,
  bool styleMapContainsAVariable = false,
  bool isAFunction = false,
  bool addExtraLine = false,
  bool isForCustomProps = false,
}) {
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

  if (isForCustomProps) {
    return '''
    $variableCheckbox
    $styleMapExample
    $willBeRemovedSuffix
    ''';
  } else if ((isAVariable || styleMapContainsAVariable)) {
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
  return elementToClean.toString().replaceAll("\'", "").replaceAll("\"", "");
}

bool nodeIsLikelyAnExpression(String node) =>
    node.contains('?') && node.contains(':') || node.contains('??');

bool isANumber(String node) => num.tryParse(node) != null;

bool isAString(String node) => node.contains('"') || node.contains('\'');

bool nodeIsLikelyAVariable(String node) => !isAString(node) && !isANumber(node);

/// Removes the '...style' and '=' entities and returns the third entity.
///
/// The third entity will be the style map, a method invocation, or a variable.
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
  }
  ;
}

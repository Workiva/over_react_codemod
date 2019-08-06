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

import './react16_utilities.dart';

/// Suggestor that updates to React 16's StyleMap standard.
///
/// Specifically, this suggestor looks for instances where a simple unitless
/// string literal is passed to a CSS property. React 16 specifies that such
/// cases should be a num instead of a string.
class ReactStyleMapsUpdater extends GeneralizingAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  @override
  visitCascadeExpression(CascadeExpression node) {
    super.visitCascadeExpression(node);

    for (Expression cascade in node.cascadeSections) {
      if (!hasValidationComment(node, sourceFile)) {
        if (cascade.toSource().contains('style') &&
            !cascade.toSource().contains('setProperty')) {
          /// A style map, method invocation, or a variable
          dynamic stylesObject = getStyles(cascade);

          /// CSS properties that were modified by the script or need to be
          /// manually checked
          List<String> listOfVariables = [];

          // Variables that affect the writing of the comment that goes above
          // the style prop. There are different messages patched based on
          // these booleans.
          bool styleMapContainsAVariable = false;
          bool isAVariable = false;
          bool isAFunction = false;
          bool isOther = false;
          bool isForCustomProps =
              cascade.toSource().toLowerCase().contains('props');

          if (stylesObject is MapLiteral) {
            stylesObject.entries.forEach((MapLiteralEntry cssPropertyRow) {
              final propertyKey = cssPropertyRow.key;
              String originalCssPropertyKey = propertyKey.toSource();
              String cleanedCssPropertyKey = cleanString(propertyKey);

              final cssPropertyValue = cssPropertyRow.value;
              String cleanedCssPropertyValue = cleanString(cssPropertyValue);

              /// Marks the current CSS property as containing a variable.
              ///
              /// Used to keep track of what properties in the style map
              /// contain variables.
              void flagAsVariable() {
                if (!listOfVariables.contains(cleanedCssPropertyKey)) {
                  listOfVariables.add(cleanedCssPropertyKey);
                }

                if (!styleMapContainsAVariable) {
                  styleMapContainsAVariable = true;
                }
              }

              num end = cssPropertyRow.end;

              // If the codemod does not override the commas originally in
              // the code, the formatting can be undesirable. As a result,
              // the codemod manually places a comma after a modified
              // property. To do this, the script needs to override the
              // already existing comma (one character after the row end)
              // without overriding the closing bracket (cascade.end).
              final nextToken = cssPropertyRow.endToken.next;
              if (nextToken.type == TokenType.COMMA) {
                end = nextToken.end;
              }

              if (cssPropertyValue is ConditionalExpression ||
                  cssPropertyValue is BinaryExpression) {
                dynamic ternaryExpressions;

                if (cssPropertyValue is ConditionalExpression) {
                  ternaryExpressions = [
                    cssPropertyValue.thenExpression,
                    cssPropertyValue.elseExpression
                  ];
                } else if (cssPropertyValue is BinaryExpression) {
                  ternaryExpressions = [
                    cssPropertyValue.leftOperand,
                    cssPropertyValue.rightOperand
                  ];
                }

                ternaryExpressions.forEach((Expression property) {
                  String cleanedPropertySubString = cleanString(property);

                  if (property is SimpleIdentifier) flagAsVariable();

                  if (isANumber(cleanedPropertySubString)) {
                    yieldPatch(property.offset, property.end,
                        cleanedPropertySubString);
                  }
                });
              } else if (cssPropertyValue is SimpleStringLiteral ||
                  cssPropertyValue is SimpleIdentifier ||
                  cssPropertyValue is IntegerLiteral) {
                if (cssPropertyValue is SimpleIdentifier) flagAsVariable();

                if (isAString(cssPropertyValue)) {
                  if (isANumber(cleanedCssPropertyValue)) {
                    yieldPatch(
                        cssPropertyRow.offset,
                        end,
                        '$originalCssPropertyKey:'
                        ' $cleanedCssPropertyValue,');
                  }
                }
              } else {
                isOther = true;
              }
            });
          } else if (stylesObject is SimpleIdentifier) {
            isAVariable = true;
          } else if (stylesObject is MethodInvocation) {
            isAFunction = true;
          } else {
            isOther = true;
          }

          // Patch the comment at the top of the style map based upon the
          // edits made.
          if (listOfVariables.isNotEmpty ||
              isAVariable ||
              isAFunction ||
              isForCustomProps ||
              isOther) {
            yieldPatch(
                cascade.offset,
                cascade.offset,
                getString(
                    isAVariable: isAVariable,
                    styleMapContainsAVariable: styleMapContainsAVariable,
                    isAFunction: isAFunction,
                    affectedValues: listOfVariables,
                    addExtraLine: sourceFile.getLine(cascade.offset) ==
                        sourceFile.getLine(cascade.parent.offset),
                    isForCustomProps: isForCustomProps,
                    isOther: isOther));
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
  bool isOther = false,
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
  } else if (isAVariable || styleMapContainsAVariable || isOther) {
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
  if (elementToClean is SimpleStringLiteral) return elementToClean.value;

  if (elementToClean is String) return elementToClean;

  return elementToClean.toSource();
}

bool isANumber(String node) => num.tryParse(node) != null;

bool isAString(AstNode node) => node is SimpleStringLiteral;

/// Removes the '...style' and '=' entities and returns the third entity.
///
/// The third entity will be the style map, a method invocation, or a variable.
dynamic getStyles(Expression cascade) {
  List styleCascadeEntities = cascade.childEntities.toList();
  List cleanedChildEntities = List.from(styleCascadeEntities);

  cleanedChildEntities.removeRange(0, 2);

  return cleanedChildEntities.first;
}

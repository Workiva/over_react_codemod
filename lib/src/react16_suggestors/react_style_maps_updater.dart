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
import 'package:analyzer/dart/ast/syntactic_entity.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
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
  static final _cssValueSuffixPattern =
      new RegExp(r'\b(?:rem|em|ex|vh|vw|vmin|vmax|%|px|cm|mm|in|pt|pc|ch)$');

  @override
  visitCascadeExpression(CascadeExpression node) {
    super.visitCascadeExpression(node);

    // UiProps instances can't be created via constructors, so we want to skip
    // these to avoid false positives on classes with a style prop.
    //
    // Make sure to only skip if a `new`/`const` keyword is present, since
    // component factory invocations can be parsed by Dart 2 as
    // InstanceCreationExpression even though they're MethodInvocations in
    // the resolved AST.
    {
      final target = node.target;
      if (target is InstanceCreationExpression && target.keyword != null) {
        return;
      }
    }

    for (Expression cascade in node.cascadeSections) {
      if (hasComment(cascade, sourceFile, willBeRemovedCommentSuffix)) {
        continue;
      }

      var isStylePropAssignment = false;
      if (cascade is AssignmentExpression) {
        final lhs = cascade.leftHandSide;
        if (lhs is PropertyAccess && lhs.propertyName.name == 'style') {
          isStylePropAssignment = true;
        }
      }
      if (!isStylePropAssignment) continue;

      /// A style map, method invocation, or a variable
      final stylesObject = getStyles(cascade);

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

      if (stylesObject is SetOrMapLiteral) {
        stylesObject.elements
            .whereType<MapLiteralEntry>()
            .forEach((cssPropertyRow) {
          final propertyKey = cssPropertyRow.key;
          String originalCssPropertyKey = propertyKey.toSource();
          String cleanedCssPropertyKey = cleanString(propertyKey);

          if (_unitlessNumberProperties.contains(cleanedCssPropertyKey) ||
              _nonLengthValueProperties.contains(cleanedCssPropertyKey)) {
            return;
          }

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

            styleMapContainsAVariable = true;
          }

          var end = cssPropertyRow.end;

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
            List<Expression> ternaryExpressions;

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

            ternaryExpressions.forEach((property) {
              String cleanedPropertySubString = cleanString(property);

              if (property is SimpleIdentifier) {
                flagAsVariable();
              } else if (isANumber(cleanedPropertySubString) &&
                  !isANumber(property.toSource())) {
                yieldPatch(
                    property.offset, property.end, cleanedPropertySubString);
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
          } else if (cssPropertyValue is StringInterpolation) {
            final lastElement = cssPropertyValue.elements.isEmpty
                ? null
                : cssPropertyValue.elements.last;
            if (lastElement is! InterpolationString ||
                !_cssValueSuffixPattern
                    .hasMatch((lastElement as InterpolationString).value)) {
              flagAsVariable();
            }
          } else if (cssPropertyValue is MethodInvocation) {
            var invocation = cssPropertyValue;
            // Handle `toRem(1).toString()`
            if (invocation.methodName.name == 'toString' &&
                invocation.target is MethodInvocation) {
              invocation = invocation.target;
            }

            if (!const ['toPx', 'toRem'].contains(invocation.methodName.name)) {
              flagAsVariable();
            }
          } else if (cssPropertyValue is DoubleLiteral ||
              cssPropertyValue is IntegerLiteral) {
            // do nothing
          } else {
            flagAsVariable();
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
      if (listOfVariables.isNotEmpty || isAVariable || isAFunction || isOther) {
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
                isOther: isOther));
      }
    }
  }
}

String getString({
  String styleMap,
  List<String> affectedValues = const [],
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

  if (isAVariable || styleMapContainsAVariable || isOther) {
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
SyntacticEntity getStyles(Expression cascade) {
  List<SyntacticEntity> styleCascadeEntities = cascade.childEntities.toList();
  final cleanedChildEntities = List<SyntacticEntity>.from(styleCascadeEntities);

  cleanedChildEntities.removeRange(0, 2);

  return cleanedChildEntities.first;
}

/// A non-exhaustive set of CSS property names whose values can be numbers
/// without units.
const _unitlessNumberProperties = const {
  'animationIterationCount',
  'borderImageOutset',
  'borderImageSlice',
  'borderImageWidth',
  'boxFlex',
  'boxFlexGroup',
  'boxOrdinalGroup',
  'columnCount',
  'columns',
  'flex',
  'flexGrow',
  'flexPositive',
  'flexShrink',
  'flexNegative',
  'flexOrder',
  'gridRow',
  'gridRowEnd',
  'gridRowSpan',
  'gridRowStart',
  'gridColumn',
  'gridColumnEnd',
  'gridColumnSpan',
  'gridColumnStart',
  'fontWeight',
  'lineClamp',
  'lineHeight',
  'opacity',
  'order',
  'orphans',
  'tabSize',
  'widows',
  'zIndex',
  'zoom',

  // SVG-related properties
  'fillOpacity',
  'floodOpacity',
  'stopOpacity',
  'strokeDasharray',
  'strokeDashoffset',
  'strokeMiterlimit',
  'strokeOpacity',
  'strokeWidth',
};

/// A non-exhaustive set of CSS property names whose values never represent
/// CSS lengths (absolute lengths like px/pt, relative lengths like %/rem).
const _nonLengthValueProperties = const {
  'backgroundAttachment',
  'backgroundColor',
  'backgroundImage',
  'borderBottomColor',
  'borderBottomStyle',
  'borderColor',
  'borderLeftColor',
  'borderLeftStyle',
  'borderRightColor',
  'borderRightStyle',
  'borderStyle',
  'borderTopColor',
  'borderTopStyle',
  'clear',
  'color',
  'cursor',
  'display',
  'float',
  'cssFloat',
  'font',
  'fontFamily',
  'fontVariant',
  'listStyle',
  'listStyleImage',
  'listStyleType',
  'overflow',
  'pageBreakAfter',
  'pageBreakBefore',
  'position',
  'textAlign',
  'textDecoration',
  'textTransform',
  'verticalAlign',
  'visibility',
};

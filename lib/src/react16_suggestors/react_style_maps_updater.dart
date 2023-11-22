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
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:codemod/codemod.dart';
import 'package:over_react_codemod/src/react16_suggestors/constants.dart';
import 'package:over_react_codemod/src/react16_suggestors/react16_utilities.dart';

/// Suggestor that updates to React 16's StyleMap standard.
///
/// Specifically, this suggestor looks for instances where a simple unitless
/// string literal is passed to a CSS property. React 16 specifies that such
/// cases should be a num instead of a string.
class ReactStyleMapsUpdater extends GeneralizingAstVisitor
    with AstVisitingSuggestor {
  static final _cssValueSuffixPattern =
      RegExp(r'\b(?:rem|em|ex|vh|vw|vmin|vmax|%|px|cm|mm|in|pt|pc|ch)$');

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
      if (hasComment(cascade, context.sourceFile, willBeRemovedCommentSuffix)) {
        continue;
      }

      /// A style map, method invocation, or a variable
      Expression? stylesObject;
      if (cascade is AssignmentExpression) {
        final lhs = cascade.leftHandSide;
        if (lhs is PropertyAccess && lhs.propertyName.name == 'style') {
          stylesObject = cascade.rightHandSide;
        }
      }
      if (stylesObject == null) continue;

      /// CSS properties that need to be manually checked.
      final potentiallyInvalidProperties = <String>{};

      // Variables that affect the writing of the comment that goes above
      // the style prop. There are different messages patched based on
      // these booleans.
      bool isAVariable = false;
      bool isAFunction = false;
      bool isOther = false;

      if (stylesObject is SetOrMapLiteral) {
        for (var cssPropertyRow
            in stylesObject.elements.whereType<MapLiteralEntry>()) {
          final originalCssPropertyKey = cssPropertyRow.key.toSource();
          final cleanedCssPropertyKey = cleanString(cssPropertyRow.key);

          if (_unitlessNumberProperties.contains(cleanedCssPropertyKey) ||
              _nonLengthValueProperties.contains(cleanedCssPropertyKey)) {
            continue;
          }

          final cssPropertyValue = cssPropertyRow.value;

          /// Marks the current CSS property as needing manual checking.
          void flagAsPotentiallyInvalid() {
            potentiallyInvalidProperties.add(cleanedCssPropertyKey);
          }

          var end = cssPropertyRow.end;

          // If the codemod does not override the commas originally in
          // the code, the formatting can be undesirable. As a result,
          // the codemod manually places a comma after a modified
          // property. To do this, the script needs to override the
          // already existing comma (one character after the row end)
          // without overriding the closing bracket (cascade.end).
          final nextToken = cssPropertyRow.endToken.next!;
          if (nextToken.type == TokenType.COMMA) {
            end = nextToken.end;
          }

          if (cssPropertyValue is ConditionalExpression ||
              cssPropertyValue is BinaryExpression) {
            final List<Expression> ternaryExpressions;

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
            } else {
              throw UnimplementedError('Unhandled type for cssPropertyValue');
            }

            for (var property in ternaryExpressions) {
              String cleanedPropertySubString = cleanString(property);

              if (property is SimpleIdentifier) {
                flagAsPotentiallyInvalid();
              } else if (isANumber(cleanedPropertySubString) &&
                  !isANumber(property.toSource())) {
                yieldPatch(
                    cleanedPropertySubString, property.offset, property.end);
              }
            }
          } else if (cssPropertyValue is SimpleStringLiteral ||
              cssPropertyValue is SimpleIdentifier ||
              cssPropertyValue is IntegerLiteral) {
            if (cssPropertyValue is SimpleIdentifier) {
              flagAsPotentiallyInvalid();
            }

            if (cssPropertyValue is SimpleStringLiteral) {
              if (isANumber(cssPropertyValue.value)) {
                yieldPatch(
                  '$originalCssPropertyKey:'
                  ' ${cssPropertyValue.value},',
                  cssPropertyRow.offset,
                  end,
                );
              }
            }
          } else if (cssPropertyValue is StringInterpolation) {
            final lastElement = cssPropertyValue.elements.isEmpty
                ? null
                : cssPropertyValue.elements.last;
            if (lastElement is! InterpolationString ||
                !_cssValueSuffixPattern.hasMatch(lastElement.value)) {
              flagAsPotentiallyInvalid();
            }
          } else if (cssPropertyValue is MethodInvocation) {
            var invocation = cssPropertyValue;
            // Handle `toRem(1).toString()`
            if (invocation.methodName.name == 'toString' &&
                invocation.target is MethodInvocation) {
              // ignore: cast_nullable_to_non_nullable
              invocation = invocation.target as MethodInvocation;
            }

            if (!const ['toPx', 'toRem'].contains(invocation.methodName.name)) {
              flagAsPotentiallyInvalid();
            }
          } else if (cssPropertyValue is DoubleLiteral ||
              cssPropertyValue is IntegerLiteral) {
            // do nothing
          } else {
            flagAsPotentiallyInvalid();
          }
        }
      } else if (stylesObject is SimpleIdentifier) {
        isAVariable = true;
      } else if (stylesObject is MethodInvocation) {
        isAFunction = true;
      } else {
        isOther = true;
      }

      // Patch the comment at the top of the style map based upon the
      // edits made.
      if (potentiallyInvalidProperties.isNotEmpty ||
          isAVariable ||
          isAFunction ||
          isOther) {
        yieldPatch(
          getString(
              isAVariable: isAVariable,
              hasPotentiallyInvalidValue:
                  potentiallyInvalidProperties.isNotEmpty,
              isAFunction: isAFunction,
              affectedValues: potentiallyInvalidProperties,
              addExtraLine: context.sourceFile.getLine(cascade.offset) ==
                  context.sourceFile.getLine(cascade.parent!.offset),
              isOther: isOther),
          cascade.offset,
          cascade.offset,
        );
      }
    }
  }
}

String getString({
  String? styleMap,
  Iterable<String> affectedValues = const [],
  bool isAVariable = false,
  bool hasPotentiallyInvalidValue = false,
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

  if (isAVariable || hasPotentiallyInvalidValue || isOther) {
    if (affectedValues.isNotEmpty) {
      return '''
      $variableCheckboxWithAffectedValues
      $styleMapComment
      $willBeRemovedSuffix
      ''';
    } else {
      return '''
      $variableCheckbox
      $styleMapComment
      $willBeRemovedSuffix
      ''';
    }
  } else if (isAFunction) {
    return '''
       $functionCheckbox
       $styleMapComment
       $willBeRemovedSuffix
       ''';
  } else {
    if (addExtraLine) {
      return '''

      $checkboxWithAffectedValues
      $styleMapComment
      $willBeRemovedSuffix
      ''';
    } else {
      return '''
      $checkboxWithAffectedValues
      $styleMapComment
      $willBeRemovedSuffix
      ''';
    }
  }
}

String cleanString(AstNode elementToClean) {
  if (elementToClean is SimpleStringLiteral) return elementToClean.value;

  return elementToClean.toSource();
}

bool isANumber(String node) => num.tryParse(node) != null;

/// A non-exhaustive set of CSS property names whose values can be numbers
/// without units.
const _unitlessNumberProperties = {
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
const _nonLengthValueProperties = {
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

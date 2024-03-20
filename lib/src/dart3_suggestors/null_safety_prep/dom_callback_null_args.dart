// Copyright 2024 Workiva Inc.
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

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:collection/collection.dart';
import 'package:over_react_codemod/src/util/class_suggestor.dart';

/// Suggestor that replaces a `null` literal argument passed to a "DOM" callback
/// with a generated `SyntheticEvent` object of the expected type.
///
/// Example:
///
/// ```dart
/// final props = domProps();
/// // Before
/// props.onClick(null);
/// // After
/// props.onClick(createSyntheticMouseEvent());
/// ```
class DomCallbackNullArgs extends RecursiveAstVisitor with ClassSuggestor {
  ResolvedUnitResult? _result;

  @override
  visitArgumentList(ArgumentList node) {
    super.visitArgumentList(node);

    if (node.arguments.isEmpty) return;
    dynamic firstArg = node.arguments.elementAt(0);
    if (firstArg is! NullLiteral) return;

    dynamic possibleCallback = node.parent;
    if (possibleCallback is FunctionExpressionInvocation) {
      String fnName = '';
      if (possibleCallback.function is PropertyAccess) {
        fnName =
            (possibleCallback.function as PropertyAccess).propertyName.name;
      } else if (possibleCallback.function is SimpleIdentifier) {
        fnName = (possibleCallback.function as SimpleIdentifier).name;
      }

      if (callbackToSyntheticEventTypeMap.keys.contains(fnName)) {
        dynamic possibleSyntheticEventCallbackFn =
            possibleCallback.staticInvokeType;
        if (possibleSyntheticEventCallbackFn is FunctionType) {
          final syntheticEventTypeName = possibleSyntheticEventCallbackFn
              .parameters.firstOrNull?.type.element?.name;
          yieldPatch('create${syntheticEventTypeName}()',
              firstArg.literal.offset, firstArg.literal.end);
        }
      }
    }
  }

  @override
  Future<void> generatePatches() async {
    _result = await context.getResolvedUnit();
    if (_result == null) {
      throw Exception(
          'Could not get resolved result for "${context.relativePath}"');
    }
    _result!.unit.accept(this);
  }

  static const callbackToSyntheticEventTypeMap = {
    'onAnimationEnd': 'SyntheticAnimationEvent',
    'onAnimationIteration': 'SyntheticAnimationEvent',
    'onAnimationStart': 'SyntheticAnimationEvent',
    'onCopy': 'SyntheticClipboardEvent',
    'onCut': 'SyntheticClipboardEvent',
    'onPaste': 'SyntheticClipboardEvent',
    'onKeyDown': 'SyntheticKeyboardEvent',
    'onKeyPress': 'SyntheticKeyboardEvent',
    'onKeyUp': 'SyntheticKeyboardEvent',
    'onFocus': 'SyntheticFocusEvent',
    'onBlur': 'SyntheticFocusEvent',
    'onChange': 'SyntheticFormEvent',
    'onInput': 'SyntheticFormEvent',
    'onSubmit': 'SyntheticFormEvent',
    'onReset': 'SyntheticFormEvent',
    'onClick': 'SyntheticMouseEvent',
    'onContextMenu': 'SyntheticMouseEvent',
    'onDoubleClick': 'SyntheticMouseEvent',
    'onDrag': 'SyntheticMouseEvent',
    'onDragEnd': 'SyntheticMouseEvent',
    'onDragEnter': 'SyntheticMouseEvent',
    'onDragExit': 'SyntheticMouseEvent',
    'onDragLeave': 'SyntheticMouseEvent',
    'onDragOver': 'SyntheticMouseEvent',
    'onDragStart': 'SyntheticMouseEvent',
    'onDrop': 'SyntheticMouseEvent',
    'onMouseDown': 'SyntheticMouseEvent',
    'onMouseEnter': 'SyntheticMouseEvent',
    'onMouseLeave': 'SyntheticMouseEvent',
    'onMouseMove': 'SyntheticMouseEvent',
    'onMouseOut': 'SyntheticMouseEvent',
    'onMouseOver': 'SyntheticMouseEvent',
    'onMouseUp': 'SyntheticMouseEvent',
    'onPointerCancel': 'SyntheticPointerEvent',
    'onPointerDown': 'SyntheticPointerEvent',
    'onPointerEnter': 'SyntheticPointerEvent',
    'onPointerLeave': 'SyntheticPointerEvent',
    'onPointerMove': 'SyntheticPointerEvent',
    'onPointerOver': 'SyntheticPointerEvent',
    'onPointerOut': 'SyntheticPointerEvent',
    'onPointerUp': 'SyntheticPointerEvent',
    'onTouchCancel': 'SyntheticTouchEvent',
    'onTouchEnd': 'SyntheticTouchEvent',
    'onTouchMove': 'SyntheticTouchEvent',
    'onTouchStart': 'SyntheticTouchEvent',
    'onTransitionEnd': 'SyntheticTransitionEvent',
    'onScroll': 'SyntheticUIEvent',
    'onWheel': 'SyntheticWheelEvent',
  };
}

// Adapted from the add_create_ref assist in over_react/analyzer_plugin
// Permalink: https://github.com/Workiva/over_react/blob/a8129f38ea8dfa0023d06250349fc8e86025df3a/tools/analyzer_plugin/lib/src/assist/refs/add_create_ref.dart#L4
//
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
import 'package:analyzer/dart/element/element.dart';
import 'package:collection/collection.dart';
import 'package:over_react_codemod/src/dart3_suggestors/null_safety_prep/utils/hint_detection.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../../util.dart';
import '../../util/class_suggestor.dart';
import 'analyzer_plugin_utils.dart';

/// Suggestor to add nullability hints to ref types.
///
/// (1) For ref prop param types:
/// ```
/// - (ButtonToolbar()..ref = (ButtonElement r) => ref = r)();
/// + (ButtonToolbar()..ref = (ButtonElement /*?*/ r) => ref = r)();
/// ```
///
/// (2) For ref variable declarations:
/// ```
/// - ButtonElement ref;
/// + ButtonElement /*?*/ ref;
/// (ButtonToolbar()..ref = (r) => ref = r)();
/// ```
///
/// (3) For ref prop type casts:
/// ```
/// - (ButtonToolbar()..ref = (r) => ref = r as ButtonElement)();
/// + (ButtonToolbar()..ref = (r) => ref = r as ButtonElement /*?*/)();
/// ```
///
/// These hints are needed because the null-safety migration tool does not do
/// well at inferring that ref types should be nullable.
class CallbackRefHintSuggestor extends RecursiveAstVisitor<void>
    with ClassSuggestor {
  CallbackRefHintSuggestor();

  late ResolvedUnitResult result;

  @override
  Future<void> visitCascadeExpression(CascadeExpression node) async {
    super.visitCascadeExpression(node);

    final cascadedProps = node.cascadeSections
        .whereType<AssignmentExpression>()
        .where((assignment) => assignment.leftHandSide is PropertyAccess)
        .map((assignment) => PropAssignment(assignment));

    for (final prop in cascadedProps) {
      if (prop.name.name == 'ref') {
        final rhs =
            prop.rightHandSide.unParenthesized.tryCast<FunctionExpression>();
        if (rhs == null) return null;

        // Add nullability hint to parameter if typed.
        final param = rhs.parameters?.parameters.first;
        if (param is SimpleFormalParameter) {
          final type = param.type;
          if (type != null && !nullableHintAlreadyExists(type)) {
            yieldPatch(nullableHint, type.end, type.end);
          }
        }

        final refParamName = param?.name?.toString();
        if (refParamName != null) {
          // Add nullability hint to ref variable declarations.
          final refCallbackArg = rhs.parameters?.parameters.firstOrNull;
          if (refCallbackArg != null) {
            final referencesToArg = allDescendantsOfType<Identifier>(rhs.body)
                .where((identifier) =>
                    identifier.staticElement == refCallbackArg.declaredElement);

            for (final reference in referencesToArg) {
              final parent = reference.parent;
              if (parent is AssignmentExpression &&
                  parent.rightHandSide == reference) {
                final lhs = parent.leftHandSide;
                if (lhs is Identifier) {
                  final varElement =
                      // Variable in function component.
                      lhs.staticElement?.tryCast<VariableElement>() ??
                          // Variable in class component.
                          lhs.parent
                              ?.tryCast<AssignmentExpression>()
                              ?.writeElement
                              ?.tryCast<PropertyAccessorElement>()
                              ?.variable;
                  if (varElement != null) {
                    final varType = lookUpVariable(varElement, result.unit)
                        ?.parent
                        .tryCast<VariableDeclarationList>()
                        ?.type;
                    if (varType != null &&
                        !nullableHintAlreadyExists(varType) &&
                        varType.toSource() != 'dynamic') {
                      yieldPatch(nullableHint, varType.end, varType.end);
                    }
                  }
                }
              }
            }
          }

          // Add nullability hint to any casts in the body of the callback ref.
          final refCasts = allDescendantsOfType<AsExpression>(rhs.body).where(
              (expression) =>
                  expression.expression.toSource() == refParamName &&
                  !nullableHintAlreadyExists(expression.type));
          for (final cast in refCasts) {
            yieldPatch(nullableHint, cast.type.end, cast.type.end);
          }
        }
      }
    }
  }

  @override
  Future<void> generatePatches() async {
    final r = await context.getResolvedUnit();
    if (r == null) {
      throw Exception(
          'Could not get resolved result for "${context.relativePath}"');
    }
    result = r;
    // Don't make any updates if the file is already null safe.
    if (result.libraryElement.isNonNullableByDefault) {
      return;
    }

    result.unit.visitChildren(this);
  }
}

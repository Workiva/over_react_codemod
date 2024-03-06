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

import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:codemod/codemod.dart';

/// Suggestor to add nullability hints to ref types.
class CallbackRefHintSuggestor extends RecursiveAstVisitor<void>
    with AstVisitingSuggestor {
  CallbackRefHintSuggestor();

  @override
  void visitCascadeExpression(CascadeExpression node) {
    super.visitCascadeExpression(node);

    final cascadedProps = node.cascadeSections
        .whereType<AssignmentExpression>()
        .where((assignment) => assignment.leftHandSide is PropertyAccess)
        .map((assignment) => PropAssignment(assignment));

    for (final prop in cascadedProps) {
      if (prop.name.name == 'ref') {
        final rhs = prop.rightHandSide;
        if (rhs is FunctionExpression) {
          // Add nullability hint to parameter if typed.
          final param = rhs.parameters?.parameters.first;
          if (param is SimpleFormalParameter) {
            final type = param.type;
            if (type != null && !_hintAlreadyExists(type)) {
              yieldPatch(nullabilityHint, type.end, type.end);
            }
          }

          // Add nullability hint to any casts in the body of the callback ref.
          final refParamName = param?.name?.toString();
          if(refParamName != null) {
            final castVisitor = RefCastVisitor(refParamName);
            rhs.body.visitChildren(castVisitor);
            for (final location in castVisitor.locationsNeedingHints) {
              yieldPatch(nullabilityHint, location, location);
            }
          }
        }
      }
    }
  }
}

/// Visitor to find [locationsNeedingHints] where ref types are casted within the body of a collback ref.
class RefCastVisitor extends RecursiveAstVisitor<void> {
  RefCastVisitor(this.refParamName);

  late String refParamName;

  /// A list of offsets where a [nullabilityHint] patch should be added.
  final locationsNeedingHints = <int>[];

  @override
  void visitAsExpression(AsExpression node) {
    super.visitAsExpression(node);
    final varName = node.expression.toSource();
    if(varName == refParamName && !_hintAlreadyExists(node.type)) {
      locationsNeedingHints.add(node.type.end);
    }
  }
}

/// Whether the nullability hint already exists after [type].
bool _hintAlreadyExists(TypeAnnotation type) {
  // The nullability hint will follow the type so we need to check the next token to find the comment if it exists.
  return type.endToken.next?.precedingComments?.value().contains(nullabilityHint) ?? false;
}

const nullabilityHint = '/*?*/';

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

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:codemod/codemod.dart';

import '../../util.dart';
import '../../util/class_suggestor.dart';

final _log = Logger('CallbackRefHintSuggestor');

/// Suggestor to add nullability hints to ref types.
///
/// todo doc comment examples
class CallbackRefHintSuggestor extends RecursiveAstVisitor<void>
    with ClassSuggestor {
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
            final bodyVisitor = RefBodyVisitor(refParamName);

            final function = rhs.unParenthesized.tryCast<FunctionExpression>();

            if (function == null) return null;

            final refCallbackArg = function.parameters?.parameters.firstOrNull;
            if (refCallbackArg == null) return null;

            final referencesToArg = allDescendantsOfType<Identifier>(function.body)
                .where((identifier) => identifier.staticElement == refCallbackArg.declaredElement);

            for (final reference in referencesToArg) {
              final parent = reference.parent;
              if (parent is AssignmentExpression && parent.rightHandSide == reference) {
                final lhs = parent.leftHandSide;
                if (lhs is Identifier) {
                  final varInFnComponent = lhs.staticElement?.tryCast<VariableElement>();
                  final varInClassComponent =
                      lhs.parent?.tryCast<AssignmentExpression>()?.writeElement?.tryCast<PropertyAccessorElement>()?.variable;
                  final type = varInClassComponent?.type;
                  if (varInClassComponent != null
                      // && !_hintAlreadyExists(type)
                  ) {
                    final a = 1;
                    yieldPatch(nullabilityHint, varInClassComponent.nameOffset, varInClassComponent.nameOffset);
                  }if (varInFnComponent != null
                      // && !_hintAlreadyExists(type)
                  ) {
                    final a = 1;
                    yieldPatch(nullabilityHint, varInFnComponent.nameOffset, varInFnComponent.nameOffset);
                  }
                  // return varInFnComponent ?? varInClassComponent;
                }
              }
            }

            rhs.body.visitChildren(bodyVisitor);
            for (final location in bodyVisitor.locationsNeedingHints) {
              yieldPatch(nullabilityHint, location, location);
            }
          }
        }
      }
    }
  }

  @override
  Future<void> generatePatches() async {
    _log.info('Resolving ${context.relativePath}...');

    final result = await context.getResolvedUnit();
    if (result == null) {
      throw Exception(
          'Could not get resolved result for "${context.relativePath}"');
    }
    result.unit.visitChildren(this);
  }
}

/// Visitor to find [locationsNeedingHints] where ref types are casted within the body of a collback ref.
class RefBodyVisitor extends RecursiveAstVisitor<void> with ClassSuggestor {
  RefBodyVisitor(this.refParamName);

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

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    super.visitAssignmentExpression(node);
    // todo - see if there are edge cases for this like casting
    final rhs = node.rightHandSide;
    String? varName;
    if(rhs is SimpleIdentifier) {
      varName = rhs.name;
    } if(rhs is AsExpression) {
      varName = rhs.expression.toSource();
    }
    if(varName == refParamName) {
      final lhs = node.leftHandSide;
      if(lhs is SimpleIdentifier) {

      }
    }
    // TODO: implement visitAssignmentExpression
  }

  @override
  Future<void> generatePatches() async {
    _log.info('Resolving ${context.relativePath}...');

    final result = await context.getResolvedUnit();
    if (result == null) {
      throw Exception(
          'Could not get resolved result for "${context.relativePath}"');
    }
    result.unit.visitChildren(this);
  }
}

/// Whether the nullability hint already exists after [type].
bool _hintAlreadyExists(TypeAnnotation type) {
  // The nullability hint will follow the type so we need to check the next token to find the comment if it exists.
  return type.endToken.next?.precedingComments?.value().contains(nullabilityHint) ?? false;
}

const nullabilityHint = '/*?*/';

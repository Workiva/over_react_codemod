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
          if (type != null && !_hintAlreadyExists(type)) {
            yieldPatch(nullabilityHint, type.end, type.end);
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
                  final varInFnComponent =
                      lhs.staticElement?.tryCast<VariableElement>();
                  final varInClassComponent = lhs.parent
                      ?.tryCast<AssignmentExpression>()
                      ?.writeElement
                      ?.tryCast<PropertyAccessorElement>()
                      ?.variable;
                  if (varInClassComponent != null
                      ) {
                    final decl = lookUpVariable(varInClassComponent, result.unit)?.parent.tryCast<VariableDeclarationList>()?.type;
                    if(decl != null && !_hintAlreadyExists(decl)) {
                      yieldPatch(
                          nullabilityHint,
                          decl.end,
                          decl.end);
                    }
                  } else if (varInFnComponent != null
                  ) {
                    final decl = lookUpVariable(varInFnComponent, result.unit)?.parent.tryCast<VariableDeclarationList>()?.type;
                    if(decl != null && !_hintAlreadyExists(decl)) {
                      yieldPatch(
                          nullabilityHint,
                          decl.end,
                          decl.end);
                    }
                  }
                  // return varInFnComponent ?? varInClassComponent;
                }
              }
            }
          }

          // Add nullability hint to any casts in the body of the callback ref.
          final refCasts = allDescendantsOfType<AsExpression>(rhs.body).where(
              (expression) =>
                  expression.expression.toSource() == refParamName &&
                  !_hintAlreadyExists(expression.type));
          for (final cast in refCasts) {
            yieldPatch(nullabilityHint, cast.type.end, cast.type.end);
          }
        }
      }
    }
  }

  @override
  Future<void> generatePatches() async {
    _log.info('Resolving ${context.relativePath}...');

    final r = await context.getResolvedUnit();
    if (r == null) {
      throw Exception(
          'Could not get resolved result for "${context.relativePath}"');
    }
    result = r;
    result.unit.visitChildren(this);
  }
}

/// Whether the nullability hint already exists after [type].
bool _hintAlreadyExists(TypeAnnotation type) {
  // The nullability hint will follow the type so we need to check the next token to find the comment if it exists.
  return type.endToken.next?.precedingComments
          ?.value()
          .contains(nullabilityHint) ??
      false;
}

/// Returns the AST node of the variable declaration associated with the [element] within [root],
/// or null if the [element] doesn't correspond to a variable declaration, or if it can't be found in [root].
VariableDeclaration? lookUpVariable(Element element, AstNode root) {
  final node = NodeLocator2(element.nameOffset).searchWithin(root);
  if (node is VariableDeclaration && node.declaredElement == element) {
    return node;
  }

  return null;
}

/// An object used to locate the [AstNode] associated with a source range.
/// More specifically, they will return the deepest [AstNode] which completely
/// encompasses the specified range with some exceptions:
///
/// - Offsets that fall between the name and type/formal parameter list of a
///   declaration will return the declaration node and not the parameter list
///   node.
class NodeLocator2 extends UnifyingAstVisitor<void> {
  /// The inclusive start offset of the range used to identify the node.
  final int _startOffset;

  /// The inclusive end offset of the range used to identify the node.
  final int _endOffset;

  /// The found node or `null` if there is no such node.
  AstNode? _foundNode;

  /// Initialize a newly created locator to locate the deepest [AstNode] for
  /// which `node.offset <= [startOffset]` and `[endOffset] < node.end`.
  ///
  /// If [endOffset] is not provided, then it is considered the same as the
  /// given [startOffset].
  NodeLocator2(int startOffset, [int? endOffset])
      : _startOffset = startOffset,
        _endOffset = endOffset ?? startOffset;

  /// Search within the given AST [node] and return the node that was found,
  /// or `null` if no node was found.
  AstNode? searchWithin(AstNode? node) {
    if (node == null) {
      return null;
    }
    try {
      node.accept(this);
    } catch (_) {
      return null;
    }
    return _foundNode;
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    // Names do not have AstNodes but offsets at the end should be treated as
    // part of the declaration (not parameter list).
    if (_startOffset == _endOffset &&
        _startOffset == (node.name ?? node.returnType).end) {
      _foundNode = node;
      return;
    }

    super.visitConstructorDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    // Names do not have AstNodes but offsets at the end should be treated as
    // part of the declaration (not parameter list).
    if (_startOffset == _endOffset && _startOffset == node.name.end) {
      _foundNode = node;
      return;
    }

    super.visitFunctionDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    // Names do not have AstNodes but offsets at the end should be treated as
    // part of the declaration (not parameter list).
    if (_startOffset == _endOffset && _startOffset == node.name.end) {
      _foundNode = node;
      return;
    }

    super.visitMethodDeclaration(node);
  }

  @override
  void visitNode(AstNode node) {
    // Don't visit a new tree if the result has been already found.
    if (_foundNode != null) {
      return;
    }
    // Check whether the current node covers the selection.
    var beginToken = node.beginToken;
    var endToken = node.endToken;
    // Don't include synthetic tokens.
    while (endToken != beginToken) {
      // Fasta scanner reports unterminated string literal errors
      // and generates a synthetic string token with non-zero length.
      // Because of this, check for length > 0 rather than !isSynthetic.
      if (endToken.isEof || endToken.length > 0) {
        break;
      }
      endToken = endToken.previous!;
    }
    var end = endToken.end;
    var start = node.offset;
    if (end <= _startOffset || start > _endOffset) {
      return;
    }
    // Check children.
    try {
      node.visitChildren(this);
    } catch (_) {
      // Ignore the exception and proceed in order to visit the rest of the
      // structure.
    }
    // Found a child.
    if (_foundNode != null) {
      return;
    }
    // Check this node.
    if (start <= _startOffset && _endOffset < end) {
      _foundNode = node;
    }
  }
}

const nullabilityHint = '/*?*/';

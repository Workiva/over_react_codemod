// These utilities were copied from analyzer utils in over_react/analyzer_plugin
// Permalink: https://github.com/Workiva/over_react/blob/a8129f38ea8dfa0023d06250349fc8e86025df3a/tools/analyzer_plugin/lib/src/util/analyzer_util.dart#L4
// Permalink: https://github.com/Workiva/over_react/blob/a8129f38ea8dfa0023d06250349fc8e86025df3a/tools/analyzer_plugin/lib/src/util/ast_util.dart
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

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

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

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

import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:over_react_codemod/src/dart3_suggestors/null_safety_prep/utils/hint_detection.dart';
import 'package:over_react_codemod/src/util.dart';
import 'package:analyzer/dart/ast/ast.dart';

import '../../util/class_suggestor.dart';

/// Suggestor to assist with preparations for null-safety by adding
/// nullability (`?`) hints to state field types.
///
/// This is intended to be run after [ClassComponentRequiredInitialStateMigrator]
/// to make the rest of the state fields nullable.
class StateMixinSuggestor extends RecursiveAstVisitor<void>
    with ClassSuggestor {
  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    super.visitVariableDeclaration(node);

    final isStateClass = (node.declaredElement?.enclosingElement
            ?.tryCast<InterfaceElement>()
            ?.allSupertypes
            .any((s) => s.element.name == 'UiState') ??
        false);
    if (!isStateClass) return;

    final fieldDeclaration = node.parentFieldDeclaration;
    if (fieldDeclaration == null) return;
    if (fieldDeclaration.isStatic) return;
    if (fieldDeclaration.fields.isConst) return;

    final type = fieldDeclaration.fields.type;
    if (type != null &&
        (requiredHintAlreadyExists(type) || nullableHintAlreadyExists(type))) {
      return;
    }

    // Make state field optional.
    if (type != null) {
      yieldPatch(nullableHint, type.end, type.end);
    }
  }

  @override
  Future<void> generatePatches() async {
    final r = await context.getResolvedUnit();
    if (r == null) {
      throw Exception(
          'Could not get resolved result for "${context.relativePath}"');
    }
    r.unit.accept(this);
  }
}

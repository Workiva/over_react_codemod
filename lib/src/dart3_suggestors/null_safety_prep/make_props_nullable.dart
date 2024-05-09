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
import 'package:over_react_codemod/src/dart3_suggestors/null_safety_prep/analyzer_plugin_utils.dart';
import 'package:over_react_codemod/src/dart3_suggestors/null_safety_prep/utils/hint_detection.dart';
import 'package:over_react_codemod/src/util/class_suggestor.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:over_react_codemod/src/util/get_all_props.dart';

class MakeNonDefaultedPropsNullableMigrator
    extends RecursiveAstVisitor<void> with ClassSuggestor {
  late ResolvedUnitResult _result;

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    patchAllProps(node.declaredElement);
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    patchAllProps(node.declaredElement);
  }

  void patchAllProps(InterfaceElement? propsElement) {
    if (propsElement == null) return;
    final props = getAllProps(propsElement);
    if (props.isEmpty) return;
    final propDecls = props.map((el) => lookUpVariable(el, _result.unit)).whereNotNull().where((decl) {
      final type = (decl.parent! as VariableDeclarationList).type;
      if (type == null) return false;
      if (requiredHintAlreadyExists(type) || nullableHintAlreadyExists(type) || nonNullableHintAlreadyExists(type)) {
        return false;
      }
      return true;
    });

    for (final propDecl in propDecls) {
      final parent = propDecl.parent! as VariableDeclarationList;
      final type = parent.type;
      final keyword = parent.keyword;
      final fieldNameToken = propDecl.name;
      // dynamic added if type is null b/c we gotta have a type to add the nullable `?` hint
      final patchedType = type == null ? 'dynamic/*?*/' : '${type.toSource()}/*?*/';
      final startOffset =
          type?.offset ?? keyword?.offset ?? fieldNameToken.offset;

      yieldPatch(patchedType, startOffset, fieldNameToken.offset);
    }
  }

  @override
  Future<void> generatePatches() async {
    final result = await context.getResolvedUnit();
    if (result == null) {
      throw Exception(
          'Could not get resolved result for "${context.relativePath}"');
    }
    _result = result;
    _result.unit.accept(this);
  }
}

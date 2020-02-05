// Copyright 2020 Workiva Inc.
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
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:codemod/codemod.dart';

import 'boilerplate_utilities.dart';

/// Suggestor that updates stand alone props mixins to be actual mixins.
///
/// > Related: [PropsMetaMigrator]
class PropsMixinMigrator extends GeneralizingAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  @override
  visitClassDeclaration(ClassDeclaration node) {
    super.visitClassDeclaration(node);

    if (!shouldMigratePropsAndStateMixin(node)) return;

    migrateClassToMixin(node, yieldPatch);
    _removePropsOrStateGetter(node);
    _removePropsOrStateMixinAnnotation(node);
    _migrateMixinMetaField(node);
  }

  void _removePropsOrStateGetter(ClassDeclaration node) {
    final classGetters = node.members
        .whereType<MethodDeclaration>()
        .where((method) => method.isGetter);
    final propsOrStateGetter = classGetters.singleWhere(
        (getter) => getter.name.name == 'props' || getter.name.name == 'state',
        orElse: () => null);
    if (propsOrStateGetter != null) {
      yieldPatch(propsOrStateGetter.offset, propsOrStateGetter.end + 1, '');
    }
  }

  void _removePropsOrStateMixinAnnotation(ClassDeclaration node) {
    final propsMixinAnnotationNode = getAnnotationNode(node, 'PropsMixin');
    if (propsMixinAnnotationNode != null) {
      yieldPatch(propsMixinAnnotationNode.offset,
          propsMixinAnnotationNode.end + 1, '');
    }

    final stateMixinAnnotationNode = getAnnotationNode(node, 'StateMixin');
    if (stateMixinAnnotationNode != null) {
      yieldPatch(stateMixinAnnotationNode.offset,
          stateMixinAnnotationNode.end + 1, '');
    }
  }

  /// NOTE: Usage of the meta field elsewhere will be migrated via the [PropsMetaMigrator].
  void _migrateMixinMetaField(ClassDeclaration node) {
    final classMembers = node.members;
    final classFields = classMembers
        .whereType<FieldDeclaration>()
        .map((decl) => decl.fields)
        .toList();
    final metaField = classFields.singleWhere(
        (field) => field.variables.single.name.name == 'meta',
        orElse: () => null);
    if (metaField == null) return;

    if (isPublic(node)) {
      yieldPatch(metaField.parent.offset, metaField.parent.offset,
          '@Deprecated(\'Use `propsMeta.forMixin(${node.name.name})` instead.\')\n');
    } else {
      // Remove the meta field, along with any comment lines that preceded it.
      final metaFieldDecl = metaField.parent;
      final previousMember = metaFieldDecl == classMembers.first
          ? null
          : classMembers[classMembers.indexOf(metaFieldDecl) - 1];
      final begin = previousMember != null
          ? previousMember.end + 1
          : node.leftBracket.offset + 1;

      yieldPatch(begin, metaField.end + 1, '');
    }
  }
}
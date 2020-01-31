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

import '../util.dart';
import 'boilerplate_utilities.dart';

/// Suggestor that updates props and state classes to new boilerplate.
///
/// This should only be done on cases where the props and state classes are not
/// simple use cases. E.g. when a prop class uses mixins or anytime it doesn't extend
/// UiProps / UiState.
///
/// Note: This should not operate on a class that does fit the criteria for _simple_.
class AdvancedPropsAndStateClassMigrator extends GeneralizingAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  @override
  visitClassDeclaration(ClassDeclaration node) {
    super.visitClassDeclaration(node);

    if (!isAssociatedWithComponent2(node) ||
        !isAPropsOrStateClass(node) ||
        isSimplePropsOrStateClass(node) ||
        // Stub while <https://jira.atl.workiva.net/browse/CPLAT-9308> is in progress
        _isPublic(node)) return;

    final className = node.name.toSource().substring(2);


    final startingString = extendsFromUiPropsOrUiState(node) ? 'with' : 'with ${node.extendsClause.superclass.toSource()}Mixin';
    final withClause = node.withClause?.childEntities?.whereType<TypeName>()?.joinWithToSource(startingString: startingString == 'width' ? startingString : '$startingString, ');

    final newClassDeclarationString = '\n\nclass $className = Ui${className.contains('Props') ? 'Props' : 'State'} ${withClause ?? startingString};';

    migrateClassToMixin(node, yieldPatch, shouldAddMixinToName: true, shouldSwapParentClass: true);
    yieldPatch(node.end, node.end, newClassDeclarationString);
  }
}

// Stub while <https://jira.atl.workiva.net/browse/CPLAT-9308> is in progress
bool _isPublic(ClassDeclaration node) => false;
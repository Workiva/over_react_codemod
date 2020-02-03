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
  final bool shouldMigrateCustomClassAndMixins;

  AdvancedPropsAndStateClassMigrator(
      {this.shouldMigrateCustomClassAndMixins = false});

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    super.visitClassDeclaration(node);

    if (!shouldMigrateAdvancedPropsAndStateClass(node)) return;

    final extendsFromCustomClass = !extendsFromUiPropsOrUiState(node);
    final hasMixins = node.withClause != null;

    // Don't operate if the props class uses mixins and extends a custom class
    if (hasMixins &&
        extendsFromCustomClass &&
        !shouldMigrateCustomClassAndMixins) return;

    final className = stripPrivateGeneratedPrefix(node.name.toSource());
    var newClassDeclarationString =
        '\n\nclass $className = Ui${className.contains('Props') ? 'Props' : 'State'} with ';

    if (extendsFromCustomClass) {
      final parentClass = node.extendsClause.superclass.toSource() + 'Mixin';
      newClassDeclarationString +=
          '$parentClass, ${className}Mixin${hasMixins ? ',' : ';'}';
    }

    if (hasMixins) {
      if (hasMixins && !extendsFromCustomClass) {
        newClassDeclarationString += '${className}Mixin,';
      }
      
      newClassDeclarationString = node.withClause?.childEntities
          ?.whereType<TypeName>()
          ?.joinWithToSource(
              startingString: newClassDeclarationString, endingString: ';');
    }

    migrateClassToMixin(node, yieldPatch,
        shouldAddMixinToName: true,
        shouldSwapParentClass: extendsFromCustomClass);
    yieldPatch(node.end, node.end, newClassDeclarationString);
  }
}

bool shouldMigrateAdvancedPropsAndStateClass(ClassDeclaration node) =>
    shouldMigratePropsAndStateClass(node) && isAdvancedPropsOrStateClass(node);

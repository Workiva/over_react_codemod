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
import 'package:over_react_codemod/src/react16_suggestors/react16_utilities.dart';

import '../util.dart';
import 'boilerplate_constants.dart';
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
  final ClassToMixinConverter converter;
  final SemverHelper semverHelper;

  AdvancedPropsAndStateClassMigrator(this.converter, this.semverHelper);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    super.visitClassDeclaration(node);

    if (!hasComment(node, sourceFile,
            publicExportLocationsComment(node, semverHelper)) &&
        shouldAddPublicExportLocationsAdvancedClassComment(
            node, semverHelper)) {
      yieldPatch(
        node.metadata.first.offset,
        node.metadata.first.offset,
        publicExportLocationsComment(node, semverHelper) + '\n',
      );
    }

    if (!shouldMigrateAdvancedPropsAndStateClass(node, semverHelper)) return;

    final extendsFromCustomClass = !extendsFromUiPropsOrUiState(node);
    final hasMixins = node.withClause != null;
    final parentClassName = node.extendsClause.superclass.name.name;

    final className = stripPrivateGeneratedPrefix(node.name.name);
    final newDeclarationBuffer = StringBuffer()
      ..write('\n\n')
      // Write a fix me comment if this class extends a custom class
      ..write(!extendsFromCustomClass
          ? ''
          : '''
          // FIXME:
          //   1. Ensure that all mixins used by $parentClassName are also mixed into this class.
          //   2. Fix any analyzer warnings on this class about missing mixins
           ''')
      // Create the class name
      ..write('class $className = ')
      // Decide if the class is a Props or a State class
      ..write('Ui${isAPropsClass(node) ? 'Props' : 'State'} ')
      // Add the width clause
      ..write('with ');

    if (extendsFromCustomClass) {
      newDeclarationBuffer.write(
          '${parentClassName}Mixin, ${className}Mixin${hasMixins ? ',' : ''}');
    }

    if (hasMixins) {
      if (!extendsFromCustomClass) {
        newDeclarationBuffer.write('${className}Mixin,');
      }

      newDeclarationBuffer.write(node.withClause.mixinTypes.joinByName());
    }

    newDeclarationBuffer.write(';');

    converter.migrate(node, yieldPatch,
        shouldAddMixinToName: true,
        shouldSwapParentClass: extendsFromCustomClass);
    yieldPatch(node.end, node.end, newDeclarationBuffer.toString());
  }
}

bool shouldMigrateAdvancedPropsAndStateClass(
        ClassDeclaration node, SemverHelper semverHelper) =>
    shouldMigratePropsAndStateClass(node, semverHelper) &&
    isAdvancedPropsOrStateClass(node);

bool shouldAddPublicExportLocationsAdvancedClassComment(
        ClassDeclaration node, SemverHelper semverHelper) =>
    shouldAddPublicExportLocationsComment(node, semverHelper) &&
    isAdvancedPropsOrStateClass(node);

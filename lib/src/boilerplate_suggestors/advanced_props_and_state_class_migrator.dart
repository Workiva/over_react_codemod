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
  final ClassToMixinConverter converter;

  AdvancedPropsAndStateClassMigrator(this.converter);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    super.visitClassDeclaration(node);

    if (!shouldMigrateAdvancedPropsAndStateClass(node)) return;

    final extendsFromCustomClass = !extendsFromUiPropsOrUiState(node);
    final hasMixins = node.withClause != null;
    final parentClassName = node.extendsClause.superclass.name.name;
    final parentClassTypeArgs =
        node.extendsClause.superclass.typeArguments ?? '';

    final className = stripPrivateGeneratedPrefix(node.name.name);
    final classTypeArgs = node.typeParameters ?? '';
    final mixinWillBeCreatedFromClass =
        getNameOfDupeClass(className, node.root, converter) == null;
    final classNameMixinForBuffer =
        mixinWillBeCreatedFromClass ? ', ${className}Mixin$classTypeArgs' : '';
    final classNeedsBody =
        !mixinWillBeCreatedFromClass && node.members.isNotEmpty;

    final newDeclarationBuffer = StringBuffer()
      ..write('\n\n')
      // Write a fix me comment if this class extends a custom class
      ..write(!extendsFromCustomClass
          ? ''
          : '''
          // FIXME:
          //   1. Ensure that all mixins used by ${getConvertedClassMixinName(parentClassName, converter)} are also mixed into this class.
          //   2. Fix any analyzer warnings on this class about missing mixins
           ''')
      // Create the class name
      ..write('class $className$classTypeArgs')
      ..write(classNeedsBody ? ' extends ' : ' = ')
      // Decide if the class is a Props or a State class
      ..write('Ui${isAPropsClass(node) ? 'Props' : 'State'} ')
      // Add the width clause
      ..write('with ');

    if (extendsFromCustomClass) {
      newDeclarationBuffer.write(
          '${getConvertedClassMixinName(parentClassName, converter)}$parentClassTypeArgs$classNameMixinForBuffer${hasMixins ? ',' : ''}');
    }

    if (hasMixins) {
      if (!extendsFromCustomClass && mixinWillBeCreatedFromClass) {
        newDeclarationBuffer.write('${className}Mixin$classTypeArgs,');
      }

      newDeclarationBuffer
          .write(node.withClause.mixinTypes.joinByName(converter: converter));
    }

    if (classNeedsBody) {
      // If no mixin will be created from the class in the `converter.migrate` step below,
      // and it has members of its own, we need to preserve those members (fields) within the concrete class.
      newDeclarationBuffer
        ..write('{\n')
        ..writeAll(node.members.map((member) => member.toSource()))
        ..write('\n}');
    } else {
      newDeclarationBuffer.write(';');
    }

    converter.migrate(node, yieldPatch,
        shouldAddMixinToName: true,
        shouldSwapParentClass: extendsFromCustomClass);
    yieldPatch(node.end, node.end, newDeclarationBuffer.toString());
  }
}

bool shouldMigrateAdvancedPropsAndStateClass(ClassDeclaration node) =>
    shouldMigratePropsAndStateClass(node) && isAdvancedPropsOrStateClass(node);

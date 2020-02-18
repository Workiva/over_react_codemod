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

    if (shouldAddPublicExportLocationsAdvancedClassComment(
            node, semverHelper) &&
        !hasComment(node, sourceFile,
            publicExportLocationsComment(node, semverHelper))) {
      yieldPatch(
        node.metadata.first.offset,
        node.metadata.first.offset,
        publicExportLocationsComment(node, semverHelper) + '\n',
      );
    }

    if (!shouldMigrateAdvancedPropsAndStateClass(node, semverHelper)) return;

    final extendsFromCustomClass = !extendsFromUiPropsOrUiState(node);
    final hasMixins = node.withClause != null;
    final hasInterfaces = node.implementsClause != null;
    final parentClassName = node.extendsClause.superclass.name.name;
    final parentClassTypeArgs =
        node.extendsClause.superclass.typeArguments ?? '';

    final className = stripPrivateGeneratedPrefix(node.name.name);
    final classTypeArgs = node.typeParameters ?? '';
    final dupeMixinExists =
        getNameOfDupeClass(className, node.root, converter) != null;
    final mixinWillBeCreatedFromClass =
        !dupeMixinExists && node.members.isNotEmpty;
    final dupeClassInSameRoot = getDupeClassInSameRoot(className, node.root);
    final classNeedsBody = node.members.isNotEmpty &&
        dupeMixinExists &&
        dupeClassInSameRoot == null;

    StringBuffer getMixinsForNewDeclaration({bool includeParentClass = true}) {
      final mixinsForNewDeclaration = StringBuffer();
      if (extendsFromCustomClass) {
        final baseAndParentClassMixins = <String>[];

        if (includeParentClass) {
          baseAndParentClassMixins.add(
              '${getConvertedClassMixinName(parentClassName, converter)}$parentClassTypeArgs');
        }

        if (mixinWillBeCreatedFromClass) {
          baseAndParentClassMixins.add('${className}Mixin$classTypeArgs');
        }

        if (baseAndParentClassMixins.isNotEmpty) {
          mixinsForNewDeclaration.write(baseAndParentClassMixins.join(','));

          if (hasMixins) {
            mixinsForNewDeclaration.write(', ');
          }
        }
      }

      if (hasMixins) {
        if (!extendsFromCustomClass && mixinWillBeCreatedFromClass) {
          mixinsForNewDeclaration.write('${className}Mixin$classTypeArgs, ');
        }

        mixinsForNewDeclaration.write(node.withClause.mixinTypes
            .joinConvertedClassesByName(
                converter: converter, sourceFile: sourceFile));
      }

      return mixinsForNewDeclaration;
    }

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
      ..write(node.isAbstract ? 'abstract class ' : 'class ')
      ..write('$className$classTypeArgs');

    StringBuffer mixins;

    if (node.isAbstract) {
      mixins = getMixinsForNewDeclaration();
      // Since its abstract, we'll create an interface-only class which can then be implemented by
      // concrete subclasses that have component classes that extend from the analogous abstract component class.
      newDeclarationBuffer.write(' implements $mixins');

      if (hasInterfaces) {
        newDeclarationBuffer.write(
            ', ${node.implementsClause.interfaces.joinConvertedClassesByName()}');
      }
    } else {
      // Its a concrete class. Have it extend from UiProps/State with mixins

      final willNeedToImplementAbstractInterface =
          isAssociatedWithAbstractComponent2(node) && extendsFromCustomClass;
      final abstractInterfaceHasAnalogousMixin =
          getConvertedClassMixinName(parentClassName, converter) !=
              parentClassName;

      mixins = willNeedToImplementAbstractInterface &&
              !abstractInterfaceHasAnalogousMixin
          // Since the parentClassName will be what is implemented in that scenario -
          // we don't want to have that class in both the withClause and the implementsClause.
          ? getMixinsForNewDeclaration(includeParentClass: false)
          : getMixinsForNewDeclaration();

      newDeclarationBuffer
        ..write(classNeedsBody || mixins.isEmpty ? ' extends ' : ' = ')
        // Decide if the class is a Props or a State class
        ..write('Ui${isAPropsClass(node) ? 'Props' : 'State'} ')
        // Add the with clause
        ..write(mixins.isEmpty ? '' : 'with $mixins');

      if (hasInterfaces || willNeedToImplementAbstractInterface) {
        newDeclarationBuffer.write(' implements ');

        if (willNeedToImplementAbstractInterface) {
          // The analogous component instance for this props/state class extends from an abstract component.
          // This means that in order for the generic params of the component to continue to work, the
          // concrete props/state class will need to implement the abstract props/state class.
          newDeclarationBuffer.write('$parentClassName$parentClassTypeArgs');

          if (hasInterfaces) {
            newDeclarationBuffer.write(', ');
          }
        }

        if (hasInterfaces) {
          newDeclarationBuffer.write(
              node.implementsClause.interfaces.joinConvertedClassesByName());
        }
      }
    }

    if (dupeMixinExists && node.members.isNotEmpty) {
      // If no mixin will be created from the class in the `converter.migrate` step below
      // as a result of a mixin with a name that matches the current node's name appended with "Mixin",
      // and it has members of its own, we need to preserve those members (fields) by moving them to the
      // existing mixin (if possible - within the same root), or create a FIX ME comment indicating what
      // needs to be done.
      if (dupeClassInSameRoot != null) {
        yieldPatch(
            dupeClassInSameRoot.rightBracket.offset,
            dupeClassInSameRoot.rightBracket.offset,
            node.members.map((member) => member.toSource()).join('\n'));

        newDeclarationBuffer.write(node.isAbstract ? '{}' : ';');
      } else {
        newDeclarationBuffer
          ..write('{\n')
          ..write('''
              // FIXME: Everything in this body needs to be moved to the body of ${getNameOfDupeClass(className, node.root, converter)}.
              // Once that is done, the body can be removed, and `extends` can be replaced with `=`.
              ''')
          ..writeAll(node.members.map((member) => member.toSource()))
          ..write('\n}');
      }
    } else {
      newDeclarationBuffer
          .write(node.isAbstract || mixins.isEmpty ? '{}' : ';');
    }

    converter.migrate(node, yieldPatch,
        shouldAddMixinToName: true,
        shouldSwapParentClass: extendsFromCustomClass,
        sourceFile: sourceFile);
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

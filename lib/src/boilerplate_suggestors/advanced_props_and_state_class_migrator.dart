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
import 'package:over_react_codemod/src/boilerplate_suggestors/migration_decision.dart';
import 'package:source_span/source_span.dart';

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
  final SemverHelper semverHelper;
  final bool convertClassesWithExternalSuperclass;
  final bool _treatUnvisitedClassesAsExternal;

  AdvancedPropsAndStateClassMigrator(
    this.converter,
    this.semverHelper, {
    // NOTE: convertClassesWithExternalSuperclass should only be set
    // to `true` on the second "run" via the `main` of `boilerplate_upgrade.dart`.
    this.convertClassesWithExternalSuperclass = false,
    bool treatUnvisitedClassesAsExternal,
  }) : _treatUnvisitedClassesAsExternal = treatUnvisitedClassesAsExternal ??
            convertClassesWithExternalSuperclass;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    super.visitClassDeclaration(node);
    converter.recordVisit(node);

    final parentClassName = node.extendsClause?.superclass?.name?.name;
    final mixinNames = node.withClause?.mixinTypes?.getConvertedClassesByName(
          converter: converter,
          sourceFile: sourceFile,
          includeGenericParameters: false,
          includeComments: false,
          includePrivateGeneratedClassNames: false,
        ) ??
        [];

    final migrationDecision = shouldMigrateAdvancedPropsAndStateClass(
      node,
      converter,
      semverHelper,
      sourceFile,
      mixinNames: mixinNames,
      parentClassHasBeenVisited: converter.wasVisited(parentClassName),
      parentClassHasBeenConverted: converter.wasMigrated(parentClassName),
      treatUnvisitedClassesAsExternal: _treatUnvisitedClassesAsExternal,
      convertClassesWithExternalSuperclass:
          convertClassesWithExternalSuperclass,
    );
    if (!migrationDecision.yee) {
      migrationDecision.patchWithReasonComment(node, yieldPatch);
      return;
    }

    final declIsAbstract = isAbstract(node);
    final extendsFromCustomClass = !extendsFromUiPropsOrUiState(node);
    final extendsFromReservedClass = isReservedBaseClass(parentClassName) &&
        !extendsFromUiPropsOrUiState(node);
    final hasMixins = node.withClause != null;
    final hasInterfaces = node.implementsClause != null;
    final parentClassTypeArgs =
        node.extendsClause.superclass.typeArguments ?? '';

    final className = stripPrivateGeneratedPrefix(node.name.name);
    final nameOfDupeMixin = getNameOfDupeClass(className, node.root, converter);
    final dupeMixinExists = nameOfDupeMixin != null;
    final mixinWillBeCreatedFromClass =
        !dupeMixinExists && node.members.isNotEmpty;
    final dupeClassInSameRoot = getDupeClassInSameRoot(className, node.root);
    final classNeedsBody = node.members.isNotEmpty &&
        dupeMixinExists &&
        dupeClassInSameRoot == null;

    String getClassTypeArgs({bool forUseInImplementsOrWithClause = false}) {
      if (node.typeParameters == null) {
        return '';
      }

      if (forUseInImplementsOrWithClause && declIsAbstract) {
        // The node is abstract, and these typeArgs will be used on a mixin/interface for that node
        // which means they should only have the type identifiers as args - not the
        // full `<<SimpleIdentifier> extends <TypeName>>` args.
        final typeIdentifiers = node.typeParameters.childEntities
            .whereType<TypeParameter>()
            .map((typeParam) =>
                typeParam.childEntities.whereType<SimpleIdentifier>())
            .expand((i) => i);
        if (typeIdentifiers.isNotEmpty) {
          return '<${typeIdentifiers.join(',')}>';
        }
      }

      return node.typeParameters.toString();
    }

    StringBuffer mixins;
    StringBuffer getMixinsForNewDeclaration({bool includeParentClass = true}) {
      final mixinsForNewDeclaration = StringBuffer();
      if (extendsFromCustomClass || extendsFromReservedClass) {
        final baseAndParentClassMixins = <String>[];

        if (includeParentClass) {
          baseAndParentClassMixins.add(
              '${getConvertedClassMixinName(parentClassName, converter)}$parentClassTypeArgs');
        }

        if (mixinWillBeCreatedFromClass) {
          baseAndParentClassMixins.add(
              '${className}Mixin${getClassTypeArgs(forUseInImplementsOrWithClause: true)}');
        }

        if (baseAndParentClassMixins.isNotEmpty) {
          mixinsForNewDeclaration.write(baseAndParentClassMixins.join(','));

          if (hasMixins) {
            mixinsForNewDeclaration.write(', ');
          }
        }
      }

      if (hasMixins) {
        if (!(extendsFromCustomClass || extendsFromReservedClass) &&
            mixinWillBeCreatedFromClass) {
          mixinsForNewDeclaration.write(
              '${className}Mixin${getClassTypeArgs(forUseInImplementsOrWithClause: true)}, ');
        }

        mixinsForNewDeclaration.write(node.withClause.mixinTypes
            .joinConvertedClassesByName(
                converter: converter, sourceFile: sourceFile));
      }

      return mixinsForNewDeclaration;
    }

    final newDeclarationBuffer = StringBuffer()
      ..write('\n\n')
      // The metadata (e.g. `@Props()` / `@State()` annotations) must remain
      // on the concrete class in order for the `StubbedPropsAndStateClassRemover`
      // migrator to work correctly. The vast majority of these will be removed by the
      // `AnnotationsRemover` migrator in a later step of the migration.
      ..write('${node.metadata.join('\n')}\n')
      // NOTE: There is no need for a FIX ME comment when both the subclass and superclass are abstract
      // because our migrator will convert abstract superclasses into "interface only" instances which
      // implement all the things it used to only mix in - so by implementing that new
      // "interface only" version... everything from the superclass will already be implemented,
      // and there is no need to use those interfaces as mixins on the abstract subclass.
      //
      // Unfortunately, we don't have access to the actual AST of the superclass to make a proper determination
      // of whether it is abstract - so we'll just catch the majority of cases by looking at its name.
      ..write((declIsAbstract && parentClassName.contains('Abstract'))
          ? ''
          : getFixMeCommentForConvertedClassDeclaration(
              converter: converter,
              mixinNames: mixinNames,
              parentClassName: parentClassName,
              convertClassesWithExternalSuperclass:
                  convertClassesWithExternalSuperclass,
            ))
      // Create the class name
      ..write(declIsAbstract ? 'abstract class ' : 'class ')
      ..write('$className${getClassTypeArgs()}');

    if (declIsAbstract) {
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
          isAssociatedWithAbstractComponent2(node) &&
              (extendsFromCustomClass || extendsFromReservedClass);
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

        newDeclarationBuffer.write(declIsAbstract ? '{}' : ';');
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
      newDeclarationBuffer.write(declIsAbstract || mixins.isEmpty ? '{}' : ';');
    }

    converter.migrate(node, yieldPatch,
        shouldAddMixinToName: true,
        shouldSwapParentClass:
            extendsFromCustomClass || extendsFromReservedClass,
        convertClassesWithExternalSuperclass:
            convertClassesWithExternalSuperclass,
        sourceFile: sourceFile);

    // If a class extends from UiProps/UiState and uses a single mixin that has a name
    // that matches the concrete class name appended with `Mixin`, the call to
    // `converter.migrate` will result in the old concrete class being deleted.
    //
    // In this case, we should also not create a new concrete class declaration
    // since the "shorthand" / "mixin only" boilerplate will suffice.
    if (!extendsFromCustomClass &&
        dupeMixinExists &&
        node.withClause.mixinTypes.length == 1 &&
        node.implementsClause == null) {
      // Do not patch with a new concrete class. Instead, update the component
      // declaration to utilize the mixin instead of the old concrete class.
      final componentNode = getComponentNodeInRoot(node);

      final classNameAsSuperclassTypeArgument = componentNode
          .extendsClause.superclass.typeArguments.arguments
          .where((arg) => arg.toSource() == className);
      final classNameAsMixinTypeArgument = componentNode.withClause?.mixinTypes
          ?.map((type) => type.typeArguments.arguments
              .where((arg) => arg.toSource() == className))
          ?.expand((arg) => arg);
      final classNameAsInterfaceTypeArgument = componentNode
          .implementsClause?.interfaces
          ?.map((type) => type.typeArguments.arguments
              .where((arg) => arg.toSource() == className))
          ?.expand((arg) => arg);
      final allClassNameAsTypeArguments = [
        ...classNameAsSuperclassTypeArgument,
        ...?classNameAsMixinTypeArgument,
        ...?classNameAsInterfaceTypeArgument,
      ];

      for (var classNameAsTypeArg in allClassNameAsTypeArguments) {
        yieldPatch(
            classNameAsTypeArg.offset, classNameAsTypeArg.end, nameOfDupeMixin);
      }

      // By deleting the dupe class and using the migrated (existing) mixin,
      // we are converting the declaration into a "shorthand" version of the boilerplate
      // in which the mixin now doubles as the props class for the component instance.
      //
      // This means that the default `consumedProps` for the component will be all the
      // props within the mixin. With the old boilerplate, if `consumedProps` was not
      // overridden in the component - the props within the mixin would get forwarded to
      // children via `addUnconsumedProps` since the default `consumedProps` were the props
      // in the separate concrete class.  But in the new "shorthand" boilerplate, since there
      // is no separate concrete class, those mixin props will get consumed by
      // default - which is a breaking change.
      //
      // To counteract this, we need to override `consumedProps` to be an empty list if
      // the component isn't already overriding it so that the mixin props continue to
      // get forwarded to child components the same way they did before the migration.
      final consumedPropsDeclarations = componentNode.members
          .whereType<MethodDeclaration>()
          .where((method) => method.name.name == 'consumedProps');
      if (consumedPropsDeclarations.isEmpty) {
        yieldPatch(componentNode.leftBracket.offset + 1,
            componentNode.leftBracket.offset + 1, '''
        // Override consumedProps to an empty list so that props within 
        // $nameOfDupeMixin are forwarded when `addUnconsumedProps` is used.
        @override
        get consumedProps => [];
        
        ''');
      } else {
        final consumedPropsDeclaration = consumedPropsDeclarations.single;
        ListLiteral currentConsumedProps;
        final consumedPropsExpressionFunctionBody = consumedPropsDeclaration
            .childEntities
            .whereType<ExpressionFunctionBody>();
        final consumedPropsBlockBody = consumedPropsDeclaration.childEntities
            .whereType<BlockFunctionBody>();
        if (consumedPropsExpressionFunctionBody.isNotEmpty) {
          currentConsumedProps = consumedPropsExpressionFunctionBody
              .single.childEntities
              .whereType<ListLiteral>()
              .single;
        } else if (consumedPropsBlockBody.isNotEmpty) {
          currentConsumedProps = consumedPropsBlockBody
              .single.block.childEntities
              .whereType<ReturnStatement>()
              .single
              .childEntities
              .whereType<ListLiteral>()
              .single;
        }

        if (currentConsumedProps.elements.isNotEmpty) {
          if (node.members.isNotEmpty) {
            yieldPatch(consumedPropsDeclaration.offset,
                consumedPropsDeclaration.offset, '''
              // FIXME: As part of the over_react boilerplate migration, $className was removed, 
              // and all of its props were moved to $nameOfDupeMixin. Double check the `consumedProps` values below,
              // and the prop forwarding behavior of this component to ensure that no regressions have occurred.
              ''');
          } else {
            yieldPatch(consumedPropsDeclaration.offset,
                consumedPropsDeclaration.offset, '''
              // FIXME: As part of the over_react boilerplate migration, $className was removed, 
              // and replaced by $nameOfDupeMixin. Double check the `consumedProps` values below,
              // and the prop forwarding behavior of this component to ensure that no regressions have occurred.
              ''');
          }

          final metaForConcreteClassThatWillBeRemoved = currentConsumedProps
              .elements
              .singleWhere((el) => el.toSource() == '$className.meta',
                  orElse: () => null);
          if (metaForConcreteClassThatWillBeRemoved != null) {
            yieldPatch(
                metaForConcreteClassThatWillBeRemoved.offset,
                metaForConcreteClassThatWillBeRemoved.end,
                'propsMeta.forMixin($nameOfDupeMixin)');
          }
        }
      }
    } else {
      // Patch with our newly generated concrete class
      yieldPatch(node.end, node.end, newDeclarationBuffer.toString());
    }

    // If a class did not get migrated previously because it extended from a custom superclass that
    // did not get migrated, the FIX ME comment that was added may now need to be removed if the
    // consumer has gone through and manually addressed issues such that the superclass is now "migratable".
    if (extendsFromCustomClass && converter.wasMigrated(parentClassName)) {
      final commentToRemove = getUnMigratedSuperclassReasonComment(
          stripPrivateGeneratedPrefix(node.name.name), parentClassName);
      removeCommentFromNode(node, commentToRemove, yieldPatch);
    }
  }
}

MigrationDecision shouldMigrateAdvancedPropsAndStateClass(
  ClassDeclaration node,
  ClassToMixinConverter converter,
  SemverHelper semverHelper,
  SourceFile sourceFile, {
  bool convertClassesWithExternalSuperclass = false,
  bool parentClassHasBeenVisited = false,
  bool parentClassHasBeenConverted = false,
  bool treatUnvisitedClassesAsExternal = false,
  List<String> mixinNames = const [],
}) {
  if (converter.wasMigrated(node.name.name)) {
    return MigrationDecision(false);
  }

  final _shouldMigratePropsAndStateClass =
      getPropsAndStateClassMigrationDecision(node, semverHelper, sourceFile);
  if (!_shouldMigratePropsAndStateClass.yee) {
    return _shouldMigratePropsAndStateClass;
  } else if (!isAdvancedPropsOrStateClass(node)) {
    return MigrationDecision(false);
  } else {
    // It is an advanced props/state class
    final publicNodeName = stripPrivateGeneratedPrefix(node.name.name);
    final superclassName = node.extendsClause.superclass.name.name;
    final isFirstTimeVisitingClasses = !treatUnvisitedClassesAsExternal;

    if (isReservedBaseClass(superclassName) && mixinNames.isEmpty) {
      // Does not extend from a custom superclass, does not use any mixins,
      // and does not extend from UiProps / UiState - meaning it extends
      // from some other "reserved" class like `FluxUiProps`.
      return MigrationDecision(true);
    }

    final migrationDecisionsBasedOnMixins = <String, MigrationDecision>{};
    if (mixinNames.isNotEmpty) {
      final mixinNamesThatAreExternal = <String>[];

      // Has one or more mixins
      for (var mixinName in mixinNames) {
        if (!isReservedBaseClass(mixinName) &&
            !converter.wasVisited(mixinName)) {
          if (isFirstTimeVisitingClasses) {
            // An advanced class with a mixin that has not been visited yet.
            // However, this is the first run through the script since `treatUnvisitedClassesAsExternal` is false,
            // so just short-circuit and do nothing since we'll circle back on the second run.
            migrationDecisionsBasedOnMixins[mixinName] =
                MigrationDecision(false);
          } else {
            // An advanced class with a mixin that has not been visited after two runs,
            // indicating that the mixin does not exist in the current repo / lib.
            if (convertClassesWithExternalSuperclass) {
              migrationDecisionsBasedOnMixins[mixinName] =
                  MigrationDecision(true);
            } else {
              mixinNamesThatAreExternal.add(mixinName);
            }
          }
        } else {
          migrationDecisionsBasedOnMixins[mixinName] = MigrationDecision(true);
        }
      }

      if (mixinNamesThatAreExternal.isNotEmpty) {
        migrationDecisionsBasedOnMixins[mixinNamesThatAreExternal.join(', ')] =
            MigrationDecision(false,
                reason: getExternalSuperclassOrMixinReasonComment(
                    publicNodeName, mixinNamesThatAreExternal,
                    mixinsAreExternal: true));
      }
    }

    final migrationDecisionsBasedOnSuperclass = <String, MigrationDecision>{};
    if (!isReservedBaseClass(superclassName)) {
      // Extends from a custom superclass
      if (parentClassHasBeenVisited) {
        if (parentClassHasBeenConverted) {
          // Safe to convert regardless of whether its the first or second run.
          migrationDecisionsBasedOnSuperclass[superclassName] =
              MigrationDecision(true);
        } else {
          // Has not been converted
          if (isFirstTimeVisitingClasses) {
            // An advanced class with a superclass that has not been converted yet.
            // However, this is the first run through the script since `treatUnvisitedClassesAsExternal` is false,
            // so just short-circuit and do nothing since we'll circle back on the second run.
            migrationDecisionsBasedOnSuperclass[superclassName] =
                MigrationDecision(false);
          } else {
            // An advanced class with a superclass that has been visited, but not converted after two runs.
            migrationDecisionsBasedOnSuperclass[superclassName] =
                MigrationDecision(
                    false,
                    reason: getUnMigratedSuperclassReasonComment(
                        publicNodeName, superclassName));
          }
        }
      } else {
        // Parent class has not been visited
        if (isFirstTimeVisitingClasses) {
          // An advanced class with a superclass that has not been visited yet.
          // However, this is the first run through the script since `treatUnvisitedClassesAsExternal` is false,
          // so just short-circuit and do nothing since we'll circle back on the second run.
          migrationDecisionsBasedOnSuperclass[superclassName] =
              MigrationDecision(false);
        } else {
          // An advanced class with a superclass that has not been visited after two runs,
          // indicating that the class does not exist in the current repo / lib, or it is a "reserved" class.
          if (convertClassesWithExternalSuperclass ||
              isReservedBaseClass(superclassName)) {
            migrationDecisionsBasedOnSuperclass[superclassName] =
                MigrationDecision(true);
          } else {
            migrationDecisionsBasedOnSuperclass[superclassName] =
                MigrationDecision(
                    false,
                    reason: getExternalSuperclassOrMixinReasonComment(
                        publicNodeName, [superclassName]));
            ;
          }
        }
      }
    }

    final migrationDecisions = {
      ...migrationDecisionsBasedOnMixins,
      ...migrationDecisionsBasedOnSuperclass
    };

    if (migrationDecisions.values.every((decision) => decision.yee)) {
      return MigrationDecision(true);
    } else if (migrationDecisions.values
        .every((decision) => !decision.yee && decision.reason == null)) {
      return MigrationDecision(false);
    } else {
      // There is one or more migration decision that requires a FIX ME comment
      final reasons = migrationDecisions.values
          .where((decision) => !decision.yee && decision.reason != null)
          .map((decisionWithReason) => decisionWithReason.reason);

      if (reasons.isEmpty) {
        return MigrationDecision(false);
      }

      return MigrationDecision(false, reason: reasons.join('//\n'));
    }
  }
}

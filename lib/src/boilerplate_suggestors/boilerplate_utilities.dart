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
import 'package:meta/meta.dart';
import 'package:over_react_codemod/src/boilerplate_suggestors/migration_decision.dart';
import 'package:over_react_codemod/src/constants.dart';
import 'package:over_react_codemod/src/react16_suggestors/react16_utilities.dart';
import 'package:over_react_codemod/src/util.dart';
import 'package:source_span/source_span.dart';

typedef YieldPatch = void Function(
    int startingOffset, int endingOffset, String replacement);

@visibleForTesting
bool isPublicForTest = false;

// Stub while <https://jira.atl.workiva.net/browse/CPLAT-9308> is in progress
bool isPublic(ClassDeclaration node) => isPublicForTest;

/// Returns the annotation node associated with the provided [classNode]
/// that matches the provided [annotationName], if one exists.
AstNode getAnnotationNode(ClassDeclaration classNode, String annotationName) {
  return classNode.metadata.firstWhere(
      (node) => node.name.name == annotationName,
      orElse: () => null);
}

/// Whether the provided [className] is considered a "reserved" (non-custom) base class name to extend from or implement.
bool isReservedBaseClass(String className) {
  return [
    'UiProps',
    'UiState',
    'FluxUiProps',
  ].contains(className);
}

/// A simple evaluation of the annotation(s) of the [classNode]
/// to verify it is either a `@PropsMixin()` or `@StateMixin`.
bool isAPropsOrStateMixin(ClassDeclaration classNode) =>
    isAPropsMixin(classNode) || isAStateMixin(classNode);

/// A simple evaluation of the annotation(s) of the [classNode]
/// to verify it is a `@PropsMixin()`.
bool isAPropsMixin(ClassDeclaration classNode) =>
    getAnnotationNode(classNode, 'PropsMixin') != null;

/// A simple evaluation of the annotation(s) of the [classNode]
/// to verify it is a `@StateMixin()`.
bool isAStateMixin(ClassDeclaration classNode) =>
    getAnnotationNode(classNode, 'StateMixin') != null;

/// Whether a props or state mixin class [classNode] should be migrated as part of the boilerplate codemod.
bool shouldMigratePropsAndStateMixin(ClassDeclaration classNode) =>
    isAPropsOrStateMixin(classNode);

/// Whether a props or state class class [node] should be migrated as part of the boilerplate codemod.
MigrationDecision shouldMigratePropsAndStateClass(ClassDeclaration node) {
  final publicNodeName = stripPrivateGeneratedPrefix(node.name.name);
  const reRunMigrationScriptInstructions =
      'pub run over_react_codemod:boilerplate_upgrade';
  if (!isAPropsOrStateClass(node)) {
    return MigrationDecision(false);
  } else if (isPublic(node)) {
    return MigrationDecision(false,
        reason: getPublicApiReasonComment(publicNodeName));
  } else if (!isAssociatedWithComponent2(node)) {
    if (getComponentNodeInRoot(node)?.name?.name == null) {
      return MigrationDecision(false);
    }

    return MigrationDecision(
      false,
      reason: '''
      // FIXME: `$publicNodeName` could not be auto-migrated to the new over_react boilerplate 
      // because `${getComponentNodeInRoot(node).name.name}` does not extend from `react.Component2`.
      // 
      // Once you have upgraded the component, you can remove this FIXME comment and 
      // re-run the boilerplate migration script:
      // $reRunMigrationScriptInstructions
      ''',
    );
  }

  return MigrationDecision(true);
}

/// A simple RegExp against the parent of the class to verify it is `UiProps`
/// or `UiState`.
bool extendsFromUiPropsOrUiState(ClassDeclaration classNode) {
  return {
    'UiProps',
    'UiState',
  }.contains(classNode.extendsClause.superclass.name.name);
}

/// A simple RegExp against the parent of the class to verify it is `UiProps`
/// or `UiState`.
bool implementsUiPropsOrUiState(ClassDeclaration classNode) {
  return classNode.implementsClause.interfaces
      .map((typeName) => typeName.name.name)
      .any({'UiProps', 'UiState'}.contains);
}

/// A simple evaluation of the annotation(s) of the [classNode]
/// to verify it is either `@Props()` or `@State()` annotated class.
bool isAPropsOrStateClass(ClassDeclaration classNode) =>
    isAPropsClass(classNode) || isAStateClass(classNode);

/// A simple evaluation of the annotation(s) of the [classNode]
/// to verify it is a `@Props()` annotated class.
bool isAPropsClass(ClassDeclaration classNode) =>
    getAnnotationNode(classNode, 'Props') != null ||
    getAnnotationNode(classNode, 'AbstractProps') != null;

/// A simple evaluation of the annotation(s) of the [classNode]
/// to verify it is a `@State()` annotated class.
bool isAStateClass(ClassDeclaration classNode) =>
    getAnnotationNode(classNode, 'State') != null ||
    getAnnotationNode(classNode, 'AbstractState') != null;

/// Detects if the Props or State class is considered simple.
///
/// Simple means:
/// - Has no mixins
/// - Extends from UiProps
bool isSimplePropsOrStateClass(ClassDeclaration classNode) {
  // Only validate props or state classes
  assert(isAPropsOrStateClass(classNode));

  final superClass = classNode.extendsClause?.superclass?.name?.name;

  if (superClass == null || !extendsFromUiPropsOrUiState(classNode)) {
    return false;
  }
  if (classNode.withClause != null) return false;

  return true;
}

/// Detects if the Props or State class is considered advanced.
///
/// Related: [isSimplePropsOrStateClass]
bool isAdvancedPropsOrStateClass(ClassDeclaration classNode) {
  // Only validate props or state classes
  assert(isAPropsOrStateClass(classNode));

  return !isSimplePropsOrStateClass(classNode);
}

/// Returns the class/mixin that was converted in a previous migration
/// that has the same name as [className] when appended with "Mixin".
ClassOrMixinDeclaration getDupeClassInSameRoot(
    String className, CompilationUnit root) {
  final possibleDupeClassesInSameRoot =
      root.declarations.whereType<ClassOrMixinDeclaration>();
  for (var decl in possibleDupeClassesInSameRoot) {
    if (decl.name.name == '${className}Mixin') {
      return decl;
    }
  }

  return null;
}

/// Returns the name of a mixin that was converted in a previous migration
/// that has the same name as [className] when appended with "Mixin".
String getNameOfDupeClass(
    String className, CompilationUnit root, ClassToMixinConverter converter) {
  final possibleDupeClasses = converter.visitedClassNames.keys;
  String nameOfDupeClass;
  for (var possibleDupeClassName in possibleDupeClasses) {
    if (possibleDupeClassName == '${className}Mixin') {
      nameOfDupeClass = possibleDupeClassName;
      break;
    }
  }

  return nameOfDupeClass ?? getDupeClassInSameRoot(className, root)?.name?.name;
}

/// A class used to handle the conversion of props / state classes to mixins.
///
/// Should only be constructed once to initialize the value of [visitedClassNames].
///
/// Then [migrate] should be called on that instance each time a class is visited and needs to be converted to a mixin.
class ClassToMixinConverter {
  ClassToMixinConverter() : _visitedClassNames = <String, String>{};

  /// A map of props / state class names that have been visited in an attempt to [migrate].
  ///
  /// The keys represent the names of all classes that were visited in an attempt to migrate.
  ///
  /// * If the value is non-null, it represents the name of mixin that should be used moving forward.
  /// * If the value is null, the class was unable to be converted.
  Map<String, String> get visitedClassNames => _visitedClassNames;
  Map<String, String> _visitedClassNames;

  /// Whether the provided [className] was migrated as a result of [migrate] being called.
  bool classWasMigrated(String className) =>
      visitedClassNames[className] != null;

  /// Whether the provided [className] was migrated as a result of [migrate] being called.
  bool classWasVisited(String className) =>
      visitedClassNames.containsKey(className);

  /// Adds the name of the provided [node] as a key within [visitedClassNames] if it is a props or state class.
  void recordVisit(ClassDeclaration node) {
    if (!isAPropsOrStateClass(node)) return;

    _visitedClassNames.putIfAbsent(
        stripPrivateGeneratedPrefix(node.name.name), () => null);
  }

  /// Used to switch a props/state class, or a `@PropsMixin()`/`@StateMixin()` class to a mixin.
  ///
  /// __EXAMPLE (Concrete Class):__
  /// ```dart
  /// // Before
  /// class _$TestProps extends UiProps {
  ///   String var1;
  ///   int var2;
  /// }
  ///
  /// // After
  /// mixin TestPropsMixin on UiProps {
  ///   String var1;
  ///   int var2;
  /// }
  /// ```
  ///
  /// __EXAMPLE (`@PropsMixin`):__
  /// ```dart
  /// // Before
  /// @PropsMixin()
  /// abstract class TestPropsMixin implements UiProps, BarPropsMixin {
  ///   // To ensure the codemod regression checking works properly, please keep this
  ///   // field at the top of the class!
  ///   // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
  ///   static const PropsMeta meta = _$metaForTestPropsMixin;
  ///
  ///   @override
  ///   Map get props;
  ///
  ///   String var1;
  ///   String var2;
  /// }
  ///
  /// // After
  /// mixin TestPropsMixin on UiProps implements BarPropsMixin {
  ///   String var1;
  ///   String var2;
  /// }
  /// ```
  ///
  /// When a class is migrated, it gets added to [visitedClassNames]
  /// so that suggestors that come after the suggestor that called this function - can know
  /// whether to yield a patch based on that information.
  void migrate(
    ClassDeclaration node,
    YieldPatch yieldPatch, {
    bool shouldAddMixinToName = false,
    bool shouldSwapParentClass = false,
    bool convertClassesWithExternalSuperclass = false,
    SourceFile sourceFile,
  }) {
    // ---------------------------------------------------------------------------------------
    // [1] If we are migrating an advanced props class that extends from a superclass coming
    //     from an external lib, that means that:
    //
    //      1. The `AdvancedPropsAndStateClassMigrator` has already been run once, resulting in the
    //         "FIX ME" comment regarding the use of external superclasses / mixins being added to the class declaration.
    //      2. During this second run of the migrator, the consumer has
    //         set the `--convert-classes-with-external-superclasses` CLI flag.
    //      3. A new "FIX ME" comment will be added to the concrete class via `AdvancedPropsAndStateClassMigrator`
    //         which will include instructions on how to complete the migration by replacing the deprecated
    //         external class / mixins.
    //      4. The "FIX ME" comment mentioned above in item 1 should now be removed since it will be positioned
    //         above the new mixin created by this `migrate` method - which will result in inaccurate instructions
    //         once the migration is completed.
    // ---------------------------------------------------------------------------------------

    final originalPublicClassName = stripPrivateGeneratedPrefix(node.name.name);
    final commentsToRemove = <String>[];

    final mixinNames = node.withClause?.mixinTypes
            ?.joinConvertedClassesByName(
                converter: this, sourceFile: sourceFile)
            ?.split(', ') ??
        [];
    final migratingAdvancedClassWithExternalMixins =
        convertClassesWithExternalSuperclass &&
            !mixinNames.every(classWasVisited);
    if (migratingAdvancedClassWithExternalMixins) {
      // ----- [1] ----- //
      commentsToRemove.add(getExternalSuperclassOrMixinReasonComment(
          originalPublicClassName, mixinNames,
          mixinsAreExternal: true));
    }

    final migratingAdvancedClassWithExternalSuperclass =
        shouldSwapParentClass && convertClassesWithExternalSuperclass;
    if (migratingAdvancedClassWithExternalSuperclass) {
      // ----- [1] ----- //
      commentsToRemove.add(getExternalSuperclassOrMixinReasonComment(
          originalPublicClassName, [node.extendsClause.superclass.name.name]));
    }

    if (commentsToRemove.isNotEmpty) {
      removeCommentFromNode(node, commentsToRemove.join('//\n'), yieldPatch);
    }

    if (shouldAddMixinToName) {
      // Check to make sure we're not creating a duplicate mixin
      final dupeClassName =
          getNameOfDupeClass(originalPublicClassName, node.root, this);
      if (dupeClassName != null || node.members.isEmpty) {
        // Delete the class since a mixin with the same name already exists,
        // or the class has no members of its own.
        yieldPatch(node.offset, node.end, '');
        _visitedClassNames[originalPublicClassName] = originalPublicClassName;
        return;
      }
    }

    if (node.abstractKeyword != null) {
      yieldPatch(node.abstractKeyword.offset, node.abstractKeyword.charEnd, '');
    }

    yieldPatch(node.classKeyword.offset, node.classKeyword.charEnd, 'mixin');

    var newMixinName = originalPublicClassName;

    if (node.extendsClause?.extendsKeyword != null) {
      // --- Convert concrete props/state class to a mixin --- //

      yieldPatch(node.name.token.offset,
          node.name.token.offset + privateGeneratedPrefix.length, '');

      yieldPatch(node.extendsClause.offset,
          node.extendsClause.extendsKeyword.charEnd, 'on');

      if (shouldAddMixinToName) {
        yieldPatch(node.name.token.charEnd, node.name.token.charEnd, 'Mixin');
        newMixinName = '${newMixinName}Mixin';
      }

      if (shouldSwapParentClass) {
        yieldPatch(
            node.extendsClause.superclass.name.offset,
            node.extendsClause.superclass.end,
            isAPropsClass(node) ? 'UiProps' : 'UiState');
      }

      if (node.withClause != null) {
        yieldPatch(node.withClause.offset, node.withClause.end, '');
      }
    } else {
      // --- Convert props/state mixin to an actual mixin --- //

      if (node.implementsClause?.implementsKeyword != null) {
        final nodeInterfaces = node.implementsClause.interfaces;
        // Implements an interface, and does not extend from another class
        if (implementsUiPropsOrUiState(node)) {
          if (nodeInterfaces.length == 1) {
            // Only implements UiProps / UiState
            yieldPatch(node.implementsClause.offset,
                node.implementsClause.implementsKeyword.charEnd, 'on');
          } else {
            // Implements UiProps / UiState along with other interfaces
            final uiInterface = nodeInterfaces.firstWhere((interface) =>
                interface.name.name == 'UiProps' ||
                interface.name.name == 'UiState');
            final otherInterfaces = List.of(nodeInterfaces)
              ..remove(uiInterface);

            yieldPatch(node.implementsClause.offset, node.implementsClause.end,
                'on ${uiInterface.name.name} implements ${otherInterfaces.joinConvertedClassesByName()}');
          }
        } else {
          // Does not implement UiProps / UiState
          final uiInterfaceStr = isAPropsMixin(node) ? 'UiProps' : 'UiState';

          if (nodeInterfaces.isNotEmpty) {
            // But does implement other stuff
            yieldPatch(node.implementsClause.offset, node.implementsClause.end,
                'on $uiInterfaceStr implements ${nodeInterfaces.joinConvertedClassesByName()}');
          }
        }
      } else {
        // Does not implement anything
        final uiInterfaceStr = isAPropsMixin(node) ? 'UiProps' : 'UiState';

        yieldPatch(
            node.name.token.end, node.name.token.end, ' on $uiInterfaceStr');
      }
    }

    _visitedClassNames[originalPublicClassName] = newMixinName;
  }

  @visibleForTesting
  void setVisitedClassNames(Map<String, String> mapOfConvertedClassNames) =>
      _visitedClassNames = mapOfConvertedClassNames;
}

/// Returns the name of the props class for a given [factoryDeclaration].
String getPropsClassNameFromFactoryDeclaration(
    TopLevelVariableDeclaration factoryDeclaration) {
  return factoryDeclaration.variables.type.childEntities
      .whereType<TypeArgumentList>()
      .firstOrNull
      ?.arguments
      ?.first
      ?.toSource();
}

/// Returns the name of the mixin that the [originalClassName] was converted to, or the [originalClassName]
/// if no matching key is found within [ClassToMixinConverter.visitedClassNames] on the provided [converter] instance.
String getConvertedClassMixinName(
    String originalClassName, ClassToMixinConverter converter) {
  const reservedBaseClassNames = {
    'FluxUiProps': 'FluxUiPropsMixin',
  };

  // If it is a "reserved" base class that the consumer doesn't control / won't be converted as
  // part of running the codemod in their repo, return the new "known" mixin name.
  if (reservedBaseClassNames.containsKey(originalClassName)) {
    return reservedBaseClassNames[originalClassName];
  }

  return converter.visitedClassNames[originalClassName] ?? originalClassName;
}

extension IterableAstUtils on Iterable<NamedType> {
  /// Utility to join an `Iterable` based on the `name` of the `name` field
  /// rather than the `toString()` of the object when the named type is:
  ///
  /// 1. A non-generated _(no `$` prefix)_ mixin / class
  /// 2. A generated mixin name that has not been converted by a migrator
  ///     * The `// ignore` comments will be preserved in this case
  String joinConvertedClassesByName({
    ClassToMixinConverter converter,
    SourceFile sourceFile,
    String separator,
    bool includeGenericParameters = true,
    bool includeComments = true,
    bool includePrivateGeneratedClassNames = true,
  }) {
    bool _mixinHasBeenConverted(NamedType t) =>
        converter.classWasMigrated(t.name.name.replaceFirst('\$', ''));

    bool _mixinNameIsOldGeneratedBoilerplate(NamedType t) =>
        t.name.name.startsWith('\$');

    String _typeArgs(NamedType t) =>
        includeGenericParameters ? '${t.typeArguments ?? ''}' : '';

    return where((t) {
      if (converter == null) return true;
      if (includePrivateGeneratedClassNames) {
        return !_mixinNameIsOldGeneratedBoilerplate(t) ||
            !_mixinHasBeenConverted(t);
      } else {
        return !_mixinNameIsOldGeneratedBoilerplate(t);
      }
    }).map((t) {
      if (converter != null &&
          sourceFile != null &&
          _mixinNameIsOldGeneratedBoilerplate(t) &&
          !_mixinHasBeenConverted(t)) {
        // Preserve ignore comments for generated, unconverted props mixins
        if (includeComments &&
            hasComment(
                t, sourceFile, 'ignore: mixin_of_non_class, undefined_class')) {
          return '// ignore: mixin_of_non_class, undefined_class\n${getConvertedClassMixinName(t.name.name, converter)}${_typeArgs(t)}';
        }
      }

      if (converter != null) {
        return '${getConvertedClassMixinName(t.name.name, converter)}${_typeArgs(t)}';
      }

      return '${t.name.name}${_typeArgs(t)}';
    }).join('${separator ?? ','} ');
  }
}

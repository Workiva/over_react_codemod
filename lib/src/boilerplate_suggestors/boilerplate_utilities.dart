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

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:meta/meta.dart';
import 'package:over_react_codemod/src/boilerplate_suggestors/migration_decision.dart';
import 'package:over_react_codemod/src/constants.dart';
import 'package:over_react_codemod/src/util.dart';
import 'package:source_span/source_span.dart';

typedef YieldPatch = void Function(
    int startingOffset, int endingOffset, String replacement);

const semverReportNotAvailable =
    'Semver report not available; this class is assumed to be public and thus will not be updated.';

/// Returns a [SemverHelper] using the file at [path].
///
/// If the file at [path] does not exist, the returned [SemverHelper] assumes
/// all classes passed to [getPublicExportLocations] are public
/// (see: [SemverHelper.alwaysPublic] constructor).
///
/// If [shouldTreatAllComponentsAsPrivate] is true, the returned [SemverHelper]
/// assumes all classes passed to [getPublicExportLocations] are private
/// (see: [SemverHelper.alwaysPrivate] constructor).
SemverHelper getSemverHelper(String path,
    {bool shouldTreatAllComponentsAsPrivate = false}) {
  if (shouldTreatAllComponentsAsPrivate) {
    return SemverHelper.alwaysPrivate();
  } else {
    final file = File(path);
    String warning;

    if (file.existsSync()) {
      try {
        final jsonReport = jsonDecode(file.readAsStringSync());
        if (jsonReport['exports'] != null) {
          return SemverHelper(jsonReport['exports']);
        }
        warning = 'Could not find exports list in semver_report.json.';
      } catch (e) {
        warning = 'Could not parse semver_report.json.';
      }
    } else {
      warning = 'Could not find semver_report.json.';
    }
    return SemverHelper.alwaysPublic(warning);
  }
}

/// Returns whether or not [node] is publicly exported.
bool isPublic(
  ClassDeclaration node,
  SemverHelper semverHelper,
  Uri sourceFileUrl,
) {
  assert(semverHelper != null);
  return semverHelper.getPublicExportLocations(node, sourceFileUrl).isNotEmpty;
}

class SemverHelper {
  final Map _exportList;
  final bool _isAlwaysPrivate;

  /// A warning message if semver report cannot be found.
  String warning;

  SemverHelper(this._exportList) : _isAlwaysPrivate = false;

  /// Used to ensure [getPublicExportLocations] always returns an empty list,
  /// treating all components as private.
  SemverHelper.alwaysPrivate()
      : _exportList = null,
        _isAlwaysPrivate = true;

  /// Used to ensure [getPublicExportLocations] always returns a non-empty list,
  /// treating all components as public.
  SemverHelper.alwaysPublic(this.warning)
      : _exportList = null,
        _isAlwaysPrivate = false;

  /// Returns a list of locations where [node] is publicly exported.
  ///
  /// If [node] is not publicly exported, returns an empty list.
  List<String> getPublicExportLocations(
    ClassDeclaration node,
    Uri sourceFileUrl,
  ) {
    final className = stripPrivateGeneratedPrefix(node.name.name);
    final locations = <String>[];

    if (!sourceFileUrl.toString().startsWith('lib/')) {
      // The member is not inside of lib/ - so its inherently private.
      return locations;
    }

    if (_exportList == null && _isAlwaysPrivate) return locations;
    if (_exportList == null && !_isAlwaysPrivate) {
      return [semverReportNotAvailable];
    }

    _exportList.forEach((key, value) {
      if (value['type'] == 'class' && value['grammar']['name'] == className) {
        locations.add(key);
      }
    });

    return locations;
  }
}

/// Returns the annotation node associated with the provided [classNode]
/// that matches the provided [annotationName], if one exists.
AstNode getAnnotationNode(ClassDeclaration classNode, String annotationName) {
  return classNode.metadata.firstWhere(
      (node) => node.name.name == annotationName,
      orElse: () => null);
}

/// A map with keys of "reserved" base props/state class names, and values of the
/// analogous mixin that the migrator(s) can assume will exist - even if the
/// base class is never visited by them.
const reservedBaseClassNames = {
  'FluxUiProps': 'FluxUiPropsMixin',
  'DomPropsMixin': 'DomPropsMixin',
  'ConnectPropsMixin': 'ConnectPropsMixin',
};

/// Returns whether the provided [className] is considered a "reserved" (non-custom) base class name to extend from or implement.
bool isReservedBaseClass(String className) {
  return ['UiProps', 'UiState', ...reservedBaseClassNames.keys]
      .contains(className);
}

/// Returns whether the [classNode] should be considered "abstract" based on either
/// the presence of the `abstract` keyword, and `Abstract`- annotations.
bool isAbstract(ClassDeclaration classNode) =>
    classNode.isAbstract ||
    getAnnotationNode(classNode, 'AbstractComponent') != null ||
    getAnnotationNode(classNode, 'AbstractComponent2') != null ||
    getAnnotationNode(classNode, 'AbstractProps') != null ||
    getAnnotationNode(classNode, 'AbstractState') != null;

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

/// Returns whether a props or state mixin class [classNode] should be migrated as part of the boilerplate codemod.
bool shouldMigratePropsAndStateMixin(ClassDeclaration classNode) =>
    isAPropsOrStateMixin(classNode);

/// Returns whether a props or state class class [node] should be migrated as part of the boilerplate codemod.
MigrationDecision getPropsAndStateClassMigrationDecision(
    ClassDeclaration node, SemverHelper semverHelper, SourceFile sourceFile) {
  final publicNodeName = stripPrivateGeneratedPrefix(node.name.name);
  if (!isAPropsOrStateClass(node)) {
    return MigrationDecision(false);
  } else if (isPublic(node, semverHelper, sourceFile.url)) {
    final publicExportLocations =
        semverHelper.getPublicExportLocations(node, sourceFile.url);
    return MigrationDecision(false,
        reason:
            getPublicApiReasonComment(publicNodeName, publicExportLocations));
  } else if (!isAssociatedWithComponent2(node)) {
    if (getComponentNodeInRoot(node)?.name?.name == null) {
      return MigrationDecision(false);
    }

    return MigrationDecision(false,
        reason: getNonComponent2ReasonComment(
            publicNodeName, getComponentNodeInRoot(node).name.name));
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
  final possibleDupeClasses = converter.visitedNames.keys;
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
/// Should only be constructed once to initialize the value of [visitedNames].
///
/// Then [migrate] should be called on that instance each time a class is visited and needs to be converted to a mixin.
class ClassToMixinConverter {
  ClassToMixinConverter() : _visitedNames = <String, String>{};

  /// A map of props / state class or mixin names that have been visited in an attempt to [migrate].
  ///
  /// The keys represent the names of all classes / mixins that were visited in an attempt to migrate.
  ///
  /// * If the value is non-null, it represents the name of the mixin that was created.
  /// * If the value is null, the class was unable to be converted.
  ///
  /// > Instead of trying to parse the keys / values for semantic meaning,
  ///   it is strongly recommended that you utilize helper methods like
  ///   [wasVisited], [wasMigrated] and [isBoilerplateCompatible] instead.
  @visibleForTesting
  Map<String, String> get visitedNames => _visitedNames;
  Map<String, String> _visitedNames;

  /// Returns whether the provided [classOrMixinName] was either created or migrated
  /// as a result of [migrate] being called.
  ///
  /// A true return value indicates that the [classOrMixinName] is
  /// compatible with the new over_react boilerplate.
  bool isBoilerplateCompatible(String classOrMixinName) =>
      visitedNames.containsValue(classOrMixinName) ||
      wasMigrated(classOrMixinName);

  /// Returns whether the provided [classOrMixinName] was migrated as a result of [migrate] being called.
  ///
  /// Returns true if:
  ///
  /// 1. A new mixin was created from the [classOrMixinName], while leaving the [classOrMixinName]
  ///    in place as a result of advanced inheritance.
  /// 2. The [classOrMixinName] was a [ClassDeclaration], and it was converted into a [MixinDeclaration]
  ///    as a result of simple inheritance.
  bool wasMigrated(String classOrMixinName) =>
      visitedNames[classOrMixinName] != null;

  /// Returns whether the provided [classOrMixinName] was migrated as a result of [migrate] being called.
  bool wasVisited(String classOrMixinName) =>
      visitedNames.containsKey(classOrMixinName);

  /// Adds the name of the provided [node] as a key within [visitedNames] if
  /// it is a props/state class, or a props/state mixin.
  ///
  /// > NOTE: The key will be the name of the [node] with the [privateGeneratedPrefix] removed.
  void recordVisit(ClassOrMixinDeclaration node) {
    if (!(isAPropsOrStateClass(node) || isAPropsOrStateMixin(node))) return;

    _visitedNames.putIfAbsent(
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
  /// When a class is migrated, it gets added to [visitedNames]
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

    final migratingAdvancedClassWithExternalSuperclass =
        shouldSwapParentClass && convertClassesWithExternalSuperclass;
    if (migratingAdvancedClassWithExternalSuperclass) {
      // ----- [1] ----- //
      commentsToRemove.add(getExternalSuperclassReasonComment(
          originalPublicClassName, node.extendsClause.superclass.name.name));
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

        // If a class extends from UiProps/UiState and uses a single mixin that has a name
        // that matches the concrete class name appended with `Mixin`,
        // the advanced props/state migrator will not create a new concrete class declaration
        // since the "shorthand" / "mixin only" boilerplate will suffice.
        if (!shouldSwapParentClass &&
            dupeClassName != null &&
            node.withClause?.mixinTypes?.length == 1 &&
            node.implementsClause == null) {
          _visitedNames[originalPublicClassName] =
              '${originalPublicClassName}Mixin';
        } else {
          _visitedNames[originalPublicClassName] = originalPublicClassName;
        }
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

      if (node.name.name.startsWith(privateGeneratedPrefix)) {
        yieldPatch(node.name.token.offset,
            node.name.token.offset + privateGeneratedPrefix.length, '');
      }

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

    _visitedNames[originalPublicClassName] = newMixinName;
  }

  @visibleForTesting
  void setVisitedNames(Map<String, String> mapOfMigratedNames) =>
      _visitedNames = mapOfMigratedNames;
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
/// if no matching key is found within [ClassToMixinConverter.visitedNames] on the provided [converter] instance.
String getConvertedClassMixinName(
    String originalClassName, ClassToMixinConverter converter) {
  // If it is a "reserved" base class that the consumer doesn't control / won't be converted as
  // part of running the codemod in their repo, return the new "known" mixin name.
  if (reservedBaseClassNames.containsKey(originalClassName)) {
    return reservedBaseClassNames[originalClassName];
  }

  return converter.visitedNames[originalClassName] ?? originalClassName;
}

extension IterableAstUtils on Iterable<NamedType> {
  List<String> getConvertedClassesByName({
    ClassToMixinConverter converter,
    SourceFile sourceFile,
    bool includeGenericParameters = true,
    bool includeComments = true,
    bool includePrivateGeneratedClassNames = true,
  }) {
    bool _mixinNameIsOldGeneratedBoilerplate(NamedType t) =>
        t.name.name.startsWith('\$');

    String _typeArgs(NamedType t) =>
        includeGenericParameters ? '${t.typeArguments ?? ''}' : '';

    return where((t) {
      if (converter == null) return true;
      if (includePrivateGeneratedClassNames) {
        return !_mixinNameIsOldGeneratedBoilerplate(t);
      } else {
        return !_mixinNameIsOldGeneratedBoilerplate(t);
      }
    }).map((t) {
      if (converter != null) {
        return '${getConvertedClassMixinName(t.name.name, converter)}${_typeArgs(t)}';
      }

      return '${t.name.name}${_typeArgs(t)}';
    }).toList();
  }

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
    return getConvertedClassesByName(
      converter: converter,
      sourceFile: sourceFile,
      includeGenericParameters: includeGenericParameters,
      includeComments: includeComments,
      includePrivateGeneratedClassNames: includePrivateGeneratedClassNames,
    ).join('${separator ?? ','} ');
  }
}

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
import 'package:analyzer/dart/ast/token.dart';
import 'package:meta/meta.dart';
import 'package:over_react_codemod/src/react16_suggestors/react16_utilities.dart';
import 'package:over_react_codemod/src/util.dart';
import 'package:source_span/source_span.dart';

import 'boilerplate_constants.dart';

typedef YieldPatch = void Function(
    int startingOffset, int endingOffset, String replacement);

/// Returns a [SemverHelper] using the file at [path].
///
/// If the file at [path] does not exist, the returned [SemverHelper] assumes
/// all classes passed to [getPublicExportLocations] are public
/// (see: [SemverHelper.alwaysPublic] constructor).
///
/// If [shouldTreatAllComponentsAsPrivate] is true, the returned [SemverHelper]
/// assumes all classes passed to [getPublicExportLocations] are private
/// (see: [SemverHelper.alwaysPrivate] constructor).
Future<SemverHelper> getSemverHelper(String path,
    {bool shouldTreatAllComponentsAsPrivate = false}) async {
  if (shouldTreatAllComponentsAsPrivate) {
    return SemverHelper.alwaysPrivate();
  } else {
    final file = File(path);

    if (await file.exists()) {
      return SemverHelper(jsonDecode(await file.readAsString()));
    } else {
      return SemverHelper.alwaysPublic();
    }
  }
}

/// Returns whether or not [node] is publicly exported.
bool isPublic(ClassDeclaration node, SemverHelper semverHelper) {
  assert(semverHelper != null);
  return semverHelper.getPublicExportLocations(node).isNotEmpty;
}

class SemverHelper {
  final Map _exportList;
  final bool _isAlwaysPrivate;

  SemverHelper(Map jsonReport)
      : _exportList = jsonReport['exports'],
        assert(jsonReport['exports'] != null),
        _isAlwaysPrivate = false;

  /// Used to ensure [getPublicExportLocations] always returns an empty list,
  /// treating all components as private.
  SemverHelper.alwaysPrivate()
      : _exportList = null,
        _isAlwaysPrivate = true;

  /// Used to ensure [getPublicExportLocations] always returns a non-empty list,
  /// treating all components as public.
  SemverHelper.alwaysPublic()
      : _exportList = null,
        _isAlwaysPrivate = false;

  /// Returns a list of locations where [node] is publicly exported.
  ///
  /// If [node] is not publicly exported, returns an empty list.
  List<String> getPublicExportLocations(ClassDeclaration node) {
    final className = node.name.name;
    final List<String> locations = List();

    if (_exportList == null && _isAlwaysPrivate) return locations;
    if (_exportList == null && !_isAlwaysPrivate) {
      return [reportNotAvailableComment];
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
bool shouldMigratePropsAndStateClass(
    ClassDeclaration node, SemverHelper semverHelper) {
  return isAssociatedWithComponent2(node) &&
      isAPropsOrStateClass(node) &&
      !isPublic(node, semverHelper);
}

/// Whether a comment should be added explaining that [node] was not updated because it is publicly exported.
bool shouldAddPublicExportLocationsComment(
    ClassDeclaration node, SemverHelper semverHelper) {
  return isAssociatedWithComponent2(node) &&
      isAPropsOrStateClass(node) &&
      isPublic(node, semverHelper);
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

  if (superClass == null ||
      superClass != 'UiProps' && superClass != 'UiState') {
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
  final possibleDupeClasses = converter.convertedClassNames.keys;
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
/// Should only be constructed once to initialize the value of [convertedClassNames].
///
/// Then [migrate] should be called on that instance each time a class is visited and needs to be converted to a mixin.
class ClassToMixinConverter {
  ClassToMixinConverter() : _convertedClassNames = <String, String>{};

  /// A map of props / state classes that have been migrated to the new boilerplate via [migrate].
  ///
  /// The keys of the map are the original class names, with the values representing the new mixin names.
  Map<String, String> get convertedClassNames => _convertedClassNames;
  Map<String, String> _convertedClassNames;

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
  /// When a class is migrated, it gets added to [convertedClassNames]
  /// so that suggestors that come after the suggestor that called this function - can know
  /// whether to yield a patch based on that information.
  void migrate(ClassDeclaration node, YieldPatch yieldPatch,
      {bool shouldAddMixinToName = false,
      bool shouldSwapParentClass = false,
      SourceFile sourceFile}) {
    final originalPublicClassName = stripPrivateGeneratedPrefix(node.name.name);

    if (shouldAddMixinToName) {
      // Check to make sure we're not creating a duplicate mixin
      final dupeClassName =
          getNameOfDupeClass(originalPublicClassName, node.root, this);
      if (dupeClassName != null || node.members.isEmpty) {
        // Delete the class since a mixin with the same name already exists,
        // or the class has no members of its own.
        yieldPatch(node.offset, node.end, '');
        convertedClassNames[originalPublicClassName] = originalPublicClassName;
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

      if (node.name.name != newMixinName) {
        yieldPatch(node.name.token.offset, node.name.token.end, newMixinName);
      }

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

    convertedClassNames[originalPublicClassName] = newMixinName;
  }

  @visibleForTesting
  void setConvertedClassNames(Map<String, String> mapOfConvertedClassNames) =>
      _convertedClassNames = mapOfConvertedClassNames;
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
/// if no matching key is found within [ClassToMixinConverter.convertedClassNames] on the provided [converter] instance.
String getConvertedClassMixinName(
    String originalClassName, ClassToMixinConverter converter) {
  const reservedBaseClassNames = {
    'FluxUiProps': 'FluxUiPropsMixin',
    'BuiltReduxUiProps': 'BuiltReduxUiPropsMixin',
  };

  // If it is a "reserved" base class that the consumer doesn't control / won't be converted as
  // part of running the codemod in their repo, return the new "known" mixin name.
  if (reservedBaseClassNames.containsKey(originalClassName)) {
    return reservedBaseClassNames[originalClassName];
  }

  return converter.convertedClassNames[originalClassName] ?? originalClassName;
}

extension IterableAstUtils on Iterable<NamedType> {
  /// Utility to join an `Iterable` based on the `name` of the `name` field
  /// rather than the `toString()` of the object when the named type is:
  ///
  /// 1. A non-generated _(no `$` prefix)_ mixin / class
  /// 2. A generated mixin name that has not been converted by a migrator
  ///     * The `// ignore` comments will be preserved in this case
  String joinConvertedClassesByName(
      {ClassToMixinConverter converter,
      SourceFile sourceFile,
      String separator}) {
    bool _mixinHasBeenConverted(NamedType t) => converter.convertedClassNames
        .containsKey(t.name.name.replaceFirst('\$', ''));

    bool _mixinNameIsOldGeneratedBoilerplate(NamedType t) =>
        t.name.name.startsWith('\$');

    String _typeArgs(NamedType t) => '${t.typeArguments ?? ''}';

    return where((t) {
      if (converter == null) return true;
      return !_mixinNameIsOldGeneratedBoilerplate(t) ||
          !_mixinHasBeenConverted(t);
    }).map((t) {
      if (converter != null &&
          sourceFile != null &&
          _mixinNameIsOldGeneratedBoilerplate(t) &&
          !_mixinHasBeenConverted(t)) {
        // Preserve ignore comments for generated, unconverted props mixins
        if (hasComment(
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

/// Adds [publicExportLocationsComment] to [classNode] or updates an existing comment.
void addPublicExportLocationsComment(ClassDeclaration classNode,
    SourceFile sourceFile, SemverHelper semverHelper, YieldPatch yieldPatch) {
  final existingReportUnavailableCommentToken =
      getComment(classNode, sourceFile, reportNotAvailableComment, yieldPatch);
  final existingExportLocationsCommentToken =
      getComment(classNode, sourceFile, classNotUpdatedComment, yieldPatch);
  final exportLocationsComment =
      publicExportLocationsComment(classNode, semverHelper);

  if (hasComment(classNode, sourceFile, exportLocationsComment)) return;

  if (existingReportUnavailableCommentToken != null) {
    // Replace existing semver report unavailable with new comment.
    yieldPatch(
      existingReportUnavailableCommentToken.offset,
      existingReportUnavailableCommentToken.end,
      exportLocationsComment,
    );
  } else if (existingExportLocationsCommentToken != null) {
    // Replace public export locations comment with new comment.
    yieldPatch(
      existingExportLocationsCommentToken.offset,
      existingExportLocationsCommentToken.end,
      exportLocationsComment,
    );
  } else {
    // Add public export locations comment.
    yieldPatch(
      classNode.offset,
      classNode.offset,
      publicExportLocationsComment(classNode, semverHelper) + '\n',
    );
  }
}

/// Removes [publicExportLocationsComment] from [classNode].
void removePublicExportLocationsComment(ClassDeclaration classNode,
    SourceFile sourceFile, SemverHelper semverHelper, YieldPatch yieldPatch) {
  final existingReportUnavailableCommentToken =
      getComment(classNode, sourceFile, reportNotAvailableComment, yieldPatch);
  final existingExportLocationsCommentToken =
      getComment(classNode, sourceFile, classNotUpdatedComment, yieldPatch);

  // Remove semver report unavailable comment.
  if (existingReportUnavailableCommentToken != null) {
    yieldPatch(
      existingReportUnavailableCommentToken.offset,
      existingReportUnavailableCommentToken.end,
      '',
    );
  }

  // Remove public export locations comment.
  if (existingExportLocationsCommentToken != null) {
    yieldPatch(
      existingExportLocationsCommentToken.offset,
      existingExportLocationsCommentToken.end,
      '',
    );
  }
}

/// Returns AST token for [commentToGet] from the comments above [node].
///
/// If [commentToGet] does not exist above [node], returns null.
Token getComment(AstNode node, SourceFile sourceFile, String commentToGet,
    YieldPatch yieldPatch) {
  final line = sourceFile.getLine(node.offset);

  // Find the comment associated with this line.
  String commentText;
  for (var comment in allComments(node.root.beginToken)) {
    final commentLine = sourceFile.getLine(comment.end);
    if (commentLine == line ||
        commentLine == line + 1 ||
        commentLine == line - 1) {
      commentText = sourceFile.getText(comment.offset, comment.end);
      if (commentText.contains(commentToGet)) return comment;
      break;
    }
  }
  return null;
}

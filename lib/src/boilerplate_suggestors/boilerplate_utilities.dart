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
import 'package:over_react_codemod/src/constants.dart';
import 'package:over_react_codemod/src/util.dart';

import '../util.dart';

typedef YieldPatch = void Function(
    int startingOffset, int endingOffset, String replacement);

// Stub while <https://jira.atl.workiva.net/browse/CPLAT-9308> is in progress
bool _isPublic(ClassDeclaration node) => false;

/// Whether a props or state class class [node] should be migrated as part of the boilerplate codemod.
bool shouldMigratePropsAndStateClass(ClassDeclaration node) {
  return isAssociatedWithComponent2(node) &&
      isAPropsOrStateClass(node) &&
      // Stub while <https://jira.atl.workiva.net/browse/CPLAT-9308> is in progress
      !_isPublic(node);
}

/// A simple RegExp against the parent of the class to verify it is `UiProps`
/// or `UiState`.
bool extendsFromUiPropsOrUiState(ClassDeclaration classNode) =>
    classNode.extendsClause.superclass.name
        .toSource()
        .contains(RegExp('(UiProps)|(UiState)'));

/// A simple RegExp against the name of the class to verify it contains `props`
/// or `state`.
bool isAPropsOrStateClass(ClassDeclaration classNode) => classNode.name
    .toSource()
    .contains(RegExp('([A-Za-z]+Props)|([A-Za-z]+State)'));

/// Detects if the Props or State class is considered simple.
///
/// Simple means:
/// - Has no mixins
/// - Extends from UiProps
bool isSimplePropsOrStateClass(ClassDeclaration classNode) {
  // Only validate props or state classes
  assert(isAPropsOrStateClass(classNode));

  final superClass = classNode.extendsClause.superclass.name.toSource();

  if (superClass != 'UiProps' && superClass != 'UiState') return false;
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

/// A map of props / state classes that have been migrated to the new boilerplate
/// via [migrateClassToMixin].
var propsAndStateClassNamesConvertedToNewBoilerplate =
    < /*old class name*/ String, /*new mixin name*/ String>{};

/// Used to switch a props or state class to a mixin.
///
/// __EXAMPLE:__
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
/// When a class is migrated, it gets added to [propsAndStateClassNamesConvertedToNewBoilerplate]
/// so that suggestors that come after the suggestor that called this function - can know
/// whether to yield a patch based on that information.
void migrateClassToMixin(ClassDeclaration node, YieldPatch yieldPatch,
    {bool shouldAddMixinToName = false, bool shouldSwapParentClass = false}) {
  if (node.abstractKeyword != null) {
    yieldPatch(node.abstractKeyword.offset, node.abstractKeyword.charEnd, '');
  }

  yieldPatch(node.classKeyword.offset, node.classKeyword.charEnd, 'mixin');

  final originalPublicClassName =
      stripPrivateGeneratedPrefix(node.name.toSource());
  String newMixinName = originalPublicClassName;

  yieldPatch(node.name.token.offset,
      node.name.token.offset + privateGeneratedPrefix.length, '');

  yieldPatch(node.extendsClause.offset,
      node.extendsClause.extendsKeyword.charEnd, 'on');

  if (shouldAddMixinToName) {
    yieldPatch(node.name.token.charEnd, node.name.token.charEnd, 'Mixin');
    newMixinName = '${newMixinName}Mixin';
  }

  if (shouldSwapParentClass) {
    final isAPropsClass = node.name.toSource().contains('Props');
    yieldPatch(
        node.extendsClause.superclass.name.offset,
        node.extendsClause.superclass.name.end,
        isAPropsClass ? 'UiProps' : 'UiState');
  }

  if (node.withClause != null) {
    yieldPatch(node.withClause.offset, node.withClause.end, '');
  }

  propsAndStateClassNamesConvertedToNewBoilerplate[originalPublicClassName] =
      newMixinName;
}

extension IterableAstUtils on Iterable<NamedType> {
  /// Utility to join an `Iterable` based on the `toSource()` of the `name` field
  /// rather than the `toString()` of the object.
  String joinWithToSource({String startingString, String endingString}) {
    var string = '${startingString.trimRight()} ' ?? '';

    forEach((e) {
      final isTheLastItem = last.name.toSource() == e.name.toSource();

      string += '${e.name.toSource()}${isTheLastItem ? '' : ', '}';
    });

    string += endingString ?? '';

    return string;
  }
}

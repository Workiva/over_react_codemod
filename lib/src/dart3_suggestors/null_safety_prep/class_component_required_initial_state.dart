// Adapted from the missing_required_prop diagnostic in over_react/analyzer_plugin
// Permalink: https://github.com/Workiva/over_react/blob/ae8c898650537e49f35f98ad1b065c516207838e/tools/analyzer_plugin/lib/src/util/prop_declarations/defaulted_props.dart

// Copyright 2024 Workiva Inc.
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

import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:over_react_codemod/src/util/get_all_state.dart';
import 'package:pub_semver/pub_semver.dart';

import 'utils/class_component_required_fields.dart';

/// Suggestor to assist with preparations for null-safety by adding
/// "requiredness" (`late`) / nullability (`?`/`!`) hints to state field types
/// based on their access within a class component's `initialState`.
///
/// If a piece of state is initialized to a non-null value within `initialState`,
/// the corresponding declaration will gain a `/*late*/` modifier hint to
/// the left of the type, and a non-nullable type hint (`/*!*/`) to the right of
/// the type to assist the `nnbd_migration:migrate` script when it attempts to
/// infer a state field's nullability.
///
/// **Optionally**, an [sdkVersion] can be passed to the constructor.
/// When set to a version that opts-in to Dart's null safety feature,
/// the `late` / `?` type modifiers will be actual modifiers rather
/// than commented hints. This should only be done using an explicit opt-in
/// flag from the executable as most consumers that have migrated to null-safety
/// will have already run this script prior to the null safety migration and thus
/// the `/*late*/` / `/*?*/` hints will already be converted to actual modifiers.
///
/// **Before**
/// ```dart
/// mixin FooState on UiState {
///   String defaultedNullable;
///   num defaultedNonNullable;
/// }
/// class FooComponent extends UiStatefulComponent2<FooProps> {
///   @override
///   get initialState => (newState()
///     ..defaultedNullable = null
///     ..defaultedNonNullable = 2.1
///   );
///
///   // ...
/// }
/// ```
///
/// **After**
/// ```dart
/// mixin FooState on UiState {
///   /*late*/ String/*?*/ defaultedNullable;
///   /*late*/ num/*!*/ defaultedNonNullable;
/// }
/// class FooComponent extends UiStatefulComponent2<FooProps> {
///   @override
///   get initialState => (newState()
///     ..defaultedNullable = null
///     ..defaultedNonNullable = 2.1
///   );
///
///   // ...
/// }
/// ```
class ClassComponentRequiredInitialStateMigrator
    extends ClassComponentRequiredFieldsMigrator<StateAssignment> {
  ClassComponentRequiredInitialStateMigrator([Version? sdkVersion])
      : super('initialState', 'getInitialState', sdkVersion);

  @override
  Future<void> visitCascadeExpression(CascadeExpression node) async {
    super.visitCascadeExpression(node);

    final isInitialState = [relevantGetterName, relevantMethodName].contains(
        node.thisOrAncestorOfType<MethodDeclaration>()?.declaredElement?.name);

    // If this cascade is not assigning values to defaultProps, bail.
    if (!isInitialState) return;

    final cascadedInitialState = node.cascadeSections
        .whereType<AssignmentExpression>()
        .where((assignment) => assignment.leftHandSide is PropertyAccess)
        .map((assignment) => StateAssignment(assignment))
        .where((prop) => prop.node.writeElement?.displayName != null);

    patchFieldDeclarations(getAllState, cascadedInitialState, node);
  }
}

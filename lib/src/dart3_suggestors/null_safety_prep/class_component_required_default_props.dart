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

import 'package:over_react_codemod/src/util.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:over_react_codemod/src/util/get_all_props.dart';
import 'package:pub_semver/pub_semver.dart';

import 'utils/class_component_required_fields.dart';

/// Suggestor to assist with preparations for null-safety by adding
/// "requiredness" (`late`) / nullability (`?`/`!`) hints to prop types
/// based on their access within a class component's `defaultProps`.
///
/// If a prop is defaulted to a non-null value within `defaultProps`, the
/// corresponding prop declaration will gain a `/*late*/` modifier hint to the
/// left of the type, and a non-nullable type hint (`/*!*/`) to the right of
/// the type to assist the `nnbd_migration:migrate` script when it attempts to
/// infer a prop's nullability.
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
/// mixin FooProps on UiProps {
///   String defaultedNullable;
///   num defaultedNonNullable;
/// }
/// class FooComponent extends UiComponent2<FooProps> {
///   @override
///   get defaultProps => (newProps()
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
/// mixin FooProps on UiProps {
///   /*late*/ String/*?*/ defaultedNullable;
///   /*late*/ num/*!*/ defaultedNonNullable;
/// }
/// class FooComponent extends UiComponent2<FooProps> {
///   @override
///   get defaultProps => (newProps()
///     ..defaultedNullable = null
///     ..defaultedNonNullable = 2.1
///   );
///
///   // ...
/// }
/// ```
class ClassComponentRequiredDefaultPropsMigrator
    extends ClassComponentRequiredFieldsMigrator<PropAssignment> {
  ClassComponentRequiredDefaultPropsMigrator([Version? sdkVersion])
      : super('defaultProps', 'getDefaultProps', sdkVersion);

  @override
  Future<void> visitCascadeExpression(CascadeExpression node) async {
    super.visitCascadeExpression(node);

    final isDefaultProps = node.ancestors.any((ancestor) {
      if (ancestor is MethodDeclaration) {
        return [relevantGetterName, relevantMethodName]
            .contains(ancestor.declaredElement?.name);
      }
      if (ancestor is VariableDeclaration &&
          (ancestor.parentFieldDeclaration?.isStatic ?? false)) {
        return RegExp('$relevantGetterName', caseSensitive: false)
            .hasMatch(ancestor.name.lexeme);
      }
      return false;
    });

    // If this cascade is not assigning values to defaultProps, bail.
    if (!isDefaultProps) return;

    final cascadedDefaultProps = node.cascadeSections
        .whereType<AssignmentExpression>()
        .where((assignment) => assignment.leftHandSide is PropertyAccess)
        .map((assignment) => PropAssignment(assignment))
        .where((prop) => prop.node.writeElement?.displayName != null);

    patchFieldDeclarations(getAllProps, cascadedDefaultProps, node);
  }
}

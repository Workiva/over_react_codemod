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

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:collection/collection.dart';
import 'package:over_react_codemod/src/dart3_suggestors/null_safety_prep/utils/hint_detection.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:over_react_codemod/src/util/get_all_props.dart';
import 'package:pub_semver/pub_semver.dart';

import '../../util.dart';
import '../../util/class_suggestor.dart';
import 'analyzer_plugin_utils.dart';

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
class ClassComponentRequiredDefaultPropsMigrator extends RecursiveAstVisitor<void>
    with ClassSuggestor {
  final sdkVersion;

  ClassComponentRequiredDefaultPropsMigrator([this.sdkVersion]);

  final Set<DefaultedPropDeclaration> defaultedPropData = {};
  late ResolvedUnitResult result;

  @override
  Future<void> visitCascadeExpression(CascadeExpression node) async {
    super.visitCascadeExpression(node);

    final isDefaultProps = ['defaultProps', 'getDefaultProps']
        .contains(node.thisOrAncestorOfType<MethodDeclaration>()?.declaredElement?.name);

    if (!isDefaultProps) return;

    final cascadedDefaultProps = node.cascadeSections
        .whereType<AssignmentExpression>()
        .where((assignment) => assignment.leftHandSide is PropertyAccess)
        .map((assignment) => PropAssignment(assignment))
        .where((prop) => prop.node.writeElement?.displayName != null);

    for (final prop in cascadedDefaultProps) {
      final fieldEl = (prop.node.writeElement! as PropertyAccessorElement).variable as FieldElement;
      // Short circuit before looking up the variable if we've already added it
      if (defaultedPropData.map((data) => data.id).contains(fieldEl.id)) continue;
      final propsElement = node.staticType.tryCast<InterfaceType>()?.element;
      if (propsElement == null) continue;
      // For component1 boilerplate its possible that `fieldEl` won't be found using `lookUpVariable` below
      // since its `enclosingElement` will be the generated abstract mixin. So we'll use `getAllProps` and
      // cross reference the return value with the name of the `fieldEl` above to locate the actual prop
      // declaration we want to patch.
      final allProps = getAllProps(propsElement);
      final matchingProp = allProps.singleWhereOrNull((element) => element.name == fieldEl.name);
      if (matchingProp == null) continue;

      // NOTE: result.unit will only work if the declaration of the field is in this file
      final fieldDeclaration = lookUpVariable(matchingProp, result.unit);
      final isDefaultedToNull = prop.node.rightHandSide.staticType!.isDartCoreNull;

      // The `fieldEl.id` value is used for custom equality so that the `defaultedPropData` set only contains unique declarations.
      defaultedPropData.add(DefaultedPropDeclaration(fieldEl.id, fieldDeclaration, isDefaultedToNull));
    }

    defaultedPropData.where((data) => !data.patchedDeclaration).forEach((data) {
      data.patch(yieldPatch, sdkVersion: sdkVersion);
    });
  }

  @override
  Future<void> generatePatches() async {
    final r = await context.getResolvedUnit();
    if (r == null) {
      throw Exception(
          'Could not get resolved result for "${context.relativePath}"');
    }
    result = r;
    final compilationUnit = r.unit;

    final defaultPropsAccessors = <PropertyAccessorElement>[];
    final getDefaultPropsMethods = <MethodElement>[];
    compilationUnit.declaredElement!.classes.forEach((c) {
      defaultPropsAccessors.addAll(c.accessors.where((a) => a.name == 'defaultProps'));
      getDefaultPropsMethods.addAll(c.methods.where((m) => m.name == 'getDefaultProps'));
    });

    // Short-circuit if there are no default props set in this unit
    if (defaultPropsAccessors.isNotEmpty || getDefaultPropsMethods.isNotEmpty) {
      r.unit.accept(this);
    }
  }
}

class DefaultedPropDeclaration {
  final int id;
  final VariableDeclaration? fieldDecl;
  final bool isDefaultedToNull;
  final String name;

  DefaultedPropDeclaration(this.id, this.fieldDecl, this.isDefaultedToNull)
      : _patchedDeclaration = false,
        name = '${fieldDecl?.name.value()}';

  /// Whether the declaration has been patched with the late / nullable hints.
  bool get patchedDeclaration => _patchedDeclaration;
  bool _patchedDeclaration;

  void patch(void Function(String updatedText, int startOffset, [int? endOffset]) handleYieldPatch, {Version? sdkVersion}) {
    if (fieldDecl == null) return;
    final type = (fieldDecl!.parent! as VariableDeclarationList).type;
    final propNameToken = fieldDecl!.name;
    String? late = type != null && requiredPropHintAlreadyExists(type) ? null : '/*late*/';
    String? nullability = '/*${isDefaultedToNull ? '?' : '!'}*/';
    if (sdkVersion != null && VersionRange(min: Version.parse('2.12.0')).allows(sdkVersion)) {
      if (late != null) {
        // If the repo has opted into null safety, patch with the real thing instead of hints
        late = 'late';
        // Unless it already has the late keyword applied
        if ((type?.parent as VariableDeclarationList?)?.lateKeyword is Token) {
          late = null;
        }
      }

      nullability = isDefaultedToNull ? '?' : '';
    }

    // Object added if type is null b/c we gotta have a type to add the nullable `?`/`!` hints to - even if for some reason the prop decl. has no left side type.
    handleYieldPatch('${late ?? ''} ${type == null ? 'Object' : type.toString()}$nullability ', type?.offset ?? propNameToken.offset, propNameToken.offset);

    _patchedDeclaration = true;
  }

  @override
  bool operator ==(Object other) {
    // Use the id of the `FieldElement` for equality so that the set created in ClassComponentRequiredDefaultPropsMigrator filters out dupe instances.
    return other is DefaultedPropDeclaration && other.id == this.id;
  }

  @override
  int get hashCode => this.id;
}

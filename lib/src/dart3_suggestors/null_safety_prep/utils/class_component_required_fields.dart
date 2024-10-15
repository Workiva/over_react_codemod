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
import 'package:over_react_codemod/src/util.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:pub_semver/pub_semver.dart';

import '../../../util/class_suggestor.dart';
import '../../required_props/codemod/recommender.dart';
import '../analyzer_plugin_utils.dart';

/// A class shared by the suggestors that manage defaultProps/initialState.
abstract class ClassComponentRequiredFieldsMigrator<
        Assignment extends PropOrStateAssignment>
    extends RecursiveAstVisitor<void> with ClassSuggestor {
  final String relevantGetterName;
  final String relevantMethodName;

  /// When set to a version that opts-in to Dart's null safety feature,
  /// the `late` / `?` type modifiers will be actual modifiers rather
  /// than commented hints. This should only be done using an explicit opt-in
  /// flag from the executable as most consumers that have migrated to null-safety
  /// will have already run this script prior to the null safety migration and thus
  /// the `/*late*/` / `/*?*/` hints will already be converted to actual modifiers.
  final Version? sdkVersion;

  ClassComponentRequiredFieldsMigrator(
      this.relevantGetterName, this.relevantMethodName,
      [this.sdkVersion]);

  late ResolvedUnitResult result;
  final Set<DefaultedOrInitializedDeclaration> fieldData = {};

  void patchFieldDeclarations(
      Iterable<FieldElement> Function(InterfaceElement) getAll,
      Iterable<Assignment> cascadedDefaultPropsOrInitialState,
      CascadeExpression node, [PropRequirednessRecommender? _propRequirednessRecommender]) {

    for (final field in cascadedDefaultPropsOrInitialState) {
      final isDefaultedToNull =
          field.node.rightHandSide.staticType!.isDartCoreNull;
      final fieldEl = (field.node.writeElement! as PropertyAccessorElement)
          .variable as FieldElement;
      final propsOrStateElement =
          node.staticType?.typeOrBound.tryCast<InterfaceType>()?.element;
      if (propsOrStateElement == null) continue;
      final fieldDeclaration = _getFieldDeclaration(getAll,
          propsOrStateElement: propsOrStateElement, fieldName: fieldEl.name);
      // The field declaration is likely in another file which our logic currently doesn't handle.
      // In this case, don't add an entry to `fieldData`.
      if (fieldDeclaration == null) continue;
      final element = fieldDeclaration.declaredElement;

      // Don't set as required if the prop is publicly exported.
      if(_propRequirednessRecommender != null && element is FieldElement) {
        final isPublic = _propRequirednessRecommender
            .getRecommendation(element)?.reason?.isPublic ?? false;
        if(isPublic) continue;
      }

      fieldData.add(DefaultedOrInitializedDeclaration(
          fieldDeclaration, fieldEl, isDefaultedToNull));
    }

    fieldData.where((data) => !data.patchedDeclaration).forEach((data) {
      data.patch(yieldPatch, sdkVersion: sdkVersion);
    });
  }

  VariableDeclaration? _getFieldDeclaration(
      Iterable<FieldElement> Function(InterfaceElement) getAll,
      {required InterfaceElement propsOrStateElement,
      required String fieldName}) {
    // For component1 boilerplate its possible that `fieldEl` won't be found using `lookUpVariable` below
    // since its `enclosingElement` will be the generated abstract mixin. So we'll use the provided `getAll` fn to
    // cross reference the return value with the `fieldName`to locate the actual prop/state field declaration we want to patch.
    final siblingFields = getAll(propsOrStateElement);
    final matchingField =
        siblingFields.singleWhereOrNull((element) => element.name == fieldName);
    if (matchingField == null) return null;

    // NOTE: result.unit will only work if the declaration of the field is in this file
    return lookUpVariable(matchingField, result.unit);
  }

  @override
  Future<void> generatePatches() async {
    // Clear so we don't share state across CompilationUnits
    fieldData.clear();
    final r = await context.getResolvedUnit();
    if (r == null) {
      throw Exception(
          'Could not get resolved result for "${context.relativePath}"');
    }
    result = r;
    r.unit.accept(this);
  }
}

class DefaultedOrInitializedDeclaration {
  final VariableDeclaration fieldDecl;
  final FieldElement fieldEl;
  final bool isDefaultedToNull;
  final String name;

  DefaultedOrInitializedDeclaration(
      this.fieldDecl, this.fieldEl, this.isDefaultedToNull)
      : _patchedDeclaration = false,
        name = '${fieldDecl.name.lexeme}';

  /// Whether the declaration has been patched with the late / nullable hints.
  bool get patchedDeclaration => _patchedDeclaration;
  bool _patchedDeclaration;

  void patch(
      void Function(String updatedText, int startOffset, [int? endOffset])
          handleYieldPatch,
      {Version? sdkVersion}) {
    final parent = fieldDecl.parent! as VariableDeclarationList;
    final keyword = parent.keyword; // e.g. var
    final type = parent.type;
    final fieldNameToken = fieldDecl.name;
    if (type != null &&
        requiredHintAlreadyExists(type) &&
        (nullableHintAlreadyExists(type) ||
            nonNullableHintAlreadyExists(type))) {
      // Short circuit - it has already been patched
      _patchedDeclaration = true;
      return;
    }

    String? late =
        type != null && requiredHintAlreadyExists(type) ? null : '/*late*/';
    String nullability = '';
    if (isDefaultedToNull) {
      if (type == null || !nullableHintAlreadyExists(type)) {
        nullability = nullableHint;
      }
    } else {
      if (type == null || !nonNullableHintAlreadyExists(type)) {
        nullability = nonNullableHint;
      }
    }

    if (sdkVersion != null &&
        VersionRange(min: Version.parse('2.12.0')).allows(sdkVersion)) {
      if (late != null) {
        // If the repo has opted into null safety, patch with the real thing instead of hints
        late = 'late';
        // Unless it already has the late keyword applied
        if ((type?.parent as VariableDeclarationList?)?.lateKeyword is Token) {
          late = null;
        }
      }

      nullability = isDefaultedToNull ? '?' : '';

      if (late == null && nullability.isEmpty) {
        // Short circuit - it has already been patched
        _patchedDeclaration = true;
        return;
      }
    }

    late = late ?? '';
    // dynamic added if type is null b/c we gotta have a type to add the nullable `?`/`!` hints to - even if for some reason the prop/state decl. has no left side type.
    final patchedType =
        type == null ? 'dynamic$nullability' : '${type.toSource()}$nullability';
    final startOffset =
        type?.offset ?? keyword?.offset ?? fieldNameToken.offset;
    handleYieldPatch('$late $patchedType ', startOffset, fieldNameToken.offset);

    _patchedDeclaration = true;
  }

  @override
  bool operator ==(Object other) {
    return other is DefaultedOrInitializedDeclaration &&
        other.fieldEl == this.fieldEl;
  }

  @override
  int get hashCode => this.fieldEl.hashCode;
}

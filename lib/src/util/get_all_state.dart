// Adapted from https://github.com/Workiva/over_react/blob/master/tools/analyzer_plugin/lib/src/util/prop_declarations/get_all_props.dart

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

import 'package:analyzer/dart/element/element.dart';
import 'package:collection/collection.dart';

// Performance optimization notes:
// [1] Building a list here is slightly more optimal than using a generator.
//
// [2] Ideally we'd check the library and package here,
//     but for some reason accessing `.library` is pretty inefficient.
//     Possibly due to the `LibraryElementImpl? get library => thisOrAncestorOfType();` impl,
//     and an inefficient `thisOrAncestorOfType` impl: https://github.com/dart-lang/sdk/issues/53255

/// Returns all state defined in a props class/mixin [stateElement] as well as all of its supertypes,
/// except for those shared by all UiState instances by default.
///
/// Each returned field will be the consumer-declared state field, and the list will not contain overrides
/// from generated over_react parts.
///
/// Excludes any fields annotated with `@doNotGenerate`.
List<FieldElement> getAllState(InterfaceElement stateElement) {
  final stateAndSupertypeElements = stateElement.thisAndSupertypesList;

  // There are two UiState; one in component_base, and one in builder_helpers that extends from it.
  // Use the component_base one, since there are some edge-cases of props that don't extend from the
  // builder_helpers version.
  final uiStateElement = stateAndSupertypeElements.firstWhereOrNull((i) =>
      i.name == 'UiState' &&
      i.library.name == 'over_react.component_declaration.component_base');

  // If stateElement does not inherit from from UiState, it could still be a legacy mixin that doesn't implement UiState.
  // This check is only necessary to retrieve props when [stateElement] is itself a legacy mixin, and not when legacy
  // props mixins are encountered below as supertypes.
  final inheritsFromUiState = uiStateElement != null;
  late final isStateMixin = stateElement.metadata.any(_isStateMixinAnnotation);
  if (!inheritsFromUiState && !isStateMixin) {
    return [];
  }

  final uiStateAndSupertypeElements = uiStateElement?.thisAndSupertypesSet;

  final allState = <FieldElement>[]; // [1]
  for (final interface in stateAndSupertypeElements) {
    // Don't process UiState or its supertypes
    if (uiStateAndSupertypeElements?.contains(interface) ?? false) continue;

    // Filter out generated accessors mixins for legacy concrete props classes.
    late final isFromGeneratedFile =
        interface.source.uri.path.endsWith('.over_react.g.dart');
    if (interface.name.endsWith('AccessorsMixin') && isFromGeneratedFile) {
      continue;
    }

    final isMixinBasedPropsMixin = interface is MixinElement &&
        interface.superclassConstraints.any((s) => s.element.name == 'UiState');
    late final isLegacyStateOrStateMixinConsumerClass = !isFromGeneratedFile &&
        interface.metadata.any(_isStateOrStateMixinAnnotation);

    if (!isMixinBasedPropsMixin && !isLegacyStateOrStateMixinConsumerClass) {
      continue;
    }

    for (final field in interface.fields) {
      if (field.isStatic) continue;
      if (field.isSynthetic) continue;

      final accessorAnnotation = _getAccessorAnnotation(field.metadata);
      final isNoGenerate = accessorAnnotation
              ?.computeConstantValue()
              ?.getField('doNotGenerate')
              ?.toBoolValue() ??
          false;
      if (isNoGenerate) continue;

      allState.add(field);
    }
  }

  return allState;
}

bool _isStateOrStateMixinAnnotation(ElementAnnotation e) {
  // [2]
  final element = e.element;
  return element is ConstructorElement &&
      const {'State', 'StateMixin'}.contains(element.enclosingElement.name);
}

bool _isStateMixinAnnotation(ElementAnnotation e) {
  // [2]
  final element = e.element;
  return element is ConstructorElement &&
      element.enclosingElement.name == 'StateMixin';
}

ElementAnnotation? _getAccessorAnnotation(List<ElementAnnotation> metadata) {
  return metadata.firstWhereOrNull((annotation) {
    // [2]
    final element = annotation.element;
    return element is ConstructorElement &&
        element.enclosingElement.name == 'Accessor';
  });
}

extension on InterfaceElement {
  // Two separate collection implementations to micro-optimize collection creation/iteration based on usage.

  Set<InterfaceElement> get thisAndSupertypesSet =>
      {this, for (final s in allSupertypes) s.element};

  List<InterfaceElement> get thisAndSupertypesList =>
      [this, for (final s in allSupertypes) s.element];
}

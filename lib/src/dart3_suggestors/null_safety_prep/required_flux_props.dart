// Copyright 2023 Workiva Inc.
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

import 'dart:developer';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:collection/collection.dart';
import 'package:over_react_codemod/src/util/offset_util.dart';

import '../../util/class_suggestor.dart';

/// Suggestor that adds required `store` and/or `actions` prop(s) to the
/// call-site of `FluxUiComponent` instances that omit them since version
/// 5.0.0 of over_react makes flux `store`/`actions` props required.
///
/// In the case of a component that is rendered in a scope where a store/actions
/// instance is available, but simply not passed along to the component, those
/// instance(s) will be used as the value for `props.store`/`props.actions`,
/// even though the component itself may not make use of them internally.
///
/// In the case of a component that is rendered in a scope where a store/actions
/// instance is not available, `null` will be used as the value for the prop(s).
///   * When this happens, a FIX ME comment will be added since the boilerplate
///   of the FluxUiComponent's definition will need to be updated to allow `null`
///   store/actions value(s) by either:
///
///     * Updating the generic parameter(s) to allow nullable values
///       e.g. `FluxUiPropsMixin<FooActions?, FooStore?>` instead of `FluxUiPropsMixin<FooActions, FooStore>`
///
///     * Adding generic parameters to boilerplate that lacks generic parameters
///       e.g. `FluxUiPropsMixin<Null, FooStore>` or `FluxUiPropsMixin<Null, Null>` instead of `FluxUiPropsMixin`
class RequiredFluxProps extends GeneralizingAstVisitor
    with ClassSuggestor {
  ResolvedUnitResult? _result;
  final List<VariableDeclaration> _variablesInScope;
  final Map<String?, List<DartType?>> _fluxPropsParamTypesByPropsClass;

  RequiredFluxProps() :
        _variablesInScope = [],
        _fluxPropsParamTypesByPropsClass = {};

  static const fluxPropsMixinName = 'FluxUiPropsMixin';

  static Element? getPropsElementBeingWrittenTo(AssignmentExpression cascade) =>
      cascade.writeElement?.declaration?.enclosingElement;

  static bool writesToFluxUiProps(AssignmentExpression cascadeAssignment) {
    final el = getPropsElementBeingWrittenTo(cascadeAssignment);
    return el?.name == fluxPropsMixinName;
  }

  static bool hasAssignmentsThatWriteToFluxUiProps(CascadeExpression cascade) {
    final sections = cascade.cascadeSections;
    return sections.whereType<AssignmentExpression>().any(writesToFluxUiProps);
  }

  VariableElement? getVariableInScopeWithType(DartType? type) =>
      _variablesInScope.firstWhereOrNull((v) =>
          v.declaredElement?.type == type)?.declaredElement;

  @override
  visitVariableDeclaration(VariableDeclaration node) {
    super.visitVariableDeclaration(node);

    if (node.declaredElement != null) {
      // FIXME (adl): This needs to not pick up on variables that are declared in other classes in the same file
      _variablesInScope.add(node);
    }
  }

  @override
  visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    super.visitFunctionExpressionInvocation(node);

    dynamic element = node.staticType?.element;
    if (element is ClassElement) {
      final fluxPropsMixin = element.mixins
          .singleWhereOrNull((e) => e.element.name == fluxPropsMixinName);

      if (fluxPropsMixin != null) {
        _fluxPropsParamTypesByPropsClass
            .putIfAbsent(node.staticType?.element?.name, () => fluxPropsMixin.typeArguments);
      }
    }
  }

  @override
  visitCascadeExpression(CascadeExpression node) {
    super.visitCascadeExpression(node);
    // TODO (adl): Is this getting polluted across multiple cascades in the same file that have store/actions names?
    var storeAssigned = false;
    var actionsAssigned = false;
    node.cascadeSections.whereType<AssignmentExpression>().forEach((cascade) {
      if (writesToFluxUiProps(cascade)) {
        final lhs = cascade.leftHandSide;
        if (lhs is PropertyAccess && !storeAssigned) {
          storeAssigned = lhs.propertyName.name == 'store';
        }

        if (lhs is PropertyAccess && !actionsAssigned) {
          actionsAssigned = lhs.propertyName.name == 'actions';
        }
      }
    });

    final propsClassName = node.staticType?.element?.name;

    if (!storeAssigned) {
      final storeType = _fluxPropsParamTypesByPropsClass[propsClassName]?[1];
      final storeValue = getVariableInScopeWithType(storeType)?.name ?? 'null';
      yieldNewCascadeSection(node, '..store = $storeValue');
    }

    if (!actionsAssigned) {
      final actionsType = _fluxPropsParamTypesByPropsClass[propsClassName]?[0];
      final actionsValue = getVariableInScopeWithType(actionsType)?.name ?? 'null';
      yieldNewCascadeSection(node, '..actions = $actionsValue');
    }
  }

  void yieldNewCascadeSection(CascadeExpression node, String newSection) {
    if (hasAssignmentsThatWriteToFluxUiProps(node)) {
      final offset = context.sourceFile.getOffsetOfLineAfter(
          node.target.offset);
      yieldPatch(newSection, offset, offset);
    }
  }

  @override
  Future<void> generatePatches() async {
    _result = await context.getResolvedUnit();
    if (_result == null) {
      throw Exception(
          'Could not get resolved result for "${context.relativePath}"');
    }
    _result!.unit.visitChildren(this);
  }
}

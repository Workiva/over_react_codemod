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
class RequiredFluxProps extends RecursiveAstVisitor
    with ClassSuggestor {
  ResolvedUnitResult? _result;

  static const fluxPropsMixinName = 'FluxUiPropsMixin';

  VariableElement? getVariableInScopeWithType(AstNode node, DartType? type) {
    final globalScopeVariableDetector = _GlobalScopeVarDetector();
    node.thisOrAncestorOfType<CompilationUnit>()?.accept(globalScopeVariableDetector);

    final inScopeVariableDetector = _InScopeVarDetector();
    [
      // FIXME (adl): Need to look for prop values in class components
      node.thisOrAncestorOfType<ClassDeclaration>(),
      // FIXME (adl): Need to look for prop values in function components (and expression fn bodies)
      node.thisOrAncestorOfType<BlockFunctionBody>(),
    ].whereNotNull().forEach((ancestorNode) {
      ancestorNode.visitChildren(inScopeVariableDetector);
    });
    final inScopeVars = [
      ...globalScopeVariableDetector.found,
      ...inScopeVariableDetector.found,
    ];

    final inScopeVar = inScopeVars.firstWhereOrNull((v) {
      final maybeMatchingType = v.declaredElement?.type;
      // FIXME (adl): maybeMatchingType == type is only true on the first run. The idempotency test that runs a second time fails
      return maybeMatchingType?.element?.name == type?.element?.name;
    })?.declaredElement;
    return inScopeVar;
  }

  @override
  visitCascadeExpression(CascadeExpression node) {
    var writesToFluxUiProps = false;
    var actionsAssigned = false;
    var storeAssigned = false;

    List<DartType?>? fluxStoreAndActionTypes;
    final cascadeWriteEl = node.staticType?.element;
    if (cascadeWriteEl is ClassElement) {
      final maybeFluxUiPropsMixin = cascadeWriteEl.mixins
          .singleWhereOrNull((e) => e.element.name == fluxPropsMixinName);
      writesToFluxUiProps = maybeFluxUiPropsMixin != null;
      fluxStoreAndActionTypes = maybeFluxUiPropsMixin?.typeArguments;
    }

    final cascadingAssignments = node.cascadeSections.whereType<AssignmentExpression>();
    storeAssigned = cascadingAssignments.any((cascade) {
      final lhs = cascade.leftHandSide;
      return lhs is PropertyAccess && lhs.propertyName.name == 'store';
    });
    actionsAssigned = cascadingAssignments.any((cascade) {
      final lhs = cascade.leftHandSide;
      return lhs is PropertyAccess && lhs.propertyName.name == 'actions';
    });

    if (writesToFluxUiProps && !storeAssigned) {
      storeAssigned = true;
      final fluxStoreType = fluxStoreAndActionTypes?[1];
      final storeValue = getVariableInScopeWithType(node, fluxStoreType)?.name ?? 'null';
      yieldNewCascadeSection(node, '..store = $storeValue');
    }

    if (writesToFluxUiProps && !actionsAssigned) {
      actionsAssigned = true;
      final fluxActionsType = fluxStoreAndActionTypes?[0];
      final actionsValue = getVariableInScopeWithType(node, fluxActionsType)?.name ?? 'null';
      yieldNewCascadeSection(node, '..actions = $actionsValue');
    }
  }

  void yieldNewCascadeSection(CascadeExpression node, String newSection) {
    final offset = context.sourceFile.getOffsetOfLineAfter(
        node.target.offset);
    yieldPatch(newSection, offset, offset);
  }

  @override
  Future<void> generatePatches() async {
    _result = await context.getResolvedUnit();
    if (_result == null) {
      throw Exception(
          'Could not get resolved result for "${context.relativePath}"');
    }
    _result!.unit.accept(this);
  }
}

mixin _InScopeVarDetectorMixin on AstVisitor {
  List<VariableDeclaration> get found;

  @override
  visitVariableDeclaration(VariableDeclaration node) {
    if (node.declaredElement != null) {
      found.add(node);
    }
  }
}

class _InScopeVarDetector extends RecursiveAstVisitor<void> with _InScopeVarDetectorMixin {
  @override
  final List<VariableDeclaration> found;

  _InScopeVarDetector() : found = [];
}

class _GlobalScopeVarDetector extends RecursiveAstVisitor<void> with _InScopeVarDetectorMixin {
  @override
  final List<VariableDeclaration> found;

  _GlobalScopeVarDetector() : found = [];
}

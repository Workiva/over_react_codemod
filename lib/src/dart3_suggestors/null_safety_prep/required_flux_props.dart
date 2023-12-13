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
class RequiredFluxProps extends RecursiveAstVisitor
    with ClassSuggestor {
  ResolvedUnitResult? _result;

  static const fluxPropsMixinName = 'FluxUiPropsMixin';

  String? getNameOfVarOrFieldInScopeWithType(AstNode node, DartType? type) {
    final inScopeVariableDetector = _InScopeVarDetector();
    // Find top level vars
    node.thisOrAncestorOfType<CompilationUnit>()?.accept(inScopeVariableDetector);
    // Find vars declared in top-level fns (like `main()`)
    node.thisOrAncestorOfType<BlockFunctionBody>()?.visitChildren(inScopeVariableDetector);

    final inScopeVarName = inScopeVariableDetector.found.firstWhereOrNull((v) {
      final maybeMatchingType = v.declaredElement?.type;
      return maybeMatchingType?.element?.name == type?.element?.name;
    })?.declaredElement?.name;

    final componentScopePropDetector = _ComponentScopeFluxPropsDetector();
    // Find actions/store in props of class components
    node.thisOrAncestorOfType<ClassDeclaration>()?.accept(componentScopePropDetector);
    // Find actions/store in props of fn components
    node.thisOrAncestorOfType<MethodInvocation>()?.accept(componentScopePropDetector);

    final inScopePropName = componentScopePropDetector.found.firstWhereOrNull((el) {
      final maybeMatchingType = componentScopePropDetector.getAccessorType(el);
      return maybeMatchingType?.element?.name == type?.element?.name;
    })?.name;

    if (inScopeVarName != null && inScopePropName != null) {
      // TODO: Do we need to handle this edge case with something better than returning null?
      // No way to determine which should be used - the scoped variable or the field on props
      // so return null to avoid setting the incorrect value on the consumer's code.
      return null;
    }

    if (inScopePropName != null) {
      return '${componentScopePropDetector.propsName}.${inScopePropName}';
    }

    return inScopeVarName;
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
      final storeValue = getNameOfVarOrFieldInScopeWithType(node, fluxStoreType) ?? 'null';
      yieldNewCascadeSection(node, '..store = $storeValue');
    }

    if (writesToFluxUiProps && !actionsAssigned) {
      actionsAssigned = true;
      final fluxActionsType = fluxStoreAndActionTypes?[0];
      final actionsValue = getNameOfVarOrFieldInScopeWithType(node, fluxActionsType) ?? 'null';
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

bool isFnComponentDeclaration(Expression? varInitializer) => varInitializer is MethodInvocation &&
    varInitializer.methodName.name.startsWith('uiF');

/// A visitor to detect in-scope store/actions variables (top-level and block function scopes)
class _InScopeVarDetector extends RecursiveAstVisitor<void> {
  final List<VariableDeclaration> found;

  _InScopeVarDetector() : found = [];

  @override
  visitVariableDeclaration(VariableDeclaration node) {
    // Don't visit function component declarations here since we visit them using the _ComponentScopeFluxPropsDetector
    if (isFnComponentDeclaration(node.initializer)) return;

    if (node.declaredElement != null) {
      found.add(node);
    }
  }
}

/// A visitor to detect store/actions values in a props class (supports both class and fn components)
class _ComponentScopeFluxPropsDetector extends RecursiveAstVisitor<void> {
  final Map<PropertyAccessorElement, DartType> _foundWithMappedTypes;
  List<PropertyAccessorElement> get found => _foundWithMappedTypes.keys.toList();

  _ComponentScopeFluxPropsDetector() : _foundWithMappedTypes = {};

  String _propsName = 'props';
  /// The name of the function component props arg, or the class component `props` instance field.
  String get propsName => _propsName;

  DartType? getAccessorType(PropertyAccessorElement el) => _foundWithMappedTypes[el];

  void _lookForFluxStoreAndActionsInPropsClass(Element? elWithProps) {
    if (elWithProps is ClassElement) {
      final fluxPropsEl = elWithProps.mixins
          .singleWhereOrNull((e) => e.element.name == RequiredFluxProps.fluxPropsMixinName);

      if (fluxPropsEl != null) {
        final actionsType = fluxPropsEl.typeArguments[0];
        final storeType = fluxPropsEl.typeArguments[1];
        fluxPropsEl.accessors.forEach((a) {
          final accessorTypeName = a.declaration.variable.type.element?.name;
          if (accessorTypeName == 'ActionsT') {
            _foundWithMappedTypes.putIfAbsent(a.declaration, () => actionsType);
          } else if (accessorTypeName == 'StoresT') {
            _foundWithMappedTypes.putIfAbsent(a.declaration, () => storeType);
          }
        });
      }
    }
  }

  /// Visit function components
  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (!isFnComponentDeclaration(node)) return;

    final nodeType = node.staticType;
    if (nodeType is FunctionType) {
      final propsArg = node.argumentList.arguments.firstOrNull as FunctionExpression?;
      final propsArgName = propsArg?.parameters?.parameterElements.firstOrNull?.name;
      if (propsArgName != null) {
        _propsName = propsArgName;
      }
      _lookForFluxStoreAndActionsInPropsClass(nodeType.returnType.element);
    }
  }

  /// Visit composite (class) components
  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final elWithProps = node.declaredElement?.supertype?.typeArguments.singleOrNull?.element;
    _lookForFluxStoreAndActionsInPropsClass(elWithProps);
  }
}

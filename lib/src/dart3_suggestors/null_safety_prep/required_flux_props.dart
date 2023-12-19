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
import 'package:over_react_codemod/src/util.dart';
import 'package:over_react_codemod/src/util/class_suggestor.dart';
import 'package:over_react_codemod/src/util/offset_util.dart';

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
class RequiredFluxProps extends RecursiveAstVisitor with ClassSuggestor {
  ResolvedUnitResult? _result;

  static const fluxPropsMixinName = 'FluxUiPropsMixin';

  @override
  visitCascadeExpression(CascadeExpression node) {
    final cascadeWriteEl = node.staticType?.element;
    if (cascadeWriteEl is! ClassElement) return;
    final isReturnedAsDefaultProps = node.ancestors
            .whereType<MethodDeclaration>()
            .firstOrNull
            ?.name
            .value()
            .toString()
            .contains(RegExp(r'getDefaultProps|defaultProps')) ==
        true;
    if (isReturnedAsDefaultProps) return;

    final maybeFluxUiPropsMixin = cascadeWriteEl.mixins
        .singleWhereOrNull((e) => e.element.name == fluxPropsMixinName);
    if (maybeFluxUiPropsMixin == null) return;

    final fluxActionsType = maybeFluxUiPropsMixin.typeArguments[0];
    final fluxStoreType = maybeFluxUiPropsMixin.typeArguments[1];

    final cascadingAssignments =
        node.cascadeSections.whereType<AssignmentExpression>();
    var storeAssigned = cascadingAssignments.any((cascade) {
      final lhs = cascade.leftHandSide;
      return lhs is PropertyAccess && lhs.propertyName.name == 'store';
    });
    var actionsAssigned = cascadingAssignments.any((cascade) {
      final lhs = cascade.leftHandSide;
      return lhs is PropertyAccess && lhs.propertyName.name == 'actions';
    });

    if (!storeAssigned) {
      storeAssigned = true;
      final storeValue =
          _getNameOfVarOrFieldInScopeWithType(node, fluxStoreType) ?? 'null';
      yieldNewCascadeSection(node, '..store = $storeValue');
    }

    if (!actionsAssigned) {
      actionsAssigned = true;
      final actionsValue =
          _getNameOfVarOrFieldInScopeWithType(node, fluxActionsType) ?? 'null';
      yieldNewCascadeSection(node, '..actions = $actionsValue');
    }
  }

  void yieldNewCascadeSection(CascadeExpression node, String newSection) {
    final sf = context.sourceFile;
    final targetLineOffset = sf.getOffset(sf.getLine(node.target.offset));
    int offset;
    if (targetLineOffset == sf.getOffset(sf.getLine(node.target.end))) {
      // Cascade on a single line / same line as the target, add the new setter(s) before the semicolon
      offset = node.target.end;
    } else {
      offset = sf.getOffsetOfLineAfter(node.target.offset);
    }
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

class InScopeVariable {
  final String name;
  final DartType? type;

  InScopeVariable(this.name, this.type);
}

String? _getNameOfVarOrFieldInScopeWithType(AstNode node, DartType type) {
  final mostInScopeVariables = node.ancestors.expand((ancestor) sync* {
    if (ancestor is FunctionDeclaration) {
      // Function arguments
      final element = ancestor.declaredElement;
      if (element != null) {
        yield* element.parameters.map((p) => InScopeVariable(p.name, p.type));
      }
    } else if (ancestor is Block) {
      // Variables declared in the block (function body, if/else block, etc.)
      yield* ancestor.statements
          .whereType<VariableDeclarationStatement>()
          .expand((d) => d.variables.variables)
          .map((v) => InScopeVariable(v.name.lexeme, v.declaredElement?.type));
    } else if (ancestor is ClassDeclaration) {
      // Class fields
      final element = ancestor.declaredElement;
      if (element != null) {
        yield* element.fields.map((f) => InScopeVariable(f.name, f.type));
      }
    } else if (ancestor is CompilationUnit) {
      // Top-level variables
      yield* ancestor.declarations
          .whereType<TopLevelVariableDeclaration>()
          .expand((d) => d.variables.variables)
          .map((v) => InScopeVariable(v.name.lexeme, v.declaredElement?.type));
    }
  });

  // Usually we'd grab typeSystem from the ResolvedUnitResult, but we don't have access to that
  // in this class, so just get it from the compilation unit.
  final typeSystem =
      (node.root as CompilationUnit).declaredElement!.library.typeSystem;
  bool isMatchingType(DartType? maybeMatchingType) =>
      maybeMatchingType != null &&
      typeSystem.isAssignableTo(maybeMatchingType, type);

  final inScopeVarName = mostInScopeVariables
      .firstWhereOrNull((v) => isMatchingType(v.type))
      ?.name;

  final componentScopePropDetector = _ComponentScopeFluxPropsDetector();
  // Find actions/store in props of class components
  componentScopePropDetector.handlePotentialClassComponent(
      node.thisOrAncestorOfType<ClassDeclaration>());
  // Find actions/store in props of fn components
  componentScopePropDetector.handlePotentialFunctionComponent(
      node.thisOrAncestorOfType<MethodInvocation>());

  final inScopePropName =
      componentScopePropDetector.found.firstWhereOrNull((el) {
    final maybeMatchingType = componentScopePropDetector.getAccessorType(el);
    return maybeMatchingType?.element?.name == type.element?.name;
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

bool _isFnComponentDeclaration(Expression? varInitializer) =>
    varInitializer is MethodInvocation &&
    varInitializer.methodName.name.startsWith('uiF');

/// A visitor to detect store/actions values in a props class (supports both class and fn components)
class _ComponentScopeFluxPropsDetector {
  final Map<PropertyAccessorElement, DartType> _foundWithMappedTypes;

  List<PropertyAccessorElement> get found =>
      _foundWithMappedTypes.keys.toList();

  _ComponentScopeFluxPropsDetector() : _foundWithMappedTypes = {};

  String _propsName = 'props';

  /// The name of the function component props arg, or the class component `props` instance field.
  String get propsName => _propsName;

  DartType? getAccessorType(PropertyAccessorElement el) =>
      _foundWithMappedTypes[el];

  void _lookForFluxStoreAndActionsInPropsClass(Element? elWithProps) {
    if (elWithProps is ClassElement) {
      final fluxPropsEl = elWithProps.mixins.singleWhereOrNull(
          (e) => e.element.name == RequiredFluxProps.fluxPropsMixinName);

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
  void handlePotentialFunctionComponent(MethodInvocation? node) {
    if (node == null) return;
    if (!_isFnComponentDeclaration(node)) return;

    final nodeType = node.staticType;
    if (nodeType is FunctionType) {
      final propsArg =
          node.argumentList.arguments.firstOrNull as FunctionExpression?;
      final propsArgName =
          propsArg?.parameters?.parameterElements.firstOrNull?.name;
      if (propsArgName != null) {
        _propsName = propsArgName;
      }
      _lookForFluxStoreAndActionsInPropsClass(nodeType.returnType.element);
    }
  }

  /// Visit composite (class) components
  void handlePotentialClassComponent(ClassDeclaration? node) {
    if (node == null) return;
    final elWithProps =
        node.declaredElement?.supertype?.typeArguments.singleOrNull?.element;
    _lookForFluxStoreAndActionsInPropsClass(elWithProps);
  }
}

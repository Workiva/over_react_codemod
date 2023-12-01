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

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:codemod/codemod.dart';

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
    with AstVisitingSuggestor {
  static bool usesFlux(AssignmentExpression cascade) =>
      cascade.writeElement?.declaration?.enclosingElement?.name == 'FluxUiPropsMixin';

  @override
  visitCascadeExpression(CascadeExpression node) {
    super.visitCascadeExpression(node);

    var storeAssigned = false;
    var actionsAssigned = false;
    node.cascadeSections.whereType<AssignmentExpression>().forEach((cascade) {
      if (usesFlux(cascade)) {
        final lhs = cascade.leftHandSide;
        if (lhs is PropertyAccess && !storeAssigned) {
          storeAssigned = lhs.propertyName.name == 'store';
        }
        if (lhs is PropertyAccess && !actionsAssigned) {
          actionsAssigned = lhs.propertyName.name == 'actions';
        }
      }
    });

    if (!storeAssigned) {
      // TODO (adl): Check if an store instance is available in scope
      // yieldPatch('..actions = null', start, end,);
    }

    if (!actionsAssigned) {
      // TODO (adl): Check if an actions instance is available in scope
      // yieldPatch('..actions = null', start, end,);
    }
  }
}

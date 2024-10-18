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
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:over_react_codemod/src/dart3_suggestors/null_safety_prep/utils/props_utils.dart';
import 'package:over_react_codemod/src/util.dart';
import 'package:over_react_codemod/src/util/class_suggestor.dart';

import 'analyzer_plugin_utils.dart';

// todo update
/// Suggestor that replaces a `null` literal argument passed to a "DOM" callback
/// with a generated `SyntheticEvent` object of the expected type.
///
/// Example:
///
/// ```dart
/// final props = domProps();
/// // Before
/// props.onClick(null);
/// // After
/// props.onClick(createSyntheticMouseEvent());
/// ```
class ConnectRequiredProps extends RecursiveAstVisitor with ClassSuggestor {
  late ResolvedUnitResult _result;

  @override
  visitCascadeExpression(CascadeExpression node) {
    super.visitCascadeExpression(node);

    // Verify the builder usage is within the `connect` method call.
    final connect = node.thisOrAncestorMatching<MethodInvocation>((n) => n is MethodInvocation && n.methodName.name == 'connect');
    if(connect == null) return;

    // Verify the builder usage is within one of the targeted connect args.
    final connectArgs = connect.argumentList.arguments.whereType<NamedExpression>();
    final connectArg = node.thisOrAncestorMatching<NamedExpression>((n) => n is NamedExpression && connectArgs.contains(n) && connectArgNames.contains(n.name.label.name));
    if(connectArg == null) return;

    final cascadedProps = getCascadedProps(node).toList();

    final ignoredPropsByMixin = <InterfaceElement, List<String>>{};
    for (final field in cascadedProps) {
      final propsElement =
          node.staticType?.typeOrBound.tryCast<InterfaceType>()?.element;
      if (propsElement == null) continue;

      final fieldName = field.name.name;
      if (ignoredPropsByMixin[propsElement] != null) {
        ignoredPropsByMixin[propsElement]!.add(fieldName);
      } else {
        ignoredPropsByMixin[propsElement] = [fieldName];
      }
    }

    for(final propsClass in ignoredPropsByMixin.keys) {
      final classNode = NodeLocator2(propsClass.nameOffset).searchWithin(_result.unit);
      if(classNode != null) {
        yieldPatch(
            '@Props(disableRequiredPropValidation: {${ignoredPropsByMixin[propsClass]!.map((p) => '\'$p\'').join(', ')}})',
            classNode.offset, classNode.offset);
      }
    }
  }

  @override
  Future<void> generatePatches() async {
    final r = await context.getResolvedUnit();
    if (r == null) {
      throw Exception(
          'Could not get resolved result for "${context.relativePath}"');
    }
    _result = r;
    _result.unit.accept(this);
  }
  static const connectArgNames = ['mapStateToProps', 'mapDispatchToProps'];
}

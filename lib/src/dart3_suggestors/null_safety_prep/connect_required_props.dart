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

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:collection/collection.dart';
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
  /// Running list of props that should be ignored per mixin that will all be added
  /// at the end in [generatePatches].
  final _ignoredPropsByMixin = <InterfaceElement, List<String>>{};

  @override
  visitCascadeExpression(CascadeExpression node) {
    super.visitCascadeExpression(node);

    // Verify the builder usage is within the `connect` method call.
    final connect = node.thisOrAncestorMatching<MethodInvocation>(
        (n) => n is MethodInvocation && n.methodName.name == 'connect');
    if (connect == null) return;

    // Verify the builder usage is within one of the targeted connect args.
    final connectArgs =
        connect.argumentList.arguments.whereType<NamedExpression>();
    final connectArg = node.thisOrAncestorMatching<NamedExpression>((n) =>
        n is NamedExpression &&
        connectArgs.contains(n) &&
        connectArgNames.contains(n.name.label.name));
    if (connectArg == null) return;

    final cascadedProps = getCascadedProps(node).toList();

    for (final field in cascadedProps) {
      final propsElement =
          node.staticType?.typeOrBound.tryCast<InterfaceType>()?.element;
      if (propsElement == null) continue;

      final fieldName = field.name.name;
      if (_ignoredPropsByMixin[propsElement] != null) {
        _ignoredPropsByMixin[propsElement]!.add(fieldName);
      } else {
        _ignoredPropsByMixin[propsElement] = [fieldName];
      }
    }
  }

  @override
  Future<void> generatePatches() async {
    _ignoredPropsByMixin.clear();
    final result = await context.getResolvedUnit();
    if (result == null) {
      throw Exception(
          'Could not get resolved result for "${context.relativePath}"');
    }
    result.unit.accept(this);

    // Add the patches at the end so that all the props to be ignored can be collected
    // from the different args in `connect` before adding patches to avoid duplicate patches.
    for (final propsClass in _ignoredPropsByMixin.keys) {
      final propsToIgnore = _ignoredPropsByMixin[propsClass]!;
      final classNode =
          NodeLocator2(propsClass.nameOffset).searchWithin(result.unit);
      if (classNode != null && classNode is NamedCompilationUnitMember) {
        final existingAnnotation =
            classNode.metadata.where((c) => c.name.name == 'Props').firstOrNull;
        if (existingAnnotation == null) {
          yieldPatch(
              '@Props(disableRequiredPropValidation: {${propsToIgnore.map((p) => '\'$p\'').join(', ')}})',
              classNode.offset,
              classNode.offset);
        } else {
          final ignoreArg = existingAnnotation.arguments?.arguments
              .whereType<NamedExpression>()
              .where(
                  (e) => e.name.label.name == 'disableRequiredPropValidation')
              .firstOrNull;
          if (ignoreArg == null) {
            final offset = existingAnnotation.arguments?.leftParenthesis.end;
            if (offset != null) {
              yieldPatch(
                  'disableRequiredPropValidation: {${propsToIgnore.map((p) => '\'$p\'').join(', ')}}${existingAnnotation.arguments?.arguments.isNotEmpty ?? false ? ', ' : ''}',
                  offset,
                  offset);
            }
          } else {
            final existingList =
                ignoreArg.expression.tryCast<SetOrMapLiteral>();
            if (existingList != null) {
              final alreadyIgnored = existingList.elements
                  .whereType<SimpleStringLiteral>()
                  .map((e) => e.stringValue)
                  .toList();
              final newPropsToIgnore =
                  propsToIgnore.where((p) => !alreadyIgnored.contains(p));
              if (newPropsToIgnore.isNotEmpty) {
                final offset = existingList.leftBracket.end;
                yieldPatch(
                    '${newPropsToIgnore.map((p) => '\'$p\'').join(', ')}, ',
                    offset,
                    offset);
              }
            }
          }
        }
      }
    }
  }

  static const connectArgNames = ['mapStateToProps', 'mapDispatchToProps'];
}

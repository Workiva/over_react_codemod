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

/// Suggestor that adds `@Props(disableRequiredPropValidation: {...})` annotations
/// for props that are set in `connect` components.
class ConnectRequiredProps extends RecursiveAstVisitor with ClassSuggestor {
  /// Running list of props that should be ignored per mixin that will all be added
  /// at the end in [generatePatches].
  final _ignoredPropsByMixin = <InterfaceElement, Set<String>>{};

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

      // Keep a running list of props to ignore per props mixin.
      final fieldName = field.name.name;
      _ignoredPropsByMixin.putIfAbsent(propsElement, () => {}).add(fieldName);
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
    _ignoredPropsByMixin.forEach((propsClass, propsToIgnore) {
      final classNode =
          NodeLocator2(propsClass.nameOffset).searchWithin(result.unit);
      if (classNode != null && classNode is NamedCompilationUnitMember) {
        final existingAnnotation =
            classNode.metadata.where((c) => c.name.name == 'Props').firstOrNull;

        if (existingAnnotation == null) {
          // Add full @Props annotation if it doesn't exist.
          yieldPatch(
              '@Props($annotationArg: {${propsToIgnore.map((p) => '\'$p\'').join(', ')}})\n',
              classNode.offset,
              classNode.offset);
        } else {
          final existingAnnotationArg = existingAnnotation.arguments?.arguments
              .whereType<NamedExpression>()
              .where((e) => e.name.label.name == annotationArg)
              .firstOrNull;

          if (existingAnnotationArg == null) {
            // Add disable validation arg to existing @Props annotation.
            final offset = existingAnnotation.arguments?.leftParenthesis.end;
            if (offset != null) {
              yieldPatch(
                  '$annotationArg: {${propsToIgnore.map((p) => '\'$p\'').join(', ')}}${existingAnnotation.arguments?.arguments.isNotEmpty ?? false ? ', ' : ''}',
                  offset,
                  offset);
            }
          } else {
            // Add props to disable validation for to the existing list of disabled
            // props in the @Props annotation if they aren't already listed.
            final existingList =
                existingAnnotationArg.expression.tryCast<SetOrMapLiteral>();
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
    });
  }

  static const connectArgNames = [
    'mapStateToProps',
    'mapStateToPropsWithOwnProps',
    'mapDispatchToProps',
    'mapDispatchToPropsWithOwnProps',
  ];
  static const annotationArg = 'disableRequiredPropValidation';
}

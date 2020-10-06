// Copyright 2020 Workiva Inc.
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
import 'package:over_react_codemod/src/boilerplate_suggestors/boilerplate_utilities.dart';

import 'boilerplate_utilities.dart';

/// Suggestor that looks for `@Props()`, `@State()`, `@Component2()` and `@Factory()` annotations, and removes them
/// as long as they do not contain any arguments.
///
/// > NOTE: `@PropsMixin()` and `@StateMixin()` annotations are removed via [PropsMixinMigrator].
class AnnotationsRemover extends GeneralizingAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  final ClassToMixinConverter converter;

  AnnotationsRemover(this.converter);

  @override
  visitCompilationUnitMember(CompilationUnitMember node) {
    super.visitAnnotatedNode(node);

    final annotationToRemove =
        node.metadata.firstWhere(_annotationIsRelevant, orElse: () => null);

    // --- Short Circuit Conditions --- //
    if (annotationToRemove == null) return;
    if (annotationToRemove.arguments.arguments.isNotEmpty) return;
    if (!_propsOrStateClassBoilerplateIsCompatible(node)) return;

    // --- Migrate --- //
    // Take out the whole line if we can
    var end = annotationToRemove.end;
    if (sourceFile.getText(end, end + 1) == '\n') {
      end = end + 1;
    }
    yieldPatch(annotationToRemove.offset, end, '');
  }

  static const _relevantAnnotationNames = [
    'Factory',
    'AbstractProps',
    'Props',
    'PropsMixin',
    'AbstractState',
    'State',
    'StateMixin',
    'AbstractComponent2',
    'Component2',
  ];

  bool _annotationIsRelevant(Annotation annotation) =>
      _relevantAnnotationNames.contains(annotation.name.name);

  bool _nodeHasRelevantAnnotation(CompilationUnitMember node) =>
      node.metadata.any(_annotationIsRelevant);

  bool _nodeHasAnnotationWithName(
          CompilationUnitMember node, String annotationName) =>
      node.metadata.any((annotation) => annotation.name.name == annotationName);

  List<String> _getNamesOfPropsClassThatMayHaveBeenConverted(
      CompilationUnitMember node) {
    if (node is TopLevelVariableDeclaration) {
      return [getPropsClassNameFromFactoryDeclaration(node)];
    } else if (node is ClassDeclaration) {
      final rootName = node.name.name.replaceFirst(RegExp(r'Component$'), '');
      // Some props classes have an extra "Component" in their name
      return [
        '${rootName}Props',
        '${rootName}ComponentProps',
      ];
    }

    return null;
  }

  bool _propsOrStateClassBoilerplateIsCompatible(CompilationUnitMember node) {
    if (_nodeHasAnnotationWithName(node, 'Factory') ||
        _nodeHasAnnotationWithName(node, 'Component2') ||
        _nodeHasAnnotationWithName(node, 'AbstractComponent2')) {
      // It's not a props or state class that would have been converted to the new boilerplate by a previous migrator.
      // but it is a UiComponent-related class with an annotation.
      return _getNamesOfPropsClassThatMayHaveBeenConverted(node)
          .any(converter.isBoilerplateCompatible);
    } else if (_nodeHasRelevantAnnotation(node) &&
        node is NamedCompilationUnitMember) {
      return converter.isBoilerplateCompatible(node.name.name);
    }

    return false;
  }
}

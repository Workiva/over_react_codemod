// Copyright 2019 Workiva Inc.
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

import '../constants.dart';
import 'component2_utilities.dart';

/// Suggestor that replaces `UiComponent` with `UiComponent2` in extends clauses
/// and updates the annotation to `@Component2()`.
///
/// The same update is made for `UiStatefulComponent` and `react.Component`
/// (including instances where `react.Component` is used for typing).
/// `react.dart` imports are also updated to show Component2 as well
/// as Component.
class ClassNameAndAnnotationMigrator extends GeneralizingAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  Iterable<String> get migrateAnnotations =>
      overReact16AnnotationNamesToMigrate;

  @override
  visitImportDirective(ImportDirective node) {
    super.visitImportDirective(node);

    if (node.uri?.stringValue != 'package:react/react.dart' ||
        node.combinators.isEmpty) {
      return;
    }

    // Add Component2 to import show list.
    var showNamesList = (node.combinators.firstWhere(
            (combinator) => combinator is ShowCombinator,
            orElse: () => null) as ShowCombinator)
        ?.shownNames;
    if (showNamesList != null &&
        !showNamesList.any((name) => name.toSource() == 'Component2')) {
      yieldPatch(
        showNamesList.last.end,
        showNamesList.last.end,
        ', Component2',
      );
    }
  }

  @override
  visitClassDeclaration(ClassDeclaration node) {
    super.visitClassDeclaration(node);

    var extendsName = node.extendsClause?.superclass?.name;
    if (extendsName == null) {
      return;
    }

    String reactImportName =
        getImportNamespace(node, 'package:react/react.dart');

    if (reactImportName != null &&
        extendsName.name == '$reactImportName.Component') {
      // Update `react.Component` extends clause.
      yieldPatch(
        extendsName.end,
        extendsName.end,
        '2',
      );
    } else {
      if (!node.metadata.any((m) =>
          migrateAnnotations.contains(m.name.name) ||
          overReact16AnnotationNames.contains(m.name.name))) {
        // Only looking for classes annotated with `@Props()`, `@State()`,
        // `@AbstractProps()`, or `@AbstractState()`. If [renameMixins] is true,
        // also includes `@PropsMixin()` and `@StateMixin()`.
        return;
      }

      // Update annotation.
      Iterable<Annotation> annotationRefs =
          node.metadata.where((m) => migrateAnnotations.contains(m.name.name));

      annotationRefs.forEach((annotationRef) {
        if (annotationRef.name.name.contains('2')) {
          return;
        }

        yieldPatch(
          annotationRef.name.end,
          annotationRef.name.end,
          '2',
        );
      });

      if (extendsName.name == 'UiComponent' ||
          extendsName.name == 'UiStatefulComponent') {
        // Update `UiComponent` or `UiStatefulComponent` extends clause.
        yieldPatch(
          extendsName.end,
          extendsName.end,
          '2',
        );
      }
    }
  }
}

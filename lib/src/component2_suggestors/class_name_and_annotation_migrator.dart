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

import 'package:analyzer/analyzer.dart';
import 'package:codemod/codemod.dart';

import '../constants.dart';

/// Suggestor that replaces `UiComponent` with `UiComponent2` in extends clauses
/// and updates the annotation to `@Component2()`.
///
/// The same update is made for `UiStatefulComponent` and `react.Component`
/// (including instances where `react.Component` is used for typing).
class ClassNameAndAnnotationMigrator extends GeneralizingAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  Iterable<String> get migrateAnnotations =>
      overReact16AnnotationNamesToMigrate;

  @override
  visitImportDirective(ImportDirective node) {
    super.visitImportDirective(node);

    if (node.uri?.stringValue != 'package:react/react.dart' ||
        node.combinators.isEmpty) return;

    var showNamesList = (node.combinators.first as ShowCombinator)?.shownNames;
    var showName = showNamesList?.firstWhere(
      (name) => name.toSource() == 'Component',
      orElse: () => null,
    );

    // Update imported class.
    if (showName != null) {
      yieldPatch(
        showName.end,
        showName.end,
        '2',
      );
    }
  }

  @override
  visitTypeName(TypeName node) {
    super.visitTypeName(node);

    // Get the name of the react.dart import.
    CompilationUnit importList = node.thisOrAncestorMatching((ancestor) {
      return ancestor is CompilationUnit;
    });

    ImportDirective reactImport = importList.directives.lastWhere(
        (dir) =>
            (dir as ImportDirective)?.uri?.stringValue ==
            'package:react/react.dart',
        orElse: () => null);

    String reactImportName = reactImport?.prefix?.name;

    // Update imported type.
    if (reactImportName != null &&
        node.toSource() == '$reactImportName.Component') {
      yieldPatch(
        node.end,
        node.end,
        '2',
      );
    }
  }

  @override
  visitClassDeclaration(ClassDeclaration node) {
    super.visitClassDeclaration(node);

    String extendsName = node.extendsClause?.superclass?.name?.name;
    if (extendsName == null) return;

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
      if (annotationRef.name.name.contains('2')) return;

      yieldPatch(
        annotationRef.name.end,
        annotationRef.name.end,
        '2',
      );
    });

    // Update extends clause.
    if (extendsName == 'UiComponent' || extendsName == 'UiStatefulComponent') {
      yieldPatch(
        node.extendsClause.superclass.name.end,
        node.extendsClause.superclass.name.end,
        '2',
      );
    } else {
      return;
    }
  }
}

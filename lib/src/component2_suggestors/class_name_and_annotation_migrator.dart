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
  ClassNameAndAnnotationMigrator();

  Iterable<String> get migrateAnnotations =>
      overReact16AnnotationNamesToMigrate;

  @override
  visitImportDirective(ImportDirective node) {
    super.visitImportDirective(node);

    if (!node.toString().contains('package:react/react.dart')) return;

    int showNameLocation = node.childEntities.toList().lastIndexWhere((i) =>
        i.toString().startsWith('show Component') &&
        !i.toString().contains('Component2'));

    // Update imported class.
    if (showNameLocation != -1) {
      var showName = node.childEntities.elementAt(showNameLocation);
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
    String reactImportName;
    var importList = (node.thisOrAncestorMatching((ancestor) {
      return ancestor is CompilationUnit;
    }) as CompilationUnit)
        .directives;
    ImportDirective reactImport = importList.firstWhere(
        (dir) => dir.toString().contains('package:react/react.dart'),
        orElse: () => null);

    if (reactImport != null) {
      int importNameLocation = reactImport.childEntities
              .toList()
              .lastIndexWhere((i) => i.toString() == 'as') +
          1;

      if (importNameLocation != 0) {
        reactImportName =
            reactImport.childEntities.elementAt(importNameLocation).toString();
      }
    }

    // Update imported type.
    if (reactImportName != null &&
        node.toString() == '$reactImportName.Component') {
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

    String extendsName = node.extendsClause?.superclass?.name?.toString?.call();
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
      if (annotationRef.name.toString().contains('2')) return;
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

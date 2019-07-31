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
import '../util.dart';

/// Suggestor that renames all props and state classes to have the required `_$`
/// prefix.
///
/// If [includeMixins] is true, props and state mixins will also be renamed.
class ClassNameAndAnnotationMigrator extends GeneralizingAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  ClassNameAndAnnotationMigrator();

  Iterable<String> get migrateAnnotations =>
      overReact16AnnotationNamesToMigrate;

  @override
  visitClassDeclaration(ClassDeclaration node) {
    super.visitClassDeclaration(node);
    if (!node.metadata.any((m) =>
        migrateAnnotations.contains(m.name.name) ||
        overReact16AnnotationNames.contains(m.name.name))) {
      // Only looking for classes annotated with `@Props()`, `@State()`,
      // `@AbstractProps()`, or `@AbstractState()`. If [renameMixins] is true,
      // also includes `@PropsMixin()` and `@StateMixin()`.
      return;
    }

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

    if (node.extendsClause.superclass.name.toString() == 'UiComponent' ||
        node.extendsClause.superclass.name.toString() ==
            'UiStatefulComponent') {
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

@Component()
class Whatever extends UiComponent<bool> {}

class UiComponent<T> {}

class Component {
  const Component();
}

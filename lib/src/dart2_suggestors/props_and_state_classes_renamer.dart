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
import '../util.dart';

/// Suggestor that renames all props and state classes to have the required `_$`
/// prefix.
///
/// If [includeMixins] is true, props and state mixins will also be renamed.
class PropsAndStateClassesRenamer extends RecursiveAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  final bool renameMixins;

  PropsAndStateClassesRenamer({this.renameMixins = true});

  Iterable<String> get annotationNames => renameMixins
      ? overReactPropsStateAnnotationNames
      : overReactPropsStateNonMixinAnnotationNames;

  @override
  visitClassDeclaration(ClassDeclaration node) {
    super.visitClassDeclaration(node);
    if (!node.metadata.any((m) => annotationNames.contains(m.name.name))) {
      // Only looking for classes annotated with `@Props()`, `@State()`,
      // `@AbstractProps()`, or `@AbstractState()`. If [renameMixins] is true,
      // also includes `@PropsMixin()` and `@StateMixin()`.
      return;
    }
    final className = node.name.name;
    final expectedName = renamePropsOrStateClass(className);
    if (className != expectedName) {
      yieldPatch(
        node.name.offset,
        node.name.end,
        expectedName,
      );
    }
  }
}

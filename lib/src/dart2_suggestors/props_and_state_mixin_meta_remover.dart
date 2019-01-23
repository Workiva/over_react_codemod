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

/// Suggestor that removes the static `meta` field from every props and state
/// mixin class if it was added by the backwards-compatible version of the
/// Dart 2 upgrade codemod.
///
/// The meta field was only necessary for Dart 1 compatibility; if props and
/// state mixin classes are prefixed with `_$`, the builder will generate the
/// prefix-stripped version that will contain this static meta field.
class PropsAndStateMixinMetaRemover extends RecursiveAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  @override
  visitClassDeclaration(ClassDeclaration node) {
    // Only looking for @PropsMixin() and @StateMixin() classes.
    final isOverReactMixin = node.metadata.any((annotation) {
      return overReactMixinAnnotationNames.contains(annotation.name.name);
    });
    if (!isOverReactMixin) {
      return;
    }

    final metaField = node.getField('meta');
    if (metaField == null || metaField.initializer == null) {
      return;
    }

    // The ignore comment on the meta field isn't included in the field
    // declaration node, so we need to explicitly check for it on the preceding
    // line and remove that line as well if found.
    var startOffset = metaField
        // Parent is the VariableDeclarationList
        .parent
        // Grandparent is the FieldDeclaration
        .parent
        // Using this offset includes the type and the `static` keyword.
        .offset;
    final declLine = sourceFile.getLine(startOffset);
    final precedingLine = sourceFile.getText(
      sourceFile.getOffset(declLine - 1),
      sourceFile.getOffset(declLine) - 1,
    );

    if (precedingLine.contains('// ignore:')) {
      startOffset = sourceFile.getOffset(declLine - 1);
    }

    // The +1 here includes the semicolon after the initializer.
    var endOffset = metaField.initializer.end + 1;

    // Remove the trailing newline if there is one.
    if (sourceFile.getText(endOffset, endOffset + 1) == '\n') {
      endOffset++;
    }

    yieldPatch(startOffset, endOffset, '');
  }
}

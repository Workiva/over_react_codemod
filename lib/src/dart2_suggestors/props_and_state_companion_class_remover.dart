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

/// Suggestor that removes every companion class for props and state classes, as
/// they were only temporarily required for backwards-compatibility with Dart 1.
class PropsAndStateCompanionClassRemover extends RecursiveAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  bool shouldRemoveCompanionClassFor(
          ClassDeclaration candidate, CompilationUnit node) =>
      true;

  @override
  visitCompilationUnit(CompilationUnit node) {
    final classDeclarations = node.declarations.whereType<ClassDeclaration>();
    for (final cd in classDeclarations) {
      final companionClass = _getCompanionClassFor(cd, node);

      if (companionClass != null && shouldRemoveCompanionClassFor(cd, node)) {
        // The single-line comment about the companion class being temporary
        // isn't associated with the class declaration node, so we need to
        // explicitly check for it on the preceding line and remove that line
        // as well if found.
        final declLine = sourceFile.getLine(companionClass.offset);
        final precedingLines = [
          sourceFile.getText(
            sourceFile.getOffset(declLine - 2),
            sourceFile.getOffset(declLine) - 2,
          ),
          sourceFile.getText(
            sourceFile.getOffset(declLine - 1),
            sourceFile.getOffset(declLine) - 1,
          ),
        ];
        var startOffset = companionClass.offset;
        for (var i = 0; i < precedingLines.length; i++) {
          final lineDelta = 2 - i;
          final line = precedingLines[i];
          if (line.contains(temporaryCompanionClassComment)) {
            startOffset = sourceFile.getOffset(declLine - lineDelta);
            break;
          }
        }

        yieldPatch(
          startOffset,
          companionClass.rightBracket.offset + 1,
          '',
        );
      }
    }
  }

  ClassDeclaration _getCompanionClassFor(
      ClassDeclaration classDeclaration, CompilationUnit node) {
    final classDeclarations = node.declarations.whereType<ClassDeclaration>();

    if (classDeclaration.metadata.any((m) =>
        overReactPropsStateNonMixinAnnotationNames.contains(m.name.name))) {
      final className = classDeclaration.name.name;
      final companionClassName = stripPrivateGeneratedPrefix(className);
      final companionClass = classDeclarations.firstWhere(
          (cd) => cd.name.name == companionClassName,
          orElse: () => null);
      return companionClass;
    }

    return null;
  }
}

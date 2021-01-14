// Copyright 2021 Workiva Inc.
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
import 'package:over_react_codemod/src/dart2_9_suggestors/dart2_9_constants.dart';
import 'package:over_react_codemod/src/util.dart';

import 'dart2_9_utilities.dart';

/// Suggestor that wraps generated factories (both in factory declarations and
/// connected components) with the `castUiFactory` function.
class GeneratedFactoryMigrator extends RecursiveAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  @override
  visitArgumentList(ArgumentList node) {
    super.visitArgumentList(node);

    final generatedArg = getGeneratedFactoryArg(node);
    if (generatedArg == null) return;

    final method = generatedArg.thisOrAncestorOfType<MethodInvocation>();
    if (method != null && method.methodName.name == castFunctionName) {
      return;
    }

    yieldPatch(generatedArg.offset, generatedArg.offset, '$castFunctionName(');
    yieldPatch(generatedArg.end, generatedArg.end, ')');
  }

  @override
  visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    super.visitTopLevelVariableDeclaration(node);

    // Update only if the factory declaration is in the new boilerplate syntax.
    if (isClassComponentFactory(node) && !isLegacyFactoryDecl(node)) {
      final initializer = node.variables?.variables?.first?.initializer;
      if (initializer is SimpleIdentifier) {
        yieldPatch(
            initializer.offset, initializer.offset, '$castFunctionName(');
        yieldPatch(initializer.end, initializer.end, ')');
      }
    }
  }

  @override
  bool shouldSkip(String sourceText) => shouldSkipParsingErrors(sourceText);
}

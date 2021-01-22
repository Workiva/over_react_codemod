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
  visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    super.visitTopLevelVariableDeclaration(node);

    // Update only if the factory declaration is in the new boilerplate syntax.
    if (isClassOrConnectedComponentFactory(node) &&
        !isLegacyFactoryDecl(node)) {
      final generatedFactory = getGeneratedFactory(node);
      if (generatedFactory
              .thisOrAncestorOfType<MethodInvocation>()
              ?.methodName
              ?.name ==
          castFunctionName) return;

      yieldPatch(generatedFactory.offset, generatedFactory.offset,
          '$castFunctionName(');
      yieldPatch(generatedFactory.end, generatedFactory.end, ')');
    }
  }

  @override
  bool shouldSkip(String sourceText) => hasParseErrors(sourceText);
}

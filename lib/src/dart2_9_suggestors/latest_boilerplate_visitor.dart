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

/// Visitor used to indicate if a codebase has already started adopting the Dart
/// >=2.9.0 boilerplate.
///
/// This makes no suggested patches, but will change [detectedLatestBoilerplate]
/// to `true` if new boilerplate is found.
class LatestBoilerplateVisitor extends RecursiveAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  bool detectedLatestBoilerplate = false;

  @override
  visitArgumentList(ArgumentList node) {
    super.visitArgumentList(node);

    // Short circuit if the latest usage has already been detected.
    if (detectedLatestBoilerplate) return;

    final generatedArg = getGeneratedFactoryConfigArg(node);
    if (generatedArg == null) return;

    if (generatedArg.name.startsWith('_')) {
      detectedLatestBoilerplate = true;
    }
  }

  @override
  visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    super.visitTopLevelVariableDeclaration(node);

    // Short circuit if the latest usage has already been detected.
    if (detectedLatestBoilerplate) return;

    if (isClassOrConnectedComponentFactory(node) &&
        !isLegacyFactoryDecl(node)) {
      final generatedFactory = getGeneratedFactory(node);
      final parentMethod = generatedFactory?.parent?.parent;
      if (parentMethod is MethodInvocation &&
          parentMethod.methodName?.name == castFunctionName) {
        detectedLatestBoilerplate = true;
      }
    }
  }

  @override
  bool shouldSkip(String sourceText) => hasParseErrors(sourceText);
}

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
import 'package:over_react_codemod/src/util.dart';

import 'dart2_9_utilities.dart';

/// Suggestor that adds the private prefix to generated factory configs in
/// preparation for Dart 2.12 when all names beginning with the `_$` prefix are
/// assumed to be generated.
class FactoryConfigMigrator extends RecursiveAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  @override
  visitArgumentList(ArgumentList node) {
    super.visitArgumentList(node);

    final generatedArg = getGeneratedFactoryConfigArg(node);
    if (generatedArg == null) return;

    if (!generatedArg.name.startsWith('_')) {
      yieldPatch(generatedArg.offset, generatedArg.offset, '_');
    }
  }

  @override
  bool shouldSkip(String sourceText) => hasParseErrors(sourceText);
}

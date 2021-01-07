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

import 'dart2_9_utilities.dart';

/// Suggestor that removes `// ignore: undefined_identifier` comments from
/// component factory declarations and factory config arguments.
class GeneratedFactoryMigrator extends RecursiveAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {

  @override
  visitArgumentList(ArgumentList node) {
    super.visitArgumentList(node);

    final generatedArg = getGeneratedArg(node);
    if(generatedArg == null) return;

    String typeName;

    final variableList = generatedArg.thisOrAncestorOfType<VariableDeclarationList>();
    final type = variableList?.type;
    if(type is TypeName && type.name.name == 'UiFactory') {
      typeName = type.toSource();
    }

    final method = generatedArg.thisOrAncestorOfType<MethodInvocation>();
    final propsType = method?.typeArguments?.arguments?.firstWhere((type) => type is TypeName && type.name.name.endsWith('Props'));
    if(propsType != null && method.typeArguments.arguments.length == 1) {
      typeName = 'UiFactory<$propsType>';
    }

    if(!generatedArg.name.startsWith('_')) {
      yieldPatch(generatedArg.offset, generatedArg.offset, '_');
    }
    if(typeName != null) {
      yieldPatch(generatedArg.end, generatedArg.end, ' as $typeName');
    }
  }
}

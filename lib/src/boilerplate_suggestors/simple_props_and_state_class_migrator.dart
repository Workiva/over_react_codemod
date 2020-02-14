// Copyright 2020 Workiva Inc.
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

import 'boilerplate_utilities.dart';

/// Suggestor that updates props and state classes to new boilerplate.
///
/// This should only be done on cases where the props and state classes are simple
/// extensions from `UiProps` or `UiState`.
///
/// Note: This should not operate on a class that uses mixins or does not extend
/// from `UiProps` or `UiState`.
class SimplePropsAndStateClassMigrator extends GeneralizingAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  final ClassToMixinConverter converter;

  SimplePropsAndStateClassMigrator(this.converter);

  @override
  visitClassDeclaration(ClassDeclaration node) {
    super.visitClassDeclaration(node);

    if (!shouldMigrateSimplePropsAndStateClass(node)) return;

    converter.migrate(node, yieldPatch, sourceFile: sourceFile);
  }
}

bool shouldMigrateSimplePropsAndStateClass(ClassDeclaration node) =>
    shouldMigratePropsAndStateClass(node) && isSimplePropsOrStateClass(node);

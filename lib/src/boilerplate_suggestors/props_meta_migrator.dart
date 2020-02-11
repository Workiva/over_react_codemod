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
import 'package:over_react_codemod/src/boilerplate_suggestors/boilerplate_utilities.dart';

/// Suggestor that looks for `meta` getter access on props classes found within
/// [convertedClassNames] as a result of being converted to the new
/// boilerplate via `SimplePropsAndStateClassMigrator` or `AdvancedPropsAndStateClassMigrator`, and converts
/// them to the way meta is accessed using the new boilerplate.
///
/// ```dart
/// // Before
/// FooProps.meta
///
/// // After
/// propsMeta.forMixin(FooProps)
/// ```
///
/// > Related: [PropsMixinMigrator]
class PropsMetaMigrator extends GeneralizingAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  final ClassToMixinConverter converter;

  PropsMetaMigrator(this.converter);

  // Utility to keep track of when a `const` keyword is removed from the left side of a `TypedLiteral`
  // so that we can prevent "overlapping" patches when a literal contains more than one `PrefixedIdentifier`
  // - which causes the codemod script to crash.
  static final Map<TypedLiteral, bool> _literalsWithConstRemoved = {};

  @override
  visitPrefixedIdentifier(PrefixedIdentifier node) {
    super.visitPrefixedIdentifier(node);

    if (node.identifier.name == 'meta') {
      if (converter.convertedClassNames.containsKey(node.prefix.name)) {
        yieldPatch(
          node.prefix.offset,
          node.identifier.end,
          'propsMeta.forMixin(${converter.convertedClassNames[node.prefix.name]})',
        );

        if (node.parent is TypedLiteral) {
          // The meta is being used in a literal
          TypedLiteral parent = node.parent;
          if (parent.isConst) {
            if (_literalsWithConstRemoved[parent] == true) return;

            if (parent.constKeyword != null) {
              _literalsWithConstRemoved[parent] = true;
              // The `const` keyword exists as part of the literal expression
              yieldPatch(
                  parent.constKeyword.offset, parent.constKeyword.end, '');
            }

            // Check for the const keyword in the variable declaration as well
            // since `isConst` can be true as a result of left-side constant context.
            if (parent.parent is VariableDeclaration) {
              _removeConstKeywordFromLeftSideOfVariableDeclaration(
                  parent.parent.parent);
            }
          }
        } else if (node.parent is VariableDeclaration) {
          _removeConstKeywordFromLeftSideOfVariableDeclaration(
              node.parent.parent);
        }
      }
    }
  }

  void _removeConstKeywordFromLeftSideOfVariableDeclaration(
      VariableDeclarationList decl,
      {String replaceWith = 'final'}) {
    if (!decl.isConst) return;
    yieldPatch(decl.keyword.offset, decl.keyword.end, replaceWith);
  }
}

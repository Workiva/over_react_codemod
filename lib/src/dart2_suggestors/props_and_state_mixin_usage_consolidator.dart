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

/// Suggestor that rewrites every usage pair of a props or state mixin to remove
/// the `$`-prefixed generated version and consolidate to the original.
class PropsAndStateMixinUsageConsolidator extends RecursiveAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  @override
  visitWithClause(WithClause node) {
    final allMixins = node.mixinTypes.map((n) => n.name.name);
    final targetMixins = allMixins
        // Only select mixin types that are _likely_ over_react mixins.
        .where((n) => n.endsWith('PropsMixin') || n.endsWith('StateMixin'))
        // Select mixin types that were added via this codemod.
        .where((n) => n.startsWith(generatedPrefix))
        // Filter out those that do not have a corresponding pair.
        .where((n) => allMixins.contains(n.substring(generatedPrefix.length)));

    if (targetMixins.isEmpty) {
      return;
    }

    for (var i = 0; i < node.mixinTypes.length; i++) {
      final mixinType = node.mixinTypes[i];
      if (targetMixins.contains(mixinType.name.name)) {
        yieldPatch(
          // The mixin type needs to be removed, but the ignore comment on the
          // line before and the comma after the previous mixin type both need
          // to be removed as well.
          node.mixinTypes[i - 1].end,
          mixinType.end,
          '',
        );
      }
    }
  }
}

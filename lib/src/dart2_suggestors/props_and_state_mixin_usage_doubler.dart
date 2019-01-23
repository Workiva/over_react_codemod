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
import '../util.dart';

final _mixinIgnoreComment = buildIgnoreComment(
  mixinOfNonClass: true,
  undefinedClass: true,
);

/// Suggestor that rewrites every usage of a props or state mixin to be a mixin
/// of a pair of mixins, one of which is a `$`-prefixed generated version that
/// is provided by the transformer or the builder.
///
/// Note that this suggestor attempts to find all relevant mixin usages naively
/// by the naming convention of props and state mixins ending in `PropsMixin`
/// and `StateMixin`, respectively. Because of this, it is possible that this
/// suggestor will hit a false positive and suggest a change that is not needed.
/// In this scenario, consumers should add an ignore comment to the mixin usage
/// like so:
///     class Foo extends Object
///         with
///             // orcm_ignore
///             DebounceStateMixin {}
// TODO: Can we use an ElementVisitor to definitively determine whether a mixin type is an over_react mixin? Otherwise we will hit false positives (e.g. `DebounceStateMixin`)
class PropsAndStateMixinUsageDoubler extends RecursiveAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  @override
  visitWithClause(WithClause node) {
    final allMixins = node.mixinTypes.map((n) => n.name.name);
    final targetMixins = node.mixinTypes
        .map((n) => n.name.name)
        // Ignore mixin types that were added already via this codemod.
        .where((n) => !n.startsWith(generatedPrefix))
        // Only select mixin types that are _likely_ over_react mixins.
        .where((n) => n.endsWith('PropsMixin') || n.endsWith('StateMixin'))
        // Filter out those that already have a `$`-prefixed partner.
        .where((n) => !allMixins.contains(generatedPrefix + n));

    if (targetMixins.isEmpty) {
      return;
    }

    for (final mixinType in node.mixinTypes) {
      if (targetMixins.contains(mixinType.name.name)) {
        final typeArgs = mixinType.typeArguments?.toSource() ?? '';
        yieldPatch(
          mixinType.end,
          mixinType.end,
          [
            ',',
            '    $_mixinIgnoreComment',
            '    ${generatedPrefix}${mixinType.name.name}$typeArgs',
          ].join('\n'),
        );
      }
    }
  }
}

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

@TestOn('vm')
import 'package:codemod/codemod.dart';
import 'package:mockito/mockito.dart';
import 'package:over_react_codemod/src/boilerplate_suggestors/factory_ignore_comment_mover.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'package:over_react_codemod/src/dart2_suggestors/component_default_props_migrator.dart';
import 'package:over_react_codemod/src/dart2_suggestors/dollar_prop_keys_migrator.dart';
import 'package:over_react_codemod/src/dart2_suggestors/dollar_props_migrator.dart';
import 'package:over_react_codemod/src/dart2_suggestors/needs_over_react_library_collector.dart';
import 'package:over_react_codemod/src/dart2_suggestors/generated_part_directive_adder.dart';
import 'package:over_react_codemod/src/dart2_suggestors/generated_part_directive_ignore_remover.dart';
import 'package:over_react_codemod/src/dart2_suggestors/orcm_ignore_remover.dart';
import 'package:over_react_codemod/src/dart2_suggestors/props_and_state_classes_renamer.dart';
import 'package:over_react_codemod/src/dart2_suggestors/props_and_state_companion_class_adder.dart';
import 'package:over_react_codemod/src/dart2_suggestors/props_and_state_companion_class_remover.dart';
import 'package:over_react_codemod/src/dart2_suggestors/props_and_state_mixin_meta_adder.dart';
import 'package:over_react_codemod/src/dart2_suggestors/props_and_state_mixin_meta_remover.dart';
import 'package:over_react_codemod/src/dart2_suggestors/props_and_state_mixin_usage_consolidator.dart';
import 'package:over_react_codemod/src/dart2_suggestors/props_and_state_mixin_usage_doubler.dart';
import 'package:over_react_codemod/src/dart2_suggestors/ui_factory_ignore_comment_remover.dart';
import 'package:over_react_codemod/src/dart2_suggestors/ui_factory_initializer.dart';
import 'package:over_react_codemod/src/ignoreable.dart';

import 'util.dart';

class MockCollector extends Mock implements NeedsOverReactLibraryCollector {}

void main() {
  group('Dart2 migration suggestors', () {
    // In the `.suggestor_test` for this suggestor, the tests are written with
    // the assumption that any library with a name of `match` or a path of
    // `match.dart` needs the part directive, and this setup is why that works.
    final mockCollector = MockCollector();
    when(mockCollector.byName).thenReturn(['match']);
    when(mockCollector.byPath)
        .thenAnswer((_) => [p.canonicalize(p.join(d.sandbox, 'match.dart'))]);
    final generatedPartDirectiveAdder =
        ignoreable(GeneratedPartDirectiveAdder(mockCollector));

    final suggestorMap = <String, Suggestor>{
      'ComponentDefaultPropsMigrator': ignoreable(
        componentDefaultPropsMigrator,
      ),
      'DollarPropKeysMigrator': ignoreable(
        dollarPropKeysMigrator,
      ),
      'DollarPropsMigrator': ignoreable(
        dollarPropsMigrator,
      ),
      'GeneratedPartDirectiveAdder': generatedPartDirectiveAdder,
      'GeneratedPartDirectiveIgnoreRemover':
          GeneratedPartDirectiveIgnoreRemover(),
      'OrcmIgnoreRemover': orcmIgnoreRemover,
      'PropsAndStateClassesRenamer': ignoreable(
        PropsAndStateClassesRenamer(renameMixins: true),
      ),
      'PropsAndStateClassesRenamerNoMixins': ignoreable(
        PropsAndStateClassesRenamer(renameMixins: false),
      ),
      'PropsAndStateCompanionClassAdder': ignoreable(
        PropsAndStateCompanionClassAdder(),
      ),
      'PropsAndStateCompanionClassAdderWithCommentPrefix': ignoreable(
        PropsAndStateCompanionClassAdder(commentPrefix: 'PREFIX: '),
      ),
      'PropsAndStateCompanionClassRemover': ignoreable(
        PropsAndStateCompanionClassRemover(),
      ),
      'PropsAndStateMixinMetaAdder': ignoreable(
        PropsAndStateMixinMetaAdder(),
      ),
      'PropsAndStateMixinMetaRemover': ignoreable(
        PropsAndStateMixinMetaRemover(),
      ),
      'PropsAndStateMixinUsageConsolidator': ignoreable(
        PropsAndStateMixinUsageConsolidator(),
      ),
      'PropsAndStateMixinUsageDoubler': ignoreable(
        PropsAndStateMixinUsageDoubler(),
      ),
      'UiFactoryIgnoreCommentRemover': ignoreable(
        UiFactoryIgnoreCommentRemover(),
      ),
      'UiFactoryInitializer': ignoreable(
        UiFactoryInitializer(includeIgnore: false),
      ),
      'UiFactoryInitializerIncludeIgnore': ignoreable(
        UiFactoryInitializer(includeIgnore: true),
      ),
    };
    testSuggestorsDir(suggestorMap, 'test/dart2_suggestors');
  });

  group('Boilerplate suggestors', () {
    final suggestorMap = {
      'FactoryIgnoreCommentMover': ignoreable(
        FactoryIgnoreCommentMover(),
      ),
    };
    testSuggestorsDir(suggestorMap, 'test/boilerplate_suggestors');
  });
}

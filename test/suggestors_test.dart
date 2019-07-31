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
import 'package:mockito/mockito.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

// Component 2
import 'package:over_react_codemod/src/component2_suggestors/componentwillmount_migrator.dart';
import 'package:over_react_codemod/src/component2_suggestors/class_name_and_annotation_migrator.dart';

// Dart 2
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
import 'package:over_react_codemod/src/dart2_suggestors/pubspec_over_react_upgrader.dart';
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
    when(mockCollector.byPath).thenReturn([p.canonicalize('match.dart')]);
    final generatedPartDirectiveAdder =
        Ignoreable(GeneratedPartDirectiveAdder(mockCollector));

    final suggestorMap = {
      'ComponentDefaultPropsMigrator': Ignoreable(
        ComponentDefaultPropsMigrator(),
      ),
      'DollarPropKeysMigrator': Ignoreable(
        DollarPropKeysMigrator(),
      ),
      'DollarPropsMigrator': Ignoreable(
        DollarPropsMigrator(),
      ),
      'GeneratedPartDirectiveAdder': generatedPartDirectiveAdder,
      'GeneratedPartDirectiveIgnoreRemover':
          GeneratedPartDirectiveIgnoreRemover(),
      'OrcmIgnoreRemover': OrcmIgnoreRemover(),
      'PropsAndStateClassesRenamer': Ignoreable(
        PropsAndStateClassesRenamer(renameMixins: true),
      ),
      'PropsAndStateClassesRenamerNoMixins': Ignoreable(
        PropsAndStateClassesRenamer(renameMixins: false),
      ),
      'PropsAndStateCompanionClassAdder': Ignoreable(
        PropsAndStateCompanionClassAdder(),
      ),
      'PropsAndStateCompanionClassAdderWithCommentPrefix': Ignoreable(
        PropsAndStateCompanionClassAdder(commentPrefix: 'PREFIX: '),
      ),
      'PropsAndStateCompanionClassRemover': Ignoreable(
        PropsAndStateCompanionClassRemover(),
      ),
      'PropsAndStateMixinMetaAdder': Ignoreable(
        PropsAndStateMixinMetaAdder(),
      ),
      'PropsAndStateMixinMetaRemover': Ignoreable(
        PropsAndStateMixinMetaRemover(),
      ),
      'PropsAndStateMixinUsageConsolidator': Ignoreable(
        PropsAndStateMixinUsageConsolidator(),
      ),
      'PropsAndStateMixinUsageDoubler': Ignoreable(
        PropsAndStateMixinUsageDoubler(),
      ),
      'PubspecOverReactUpgrader': PubspecOverReactUpgrader(
        PubspecOverReactUpgrader.dart2Constraint,
      ),
      'UiFactoryIgnoreCommentRemover': Ignoreable(
        UiFactoryIgnoreCommentRemover(),
      ),
      'UiFactoryInitializer': Ignoreable(
        UiFactoryInitializer(includeIgnore: false),
      ),
      'UiFactoryInitializerIncludeIgnore': Ignoreable(
        UiFactoryInitializer(includeIgnore: true),
      ),
    };
    testSuggestorsDir(suggestorMap, 'test/dart2_suggestors');
  });

  group('Component2 migration suggestors', () {
    // In the `.suggestor_test` for this suggestor, the tests are written with
    // the assumption that any library with a name of `match` or a path of
    // `match.dart` needs the part directive, and this setup is why that works.
    final mockCollector = MockCollector();
    when(mockCollector.byName).thenReturn(['match']);
    when(mockCollector.byPath).thenReturn([p.canonicalize('match.dart')]);
    final generatedPartDirectiveAdder =
        Ignoreable(GeneratedPartDirectiveAdder(mockCollector));

    final suggestorMap = {
      'ClassNameAndAnnotationMigrator': Ignoreable(
        ClassNameAndAnnotationMigrator(),
      ),
      'ComponentWillMountMigrator': Ignoreable(
        ComponentWillMountMigrator(),
      ),
    };
    testSuggestorsDir(suggestorMap, 'test/component2_suggestors');
  });
}

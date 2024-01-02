// Copyright 2024 Workiva Inc.
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

import 'package:over_react_codemod/src/null_safety_migration_suggestors/callback_ref_hint_suggestor.dart';
import 'package:test/test.dart';

import '../resolved_file_context.dart';
import '../util.dart';

void main() {
  final resolvedContext = SharedAnalysisContext.wsd;

  // Warm up analysis in a setUpAll so that if getting the resolved AST times out
  // (which is more common for the WSD context), it fails here instead of failing the first test.
  setUpAll(resolvedContext.warmUpAnalysis);

  group('MuiButtonToolbarMigrator', () {
    final testSuggestor = getSuggestorTester(
      CallbackRefHintSuggestor(),
      resolvedContext: resolvedContext,
    );

    group('migrates WSD ButtonToolbars', () {
      test('that are either unnamespaced or namespaced, and either v1 or v2',
          () async {
        await testSuggestor(
          input:/*language=dart*/ '''
              import 'dart:html';
        
              import 'package:over_react/over_react.dart';
              import 'package:web_skin_dart/component2/all.dart';
              
              content() {
                var ref;
                (ButtonToolbar()..ref = (ButtonElement r) => ref = r)();
                (ButtonToolbar()..ref = (r) => ref = r as ButtonElement)();
                (ButtonToolbar()..ref = (ButtonElement r) { ref = r; })();
                (ButtonToolbar()..ref = (r) { ref = r as ButtonElement; })();
                ref;
              }
          ''',
          // todo add block function, and other test cases, non-ref prop names
          expectedOutput: /*language=dart*/ '''
              import 'dart:html';
        
              import 'package:over_react/over_react.dart';
              import 'package:web_skin_dart/component2/all.dart';
              
              content() {
                var ref;
                (ButtonToolbar()..ref = (ButtonElement /*?*/ r) => ref = r)();
                (ButtonToolbar()..ref = (r) => ref = r as ButtonElement /*?*/)();
                (ButtonToolbar()..ref = (ButtonElement /*?*/ r) { ref = r; })();
                (ButtonToolbar()..ref = (r) { ref = r as ButtonElement /*?*/; })();
                ref;
              }
          ''',
        );
      });


    });
  });
}

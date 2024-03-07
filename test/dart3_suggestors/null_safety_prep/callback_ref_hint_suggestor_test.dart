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

import 'package:over_react_codemod/src/dart3_suggestors/null_safety_prep/callback_ref_hint_suggestor.dart';
import 'package:test/test.dart';

import '../../mui_suggestors/components/shared.dart';
import '../../resolved_file_context.dart';
import '../../util.dart';

// todo add block function, and other test cases, non-ref prop names, mui/dom usages

void main() {
  final resolvedContext = SharedAnalysisContext.wsd;

  // Warm up analysis in a setUpAll so that if getting the resolved AST times out
  // (which is more common for the WSD context), it fails here instead of failing the first test.
  setUpAll(resolvedContext.warmUpAnalysis);

  group('CallbackRefHintSuggestor', () {
    final testSuggestor = getSuggestorTester(
      CallbackRefHintSuggestor(),
      resolvedContext: resolvedContext,
    );

    group('adds nullability hint to ref prop typed parameters', () {
      test('', () async {
        await testSuggestor(
          input: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                var ref;
                (ButtonToolbar()..ref = (ButtonElement r) => ref = r)();
                (ButtonToolbar()..ref = (ButtonElement r) { ref = r; })();
                ref;
              }
          '''),
          expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                var ref;
                (ButtonToolbar()..ref = (ButtonElement /*?*/ r) => ref = r)();
                (ButtonToolbar()..ref = (ButtonElement /*?*/ r) { ref = r; })();
                ref;
              }
          '''),
        );
      });

      test('for builders', () async {
        await testSuggestor(
          input: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                var ref;
                (ButtonToolbar()..ref = (ButtonElement r) => ref = r);
                (ButtonToolbar()..ref = (ButtonElement r) { ref = r; });
                ref;
              }
          '''),
          expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                var ref;
                (ButtonToolbar()..ref = (ButtonElement /*?*/ r) => ref = r);
                (ButtonToolbar()..ref = (ButtonElement /*?*/ r) { ref = r; });
                ref;
              }
          '''),
        );
      });
    });

    group('adds nullability hint to casts in a callback ref body', () {
      test('', () async {
        await testSuggestor(
          input: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                var ref;
                (ButtonToolbar()..ref = (r) => ref = r as ButtonElement)();
                (ButtonToolbar()..ref = (r) { ref = r as ButtonElement; })();
                ref;
              }
          '''),
          expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                var ref;
                (ButtonToolbar()..ref = (r) => ref = r as ButtonElement /*?*/)();
                (ButtonToolbar()..ref = (r) { ref = r as ButtonElement /*?*/; })();
                ref;
              }
          '''),
        );
      });

      test('for builders', () async {
        await testSuggestor(
          input: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                var ref;
                (ButtonToolbar()..ref = (r) => ref = r as ButtonElement);
                (ButtonToolbar()..ref = (r) { ref = r as ButtonElement; });
                ref;
              }
          '''),
          expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                var ref;
                (ButtonToolbar()..ref = (r) => ref = r as ButtonElement /*?*/);
                (ButtonToolbar()..ref = (r) { ref = r as ButtonElement /*?*/; });
                ref;
              }
          '''),
        );
      });

      test('only for casts of the ref param', () async {
        await testSuggestor(
          input: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                var ref;
                final a = 1;
                (ButtonToolbar()
                  ..ref = (r) { 
                    ref = r as int; 
                    ref = a as ButtonElement;
                    ref as int;
                    ref = r as ButtonElement;
                })();
                (ButtonToolbar()
                  ..ref = (ButtonElement r) { 
                    ref = r as int; 
                    ref = a as ButtonElement;
                })();
                (ButtonToolbar()..ref = (ButtonElement r) => ref = a as ButtonElement)();
                (ButtonToolbar()..ref = (_) => ref = a as ButtonElement)();
                ref;
              }
          '''),
          expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                var ref;
                final a = 1;
                (ButtonToolbar()
                  ..ref = (r) { 
                    ref = r as int /*?*/; 
                    ref = a as ButtonElement;
                    ref as int;
                    ref = r as ButtonElement /*?*/;
                })();
                (ButtonToolbar()
                  ..ref = (ButtonElement /*?*/ r) { 
                    ref = r as int /*?*/; 
                    ref = a as ButtonElement;
                })();
                (ButtonToolbar()..ref = (ButtonElement /*?*/ r) => ref = a as ButtonElement)();
                (ButtonToolbar()..ref = (_) => ref = a as ButtonElement)();
                ref;
              }
          '''),
        );
      });
    });

    group('adds nullability hint to class ref variables', () {
      test('', () async {
        await testSuggestor(
          input: withOverReactAndWsdImports(/*language=dart*/ '''
              ButtonElement ref5;
              content() {
                ButtonElement ref2;
                ButtonElement ref4;
                (ButtonToolbar()..ref = (r) => ref5 = r)();
                (ButtonToolbar()..ref = (r) {
                  ButtonElement ref3;
                  ref2 = r;
                  ref3 = r as ButtonElement;
                  final a = ButtonElement();
                  ref4 = a;
                  ref3;
                });
                ref5;
                ref2;
                ref4;
              }
          '''),
          expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                ButtonElement /*?*/ ref5;
                ButtonElement /*?*/ ref2;
                ButtonElement ref4;
                (ButtonToolbar()..ref = (r) => ref5 = r)();
                (ButtonToolbar()..ref = (r) {
                  ButtonElement /*?*/ ref3;
                  ref2 = r;
                  ref3 = r as ButtonElement /*?*/;
                  final a = 1;
                  ref4 = a;
                });
                ref5;
                ref2;
                ref3;
                ref4;
              }
          '''),
        );
      });
    });

    test('does not add hints if they already exist', () async {
      await testSuggestor(
        input: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                var ref;
                (ButtonToolbar()..ref = (ButtonElement /*?*/ r) => ref = r)();
                (ButtonToolbar()..ref = (r) { ref = r as ButtonElement /*?*/; })();
                ref;
              }
          '''),
        expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                var ref;
                (ButtonToolbar()..ref = (ButtonElement /*?*/ r) => ref = r)();
                (ButtonToolbar()..ref = (r) { ref = r as ButtonElement /*?*/; })();
                ref;
              }
          '''),
      );
    });
  });
}

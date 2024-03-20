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
                (Dom.div()..ref = (ButtonElement r) { ref = r; })();
                ref;
              }
          '''),
          expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                var ref;
                (ButtonToolbar()..ref = (ButtonElement /*?*/ r) => ref = r)();
                (Dom.div()..ref = (ButtonElement /*?*/ r) { ref = r; })();
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
                (Dom.div()..ref = (ButtonElement r) { ref = r; });
                ref;
              }
          '''),
          expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                var ref;
                (ButtonToolbar()..ref = (ButtonElement /*?*/ r) => ref = r);
                (Dom.div()..ref = (ButtonElement /*?*/ r) { ref = r; });
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
                (Dom.div()..ref = (r) { ref = r as ButtonElement; })();
                ref;
              }
          '''),
          expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                var ref;
                (ButtonToolbar()..ref = (r) => ref = r as ButtonElement /*?*/)();
                (Dom.div()..ref = (r) { ref = r as ButtonElement /*?*/; })();
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
                (Dom.div()..ref = (r) { ref = r as ButtonElement; });
                ref;
              }
          '''),
          expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                var ref;
                (ButtonToolbar()..ref = (r) => ref = r as ButtonElement /*?*/);
                (Dom.div()..ref = (r) { ref = r as ButtonElement /*?*/; });
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
                (Dom.div()
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
                (Dom.div()
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
              ButtonElement ref1;
              content() {
                ButtonElement ref2;
                ButtonElement ref3;
                (ButtonToolbar()..ref = (r) => ref1 = r)();
                (Dom.div()..ref = (r) {
                  ButtonElement ref4;
                  ref2 = r;
                  final a = ButtonElement();
                  ref3 = a;
                  ref4 = r;
                  ref4;
                });
                ref1;
                ref2;
                ref3;
              }
          '''),
          expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
              ButtonElement /*?*/ ref1;
              content() {
                ButtonElement /*?*/ ref2;
                ButtonElement ref3;
                (ButtonToolbar()..ref = (r) => ref1 = r)();
                (Dom.div()..ref = (r) {
                  ButtonElement /*?*/ ref4;
                  ref2 = r;
                  final a = ButtonElement();
                  ref3 = a;
                  ref4 = r;
                  ref4;
                });
                ref1;
                ref2;
                ref3;
              }
          '''),
        );
      });

      test('unless there is no type on the declaration', () async {
        await testSuggestor(
          input: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                dynamic ref1;
                var ref2;
                (ButtonToolbar()..ref = (r) {
                  ref1 = r;
                  ref2 = r;
                });
                ref1;
                ref2;
              }
          '''),
          expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                dynamic ref1;
                var ref2;
                (ButtonToolbar()..ref = (r) {
                  ref1 = r;
                  ref2 = r;
                });
                ref1;
                ref2;
              }
          '''),
        );
      });
    });

    test('does not add hints if they already exist', () async {
      await testSuggestor(
        input: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                ButtonElement /*?*/ ref;
                (ButtonToolbar()..ref = (ButtonElement /*?*/ r) => ref = r)();
                (Dom.div()..ref = (r) { ref = r as ButtonElement /*?*/; })();
                ref;
              }
          '''),
        expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                ButtonElement /*?*/ ref;
                (ButtonToolbar()..ref = (ButtonElement /*?*/ r) => ref = r)();
                (Dom.div()..ref = (r) { ref = r as ButtonElement /*?*/; })();
                ref;
              }
          '''),
      );
    });

    test('does not add hints for non-ref props', () async {
      await testSuggestor(
        input: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                ButtonElement ref;
                (ButtonToolbar()..onClick = (r) { ref = r as ButtonElement; })();
                ref;
              }
          '''),
        expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                ButtonElement ref;
                (ButtonToolbar()..onClick = (r) { ref = r as ButtonElement; })();
                ref;
              }
          '''),
      );
    });
  });
}

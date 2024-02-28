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

import 'package:over_react_codemod/src/dart3_suggestors/null_safety_prep/dom_callback_null_args.dart';
import 'package:test/test.dart';

import '../../resolved_file_context.dart';
import '../../util.dart';
import '../../util/component_usage_migrator_test.dart';

void main() {
  final resolvedContext = SharedAnalysisContext.overReact;

  // Warm up analysis in a setUpAll so that if getting the resolved AST times out
  // (which is more common for the WSD context), it fails here instead of failing the first test.
  setUpAll(resolvedContext.warmUpAnalysis);

  group('DomCallbackNullArgs', () {
    late SuggestorTester testSuggestor;

    setUp(() {
      testSuggestor = getSuggestorTester(
        DomCallbackNullArgs(),
        resolvedContext: resolvedContext,
      );
    });

    test(
        'leaves dom callbacks alone when a non-null value is passed as the first argument',
        () async {
      await testSuggestor(
        expectedPatchCount: 0,
        input: withOverReactImport('''
              main() {
                final props = domProps();
                props.onClick(createSyntheticMouseEvent());
                final onBlur = props.onBlur;
                onBlur(createSyntheticFocusEvent());
              }
            '''),
      );
    });

    test(
        'leaves functions alone when a null value is passed as the first argument if they are not dom callbacks',
        () async {
      await testSuggestor(
        expectedPatchCount: 0,
        input: withOverReactImport('''
              main() {
                void foo(dynamic arg) {}
                foo(null);
              }
            '''),
      );
    });

    group(
        'replaces null arg in dom callback with an empty synthetic event of the correct type: ',
        () {
      DomCallbackNullArgs.callbackToSyntheticEventTypeMap
          .forEach((callbackFnName, syntheticEventTypeName) {
        test(callbackFnName, () async {
          await testSuggestor(
            expectedPatchCount: 2,
            input: withOverReactImport('''
              main() {
                final props = domProps();
                props.${callbackFnName}(null);
                final ${callbackFnName} = props.${callbackFnName};
                ${callbackFnName}(null);
              }
            '''),
            expectedOutput: withOverReactImport('''
              main() {
                final props = domProps();
                props.${callbackFnName}(create${syntheticEventTypeName}());
                final ${callbackFnName} = props.${callbackFnName};
                ${callbackFnName}(create${syntheticEventTypeName}());
              }
            '''),
          );
        });
      });
    });
  });
}

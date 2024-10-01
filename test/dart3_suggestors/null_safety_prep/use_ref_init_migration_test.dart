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

import 'package:over_react_codemod/src/dart3_suggestors/null_safety_prep/use_ref_init_migration.dart';
import 'package:test/test.dart';

import '../../resolved_file_context.dart';
import '../../util.dart';
import '../../util/component_usage_migrator_test.dart';

void main() {
  final resolvedContext = SharedAnalysisContext.overReact;

  // Warm up analysis in a setUpAll so that if getting the resolved AST times out
  // (which is more common for the WSD context), it fails here instead of failing the first test.
  setUpAll(resolvedContext.warmUpAnalysis);

  group('UseRefInitMigration', () {
    late SuggestorTester testSuggestor;

    setUp(() {
      testSuggestor = getSuggestorTester(
        UseRefInitMigration(),
        resolvedContext: resolvedContext,
      );
    });

    test(
        'leaves useRef function invocations alone when the argument list is empty',
        () async {
      await testSuggestor(
        expectedPatchCount: 0,
        input: withOverReactImport('''
              final Foo = uiFunction<UiProps>(
                (props) {
                  final foo = useRef();
                  print(foo);
                  return null;
                },
                UiFactoryConfig(displayName: 'Foo'),
              );
            '''),
      );
    });

    test('replaces useRef usages with useRefInit when an argument is passed',
        () async {
      await testSuggestor(
        expectedPatchCount: 1,
        input: withOverReactImport('''
              final Foo = uiFunction<UiProps>(
                (props) {
                  final foo = useRef('bar');
                  return (Dom.div()..id = foo.current)();
                },
                UiFactoryConfig(displayName: 'Foo'),
              );
            '''),
        expectedOutput: withOverReactImport('''
              final Foo = uiFunction<UiProps>(
                (props) {
                  final foo = useRefInit('bar');
                  return (Dom.div()..id = foo.current)();
                },
                UiFactoryConfig(displayName: 'Foo'),
              );
            '''),
      );
    });

    test(
        'replaces useRef<Generic> usages with useRefInit<Generic> when an argument is passed',
        () async {
      await testSuggestor(
        expectedPatchCount: 1,
        input: withOverReactImport('''
              final Foo = uiFunction<UiProps>(
                (props) {
                  final foo = useRef<String>('bar');
                  return (Dom.div()..id = foo.current)();
                },
                UiFactoryConfig(displayName: 'Foo'),
              );
            '''),
        expectedOutput: withOverReactImport('''
              final Foo = uiFunction<UiProps>(
                (props) {
                  final foo = useRefInit<String>('bar');
                  return (Dom.div()..id = foo.current)();
                },
                UiFactoryConfig(displayName: 'Foo'),
              );
            '''),
      );
    });

    test('removes unnecessary null arguments', () async {
      await testSuggestor(
        expectedPatchCount: 2,
        input: withOverReactImport('''
              useTestHook() {
                final foo = useRef(null);
                final bar = useRef<String>(null);
                return [foo, bar];
              }
            '''),
        expectedOutput: withOverReactImport('''
              useTestHook() {
                final foo = useRef();
                final bar = useRef<String>();
                return [foo, bar];
              }
            '''),
      );
    });
  });
}

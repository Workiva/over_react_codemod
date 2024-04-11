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

import 'package:over_react_codemod/src/dart3_suggestors/null_safety_prep/fn_prop_null_aware_call_suggestor.dart';
import 'package:test/test.dart';

import '../../resolved_file_context.dart';
import '../../util.dart';
import '../../util/component_usage_migrator_test.dart';

void main() {
  final resolvedContext = SharedAnalysisContext.overReact;

  // Warm up analysis in a setUpAll so that if getting the resolved AST times out
  // (which is more common for the WSD context), it fails here instead of failing the first test.
  setUpAll(resolvedContext.warmUpAnalysis);

  group('FnPropNullAwareCallSuggestor', () {
    late SuggestorTester testSuggestor;

    setUp(() {
      testSuggestor = getSuggestorTester(
        FnPropNullAwareCallSuggestor(),
        resolvedContext: resolvedContext,
      );
    });

    group('handles block if conditions', () {
      test('with a single condition', () async {
        await testSuggestor(
            expectedPatchCount: 1,
            input: withOverReactImport('''
              final Foo = uiFunction<UiProps>(
                (props) {
                  final handleClick = useCallback<MouseEventCallback>((e) {
                    if (props.onClick != null) {
                      props.onClick(e);
                    }
                  }, [props.onClick]);
                  
                  return (Dom.button()..onClick = handleClick)();
                },
                UiFactoryConfig(displayName: 'Foo'),
              );
            '''),
            expectedOutput: withOverReactImport('''
              final Foo = uiFunction<UiProps>(
                (props) {
                  final handleClick = useCallback<MouseEventCallback>((e) {
                    props.onClick?.call(e);
                  }, [props.onClick]);
                  
                  return (Dom.button()..onClick = handleClick)();
                },
                UiFactoryConfig(displayName: 'Foo'),
              );
            '''));
      });

      test(
          'unless the single condition is not a null check of the function being called',
          () async {
        await testSuggestor(
          expectedPatchCount: 0,
          input: withOverReactImport('''
              final Foo = uiFunction<UiProps>(
                (props) {
                  final handleClick = useCallback<MouseEventCallback>((e) {
                    if (1 > 0) {
                      props.onClick(e);
                    }
                  }, [props.onClick]);
                  
                  return (Dom.button()..onClick = handleClick)();
                },
                UiFactoryConfig(displayName: 'Foo'),
              );
            '''),
        );
      });

      test('unless there is an else condition', () async {
        await testSuggestor(
          expectedPatchCount: 0,
          input: withOverReactImport('''
              final Foo = uiFunction<UiProps>(
                (props) {
                  final bar = useState(0);
                  final handleClick = useCallback<MouseEventCallback>((e) {
                    if (props.onClick != null) {
                      props.onClick(e);
                    } else {
                      bar.set(1);
                    }
                  }, [props.onClick]);
                  
                  return (Dom.button()..onClick = handleClick)(bar.value);
                },
                UiFactoryConfig(displayName: 'Foo'),
              );
            '''),
        );
      });

      test('unless there is an else if condition', () async {
        await testSuggestor(
          expectedPatchCount: 0,
          input: withOverReactImport('''
              final Foo = uiFunction<UiProps>(
                (props) {
                  final bar = useState(0);
                  final handleClick = useCallback<MouseEventCallback>((e) {
                    if (props.onMouseEnter != null) {
                      bar.set(1);
                    } else if (props.onClick != null) {
                      props.onClick(e);
                    }
                  }, [props.onClick]);
                  
                  return (Dom.button()..onClick = handleClick)(bar.value);
                },
                UiFactoryConfig(displayName: 'Foo'),
              );
            '''),
        );
      });

      test(
          'unless the single condition involves the function being called, but is not a null check',
          () async {
        await testSuggestor(
          expectedPatchCount: 0,
          input: withOverReactImport('''
              final Foo = uiFunction<UiProps>(
                (props) {
                  final handleClick = useCallback<MouseEventCallback>((e) {
                    if (props.onClick is Function) {
                      props.onClick(e);
                    }
                  }, [props.onClick]);
                  
                  return (Dom.button()..onClick = handleClick)();
                },
                UiFactoryConfig(displayName: 'Foo'),
              );
            '''),
        );
      });

      test('unless there are multiple conditions', () async {
        await testSuggestor(
          expectedPatchCount: 0,
          input: withOverReactImport('''
              final Foo = uiFunction<UiProps>(
                (props) {
                  final handleClick = useCallback<MouseEventCallback>((e) {
                    if (props.onClick != null && props.onMouseEnter != null) {
                      props.onClick(e);
                    }
                  }, [props.onClick]);
                  
                  return (Dom.button()..onClick = handleClick)();
                },
                UiFactoryConfig(displayName: 'Foo'),
              );
            '''),
        );
      });
    });

    group('handles inline if conditions', () {
      test('with a single condition', () async {
        await testSuggestor(
            expectedPatchCount: 1,
            input: withOverReactImport('''
              final Foo = uiFunction<UiProps>(
                (props) {
                  final handleClick = useCallback<MouseEventCallback>((e) {
                    if (props.onClick != null) props.onClick(e);
                  }, [props.onClick]);
                  
                  return (Dom.button()..onClick = handleClick)();
                },
                UiFactoryConfig(displayName: 'Foo'),
              );
            '''),
            expectedOutput: withOverReactImport('''
              final Foo = uiFunction<UiProps>(
                (props) {
                  final handleClick = useCallback<MouseEventCallback>((e) {
                    props.onClick?.call(e);
                  }, [props.onClick]);
                  
                  return (Dom.button()..onClick = handleClick)();
                },
                UiFactoryConfig(displayName: 'Foo'),
              );
            '''));
      });

      test(
          'unless the single condition is not a null check of the function being called',
          () async {
        await testSuggestor(
          expectedPatchCount: 0,
          input: withOverReactImport('''
              final Foo = uiFunction<UiProps>(
                (props) {
                  final handleClick = useCallback<MouseEventCallback>((e) {
                    if (1 > 0) props.onClick(e);
                  }, [props.onClick]);
                  
                  return (Dom.button()..onClick = handleClick)();
                },
                UiFactoryConfig(displayName: 'Foo'),
              );
            '''),
        );
      });

      test(
          'unless the single condition involves the function being called, but is not a null check',
          () async {
        await testSuggestor(
          expectedPatchCount: 0,
          input: withOverReactImport('''
              final Foo = uiFunction<UiProps>(
                (props) {
                  final handleClick = useCallback<MouseEventCallback>((e) {
                    if (props.onClick is Function) props.onClick(e);
                  }, [props.onClick]);
                  
                  return (Dom.button()..onClick = handleClick)();
                },
                UiFactoryConfig(displayName: 'Foo'),
              );
            '''),
        );
      });

      test('unless there are multiple conditions', () async {
        await testSuggestor(
          expectedPatchCount: 0,
          input: withOverReactImport('''
              final Foo = uiFunction<UiProps>(
                (props) {
                  final handleClick = useCallback<MouseEventCallback>((e) {
                    if (props.onClick != null && props.onMouseEnter != null) props.onClick(e);
                  }, [props.onClick]);
                  
                  return (Dom.button()..onClick = handleClick)();
                },
                UiFactoryConfig(displayName: 'Foo'),
              );
            '''),
        );
      });
    });
  });
}

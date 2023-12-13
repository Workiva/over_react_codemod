// Copyright 2023 Workiva Inc.
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

import 'package:over_react_codemod/src/dart3_suggestors/null_safety_prep/required_flux_props.dart';
import 'package:test/test.dart';

import '../../resolved_file_context.dart';
import '../../util.dart';
import '../../util/component_usage_migrator_test.dart';

void main() {
  final resolvedContext = SharedAnalysisContext.overReact;

  // Warm up analysis in a setUpAll so that if getting the resolved AST times out
  // (which is more common for the WSD context), it fails here instead of failing the first test.
  setUpAll(resolvedContext.warmUpAnalysis);

  group('RequiredFluxProps', () {
    late SuggestorTester testSuggestor;

    setUp(() {
      testSuggestor = getSuggestorTester(
        RequiredFluxProps(),
        resolvedContext: resolvedContext,
      );
    });

    test('leaves builders alone if they don\'t use FluxUiPropsMixin, '
        'even if they have props named store/actions', () async {
      await testSuggestor(
        isExpectedError: (err) => err.message.contains(RegExp(r'theStore|theActions')),
        expectedPatchCount: 0,
        input: withFluxComponentUsage(/*language=dart*/ r'''
          main() {
            final theStore = BazFooStore();
            final theActions = BazFooActions();

            return (NotFoo()
              ..id = '123'
            )();
          }
        '''),
      );
    });

    group('patches un-invoked builders that use FluxUiPropsMixin', () {
      group('and do not have props.actions set', () {
        test('no actions var in scope', () async {
          await testSuggestor(
            expectedPatchCount: 1,
            input: withFluxComponentUsage(/*language=dart*/ r'''
              main() {
                final theStore = FooStore();

                Foo()
                  ..store = theStore;
              }
            '''),
            expectedOutput: withFluxComponentUsage(/*language=dart*/ r'''
              main() {
                final theStore = FooStore();

                Foo()
                  ..actions = null
                  ..store = theStore;
              }
            '''),
          );
        });

        test('actions var in local fn scope with incorrect type', () async {
          await testSuggestor(
            isExpectedError: (err) => err.message.contains('theActions'),
            expectedPatchCount: 1,
            input: withFluxComponentUsage(/*language=dart*/ r'''
              main() {
                final theStore = FooStore();
                final theActions = BazFooActions();

                Foo()
                  ..store = theStore;
              }
            '''),
            expectedOutput: withFluxComponentUsage(/*language=dart*/ r'''
              main() {
                final theStore = FooStore();
                final theActions = BazFooActions();

                Foo()
                  ..actions = null
                  ..store = theStore;
              }
            '''),
          );
        });

        test('actions var in local fn component props with incorrect type', () async {
          await testSuggestor(
            expectedPatchCount: 1,
            input: withFluxComponentUsage(/*language=dart*/ r'''
              class FooConsumerProps = UiProps with FluxUiPropsMixin<BazFooActions, BazFooStore>;
              final FooConsumer = uiFunction<FooConsumerProps>(
                (localProps) {
                  someFunction() {
                    return Foo()
                      ..store = FooStore();
                  }
                
                  return someFunction()();
                },
                _$FooConsumerConfig, // ignore: undefined_identifier
              );
            '''),
            expectedOutput: withFluxComponentUsage(/*language=dart*/ r'''
              class FooConsumerProps = UiProps with FluxUiPropsMixin<BazFooActions, BazFooStore>;
              final FooConsumer = uiFunction<FooConsumerProps>(
                (localProps) {
                  someFunction() {
                    return Foo()
                      ..actions = null
                      ..store = FooStore();
                  }
                
                  return someFunction()();
                },
                _$FooConsumerConfig, // ignore: undefined_identifier
              );
            '''),
          );
        });

        test('actions var in class component props with incorrect type', () async {
          await testSuggestor(
            expectedPatchCount: 1,
            input: withFluxComponentUsage(/*language=dart*/ r'''
              // ignore: undefined_identifier
              UiFactory<FooConsumerProps> FooConsumer = castUiFactory(_$FooConsumer);
              class FooConsumerProps = UiProps with FluxUiPropsMixin<BazFooActions, BazFooStore>;
              class FooConsumerComponent extends FluxUiComponent2<FooConsumerProps> {
                someMethod() {
                  return Foo()
                    ..store = FooStore();
                }

                @override
                render() => null;
              }
            '''),
            expectedOutput: withFluxComponentUsage(/*language=dart*/ r'''
              // ignore: undefined_identifier
              UiFactory<FooConsumerProps> FooConsumer = castUiFactory(_$FooConsumer);
              class FooConsumerProps = UiProps with FluxUiPropsMixin<BazFooActions, BazFooStore>;
              class FooConsumerComponent extends FluxUiComponent2<FooConsumerProps> {
                someMethod() {
                  return Foo()
                    ..actions = null
                    ..store = FooStore();
                }

                @override
                render() => null;
              }
            '''),
          );
        });

        test('actions var in global scope with incorrect type', () async {
          await testSuggestor(
            isExpectedError: (err) => err.message.contains('theActions'),
            expectedPatchCount: 1,
            input: withFluxComponentUsage(/*language=dart*/ r'''
              final theActions = BazFooActions();
              main() {
                final theStore = FooStore();

                Foo()
                  ..store = theStore;
              }
            '''),
            expectedOutput: withFluxComponentUsage(/*language=dart*/ r'''
              final theActions = BazFooActions();
              main() {
                final theStore = FooStore();

                Foo()
                  ..actions = null
                  ..store = theStore;
              }
            '''),
          );
        });

        test('actions var in local fn scope with correct type', () async {
          await testSuggestor(
            isExpectedError: (err) => err.message.contains('theActions'),
            expectedPatchCount: 1,
            input: withFluxComponentUsage(/*language=dart*/ r'''
              main() {
                final theStore = FooStore();
                final theActions = FooActions();

                Foo()
                  ..store = theStore;
              }
            '''),
            expectedOutput: withFluxComponentUsage(/*language=dart*/ r'''
              main() {
                final theStore = FooStore();
                final theActions = FooActions();

                Foo()
                  ..actions = theActions
                  ..store = theStore;
              }
            '''),
          );
        });

        test('actions var in local fn component props with correct type', () async {
          await testSuggestor(
            expectedPatchCount: 1,
            input: withFluxComponentUsage(/*language=dart*/ r'''
              class FooConsumerProps = UiProps with FluxUiPropsMixin<FooActions, FooStore>;
              final FooConsumer = uiFunction<FooConsumerProps>(
                (localProps) {
                  someFunction() {
                    return Foo()
                      ..store = localProps.store;
                  }
                
                  return someFunction()();
                },
                _$FooConsumerConfig, // ignore: undefined_identifier
              );
            '''),
            expectedOutput: withFluxComponentUsage(/*language=dart*/ r'''
              class FooConsumerProps = UiProps with FluxUiPropsMixin<FooActions, FooStore>;
              final FooConsumer = uiFunction<FooConsumerProps>(
                (localProps) {
                  someFunction() {
                    return Foo()
                      ..actions = localProps.actions
                      ..store = localProps.store;
                  }
                
                  return someFunction()();
                },
                _$FooConsumerConfig, // ignore: undefined_identifier
              );
            '''),
          );
        });

        test('actions var in class component props with correct type', () async {
          await testSuggestor(
            expectedPatchCount: 1,
            input: withFluxComponentUsage(/*language=dart*/ r'''
              // ignore: undefined_identifier
              UiFactory<FooConsumerProps> FooConsumer = castUiFactory(_$FooConsumer);
              class FooConsumerProps = UiProps with FluxUiPropsMixin<FooActions, FooStore>;
              class FooConsumerComponent extends FluxUiComponent2<FooConsumerProps> {
                someMethod() {
                  return Foo()
                    ..store = props.store;
                }

                @override
                render() => null;
              }
            '''),
            expectedOutput: withFluxComponentUsage(/*language=dart*/ r'''
              // ignore: undefined_identifier
              UiFactory<FooConsumerProps> FooConsumer = castUiFactory(_$FooConsumer);
              class FooConsumerProps = UiProps with FluxUiPropsMixin<FooActions, FooStore>;
              class FooConsumerComponent extends FluxUiComponent2<FooConsumerProps> {
                someMethod() {
                  return Foo()
                    ..actions = props.actions
                    ..store = props.store;
                }

                @override
                render() => null;
              }
            '''),
          );
        });

        test('actions var in global scope with correct type', () async {
          await testSuggestor(
            isExpectedError: (err) => err.message.contains('theActions'),
            expectedPatchCount: 1,
            input: withFluxComponentUsage(/*language=dart*/ r'''
              final theActions = FooActions();
              main() {
                final theStore = FooStore();

                Foo()
                  ..store = theStore;
              }
            '''),
            expectedOutput: withFluxComponentUsage(/*language=dart*/ r'''
              final theActions = FooActions();
              main() {
                final theStore = FooStore();

                Foo()
                  ..actions = theActions
                  ..store = theStore;
              }
            '''),
          );
        });
      });

      group('and do not have props.store set', () {
        test('no store var in scope', () async {
          await testSuggestor(
            expectedPatchCount: 1,
            input: withFluxComponentUsage(/*language=dart*/ r'''
              main() {
                final theActions = FooActions();

                Foo()
                  ..actions = theActions;
              }
            '''),
            expectedOutput: withFluxComponentUsage(/*language=dart*/ r'''
              main() {
                final theActions = FooActions();

                Foo()
                  ..store = null
                  ..actions = theActions;
              }
            '''),
          );
        });

        test('store var in local fn scope with incorrect type', () async {
          await testSuggestor(
            isExpectedError: (err) => err.message.contains('theStore'),
            expectedPatchCount: 1,
            input: withFluxComponentUsage(/*language=dart*/ r'''
              main() {
                final theStore = BazFooStore();
                final theActions = FooActions();

                Foo()
                  ..actions = theActions;
              }
            '''),
            expectedOutput: withFluxComponentUsage(/*language=dart*/ r'''
              main() {
                final theStore = BazFooStore();
                final theActions = FooActions();

                Foo()
                  ..store = null
                  ..actions = theActions;
              }
            '''),
          );
        });

        test('store var in local fn component props with incorrect type', () async {
          await testSuggestor(
            expectedPatchCount: 1,
            input: withFluxComponentUsage(/*language=dart*/ r'''
              class FooConsumerProps = UiProps with FluxUiPropsMixin<BazFooActions, BazFooStore>;
              final FooConsumer = uiFunction<FooConsumerProps>(
                (localProps) {
                  someFunction() {
                    return Foo()
                      ..actions = FooActions();
                  }
                
                  return someFunction()();
                },
                _$FooConsumerConfig, // ignore: undefined_identifier
              );
            '''),
            expectedOutput: withFluxComponentUsage(/*language=dart*/ r'''
              class FooConsumerProps = UiProps with FluxUiPropsMixin<BazFooActions, BazFooStore>;
              final FooConsumer = uiFunction<FooConsumerProps>(
                (localProps) {
                  someFunction() {
                    return Foo()
                      ..store = null
                      ..actions = FooActions();
                  }
                
                  return someFunction()();
                },
                _$FooConsumerConfig, // ignore: undefined_identifier
              );
            '''),
          );
        });

        test('store var in class component props with incorrect type', () async {
          await testSuggestor(
              expectedPatchCount: 1,
              input: withFluxComponentUsage(/*language=dart*/ r'''
              // ignore: undefined_identifier
              UiFactory<FooConsumerProps> FooConsumer = castUiFactory(_$FooConsumer);
              class FooConsumerProps = UiProps with FluxUiPropsMixin<BazFooActions, BazFooStore>;
              class FooConsumerComponent extends FluxUiComponent2<FooConsumerProps> {
                someMethod() {
                  return Foo()
                    ..actions = FooActions();
                }

                @override
                render() => null;
              }
            '''),
          expectedOutput: withFluxComponentUsage(/*language=dart*/ r'''
              // ignore: undefined_identifier
              UiFactory<FooConsumerProps> FooConsumer = castUiFactory(_$FooConsumer);
              class FooConsumerProps = UiProps with FluxUiPropsMixin<BazFooActions, BazFooStore>;
              class FooConsumerComponent extends FluxUiComponent2<FooConsumerProps> {
                someMethod() {
                  return Foo()
                    ..store = null
                    ..actions = FooActions();
                }

                @override
                render() => null;
              }
            '''),
          );
        });

        test('store var in global scope with incorrect type', () async {
          await testSuggestor(
            isExpectedError: (err) => err.message.contains('theStore'),
            expectedPatchCount: 1,
            input: withFluxComponentUsage(/*language=dart*/ r'''
              final theStore = BazFooStore();
              main() {
                final theActions = FooActions();

                Foo()
                  ..actions = theActions;
              }
            '''),
            expectedOutput: withFluxComponentUsage(/*language=dart*/ r'''
              final theStore = BazFooStore();
              main() {
                final theActions = FooActions();

                Foo()
                  ..store = null
                  ..actions = theActions;
              }
            '''),
          );
        });

        test('store var in local fn scope with correct type', () async {
          await testSuggestor(
            isExpectedError: (err) => err.message.contains('theStore'),
            expectedPatchCount: 1,
            input: withFluxComponentUsage(/*language=dart*/ r'''
              main() {
                final theStore = FooStore();
                final theActions = FooActions();

                Foo()
                  ..actions = theActions;
              }
            '''),
            expectedOutput: withFluxComponentUsage(/*language=dart*/ r'''
              main() {
                final theStore = FooStore();
                final theActions = FooActions();

                Foo()
                  ..store = theStore
                  ..actions = theActions;
              }
            '''),
          );
        });

        test('store var in local fn component props with correct type', () async {
          await testSuggestor(
            expectedPatchCount: 1,
            input: withFluxComponentUsage(/*language=dart*/ r'''
              class FooConsumerProps = UiProps with FluxUiPropsMixin<FooActions, FooStore>;
              final FooConsumer = uiFunction<FooConsumerProps>(
                (localProps) {
                  someFunction() {
                    return Foo()
                      ..actions = localProps.actions;
                  }
                
                  return someFunction()();
                },
                _$FooConsumerConfig, // ignore: undefined_identifier
              );
            '''),
            expectedOutput: withFluxComponentUsage(/*language=dart*/ r'''
              class FooConsumerProps = UiProps with FluxUiPropsMixin<FooActions, FooStore>;
              final FooConsumer = uiFunction<FooConsumerProps>(
                (localProps) {
                  someFunction() {
                    return Foo()
                      ..store = localProps.store
                      ..actions = localProps.actions;
                  }
                
                  return someFunction()();
                },
                _$FooConsumerConfig, // ignore: undefined_identifier
              );
            '''),
          );
        });

        test('store var in class component props with correct type', () async {
          await testSuggestor(
            expectedPatchCount: 1,
            input: withFluxComponentUsage(/*language=dart*/ r'''
              // ignore: undefined_identifier
              UiFactory<FooConsumerProps> FooConsumer = castUiFactory(_$FooConsumer);
              class FooConsumerProps = UiProps with FluxUiPropsMixin<FooActions, FooStore>;
              class FooConsumerComponent extends FluxUiComponent2<FooConsumerProps> {
                someMethod() {
                  return Foo()
                    ..actions = props.actions;
                }

                @override
                render() => null;
              }
            '''),
            expectedOutput: withFluxComponentUsage(/*language=dart*/ r'''
              // ignore: undefined_identifier
              UiFactory<FooConsumerProps> FooConsumer = castUiFactory(_$FooConsumer);
              class FooConsumerProps = UiProps with FluxUiPropsMixin<FooActions, FooStore>;
              class FooConsumerComponent extends FluxUiComponent2<FooConsumerProps> {
                someMethod() {
                  return Foo()
                    ..store = props.store
                    ..actions = props.actions;
                }

                @override
                render() => null;
              }
            '''),
          );
        });

        test('store var in global scope with correct type', () async {
          await testSuggestor(
            isExpectedError: (err) => err.message.contains('theStore'),
            expectedPatchCount: 1,
            input: withFluxComponentUsage(/*language=dart*/ r'''
              final theStore = FooStore();
              main() {
                final theActions = FooActions();

                Foo()
                  ..actions = theActions;
              }
            '''),
            expectedOutput: withFluxComponentUsage(/*language=dart*/ r'''
              final theStore = FooStore();
              main() {
                final theActions = FooActions();

                Foo()
                  ..store = theStore
                  ..actions = theActions;
              }
            '''),
          );
        });
      });

      group('and do not have props.store or props.actions set', () {
        test('no store or actions var in scope', () async {
          await testSuggestor(
            expectedPatchCount: 2,
            input: withFluxComponentUsage(/*language=dart*/ r'''
              main() {
                Foo()
                  ..id = '123';
              }
            '''),
            expectedOutput: withFluxComponentUsage(/*language=dart*/ r'''
              main() {
                Foo()
                  ..store = null
                  ..actions = null
                  ..id = '123';
              }
            '''),
          );
        });

        test('store and actions vars in local fn scope with incorrect types', () async {
          await testSuggestor(
            isExpectedError: (err) => err.message.contains(RegExp(r'theStore|theActions')),
            expectedPatchCount: 2,
            input: withFluxComponentUsage(/*language=dart*/ r'''
              main() {
                final theStore = BazFooStore();
                final theActions = BazFooActions();

                Foo()
                  ..id = '123';
              }
            '''),
            expectedOutput: withFluxComponentUsage(/*language=dart*/ r'''
              main() {
                final theStore = BazFooStore();
                final theActions = BazFooActions();

                Foo()
                  ..store = null
                  ..actions = null
                  ..id = '123';
              }
            '''),
          );
        });

        test('store and actions vars in local fn component props with incorrect types', () async {
          await testSuggestor(
            expectedPatchCount: 2,
            input: withFluxComponentUsage(/*language=dart*/ r'''
              class FooConsumerProps = UiProps with FluxUiPropsMixin<BazFooActions, BazFooStore>;
              final FooConsumer = uiFunction<FooConsumerProps>(
                (localProps) {
                  someFunction() {
                    return Foo()
                      ..id = '123';
                  }
                
                  return someFunction()();
                },
                _$FooConsumerConfig, // ignore: undefined_identifier
              );
            '''),
            expectedOutput: withFluxComponentUsage(/*language=dart*/ r'''
              class FooConsumerProps = UiProps with FluxUiPropsMixin<BazFooActions, BazFooStore>;
              final FooConsumer = uiFunction<FooConsumerProps>(
                (localProps) {
                  someFunction() {
                    return Foo()
                      ..store = null
                      ..actions = null
                      ..id = '123';
                  }
                
                  return someFunction()();
                },
                _$FooConsumerConfig, // ignore: undefined_identifier
              );
            '''),
          );
        });

        test('store and actions vars in class component props with incorrect types', () async {
          await testSuggestor(
            expectedPatchCount: 2,
            input: withFluxComponentUsage(/*language=dart*/ r'''
              // ignore: undefined_identifier
              UiFactory<FooConsumerProps> FooConsumer = castUiFactory(_$FooConsumer);
              class FooConsumerProps = UiProps with FluxUiPropsMixin<BazFooActions, BazFooStore>;
              class FooConsumerComponent extends FluxUiComponent2<FooConsumerProps> {
                someMethod() {
                  return Foo()
                    ..id = '123';
                }

                @override
                render() => null;
              }
            '''),
            expectedOutput: withFluxComponentUsage(/*language=dart*/ r'''
              // ignore: undefined_identifier
              UiFactory<FooConsumerProps> FooConsumer = castUiFactory(_$FooConsumer);
              class FooConsumerProps = UiProps with FluxUiPropsMixin<BazFooActions, BazFooStore>;
              class FooConsumerComponent extends FluxUiComponent2<FooConsumerProps> {
                someMethod() {
                  return Foo()
                    ..store = null
                    ..actions = null
                    ..id = '123';
                }

                @override
                render() => null;
              }
            '''),
          );
        });

        test('store var in local fn scope with incorrect type', () async {
          await testSuggestor(
            isExpectedError: (err) => err.message.contains('theStore'),
            expectedPatchCount: 2,
            input: withFluxComponentUsage(/*language=dart*/ r'''
              main() {
                final theStore = BazFooStore();

                Foo()
                  ..id = '123';
              }
            '''),
            expectedOutput: withFluxComponentUsage(/*language=dart*/ r'''
              main() {
                final theStore = BazFooStore();

                Foo()
                  ..store = null
                  ..actions = null
                  ..id = '123';
              }
            '''),
          );
        });

        test('actions var in local fn scope with incorrect type', () async {
          await testSuggestor(
            isExpectedError: (err) => err.message.contains('theActions'),
            expectedPatchCount: 2,
            input: withFluxComponentUsage(/*language=dart*/ r'''
              main() {
                final theActions = BazFooActions();

                Foo()
                  ..id = '123';
              }
            '''),
            expectedOutput: withFluxComponentUsage(/*language=dart*/ r'''
              main() {
                final theActions = BazFooActions();

                Foo()
                  ..store = null
                  ..actions = null
                  ..id = '123';
              }
            '''),
          );
        });

        test('store and actions vars in global scope with incorrect types', () async {
          await testSuggestor(
            isExpectedError: (err) => err.message.contains(RegExp(r'theStore|theActions')),
            expectedPatchCount: 2,
            input: withFluxComponentUsage(/*language=dart*/ r'''
              final theStore = BazFooStore();
              final theActions = BazFooActions();
              main() {
                Foo()
                  ..id = '123';
              }
            '''),
            expectedOutput: withFluxComponentUsage(/*language=dart*/ r'''
              final theStore = BazFooStore();
              final theActions = BazFooActions();
              main() {
                Foo()
                  ..store = null
                  ..actions = null
                  ..id = '123';
              }
            '''),
          );
        });

        test('store var in global scope with incorrect type', () async {
          await testSuggestor(
            isExpectedError: (err) => err.message.contains('theStore'),
            expectedPatchCount: 2,
            input: withFluxComponentUsage(/*language=dart*/ r'''
              final theStore = BazFooStore();
              main() {
                Foo()
                  ..id = '123';
              }
            '''),
            expectedOutput: withFluxComponentUsage(/*language=dart*/ r'''
              final theStore = BazFooStore();
              main() {
                Foo()
                  ..store = null
                  ..actions = null
                  ..id = '123';
              }
            '''),
          );
        });

        test('actions var in global scope with incorrect type', () async {
          await testSuggestor(
            isExpectedError: (err) => err.message.contains('theActions'),
            expectedPatchCount: 2,
            input: withFluxComponentUsage(/*language=dart*/ r'''
              final theActions = BazFooActions();
              main() {
                Foo()
                  ..id = '123';
              }
            '''),
            expectedOutput: withFluxComponentUsage(/*language=dart*/ r'''
              final theActions = BazFooActions();
              main() {
                Foo()
                  ..store = null
                  ..actions = null
                  ..id = '123';
              }
            '''),
          );
        });

        test('store and actions vars in local fn scope with correct types', () async {
          await testSuggestor(
            isExpectedError: (err) => err.message.contains(RegExp(r'theStore|theActions')),
            expectedPatchCount: 2,
            input: withFluxComponentUsage(/*language=dart*/ r'''
              main() {
                final theStore = FooStore();
                final theActions = FooActions();

                Foo()
                  ..id = '123';
              }
            '''),
            expectedOutput: withFluxComponentUsage(/*language=dart*/ r'''
              main() {
                final theStore = FooStore();
                final theActions = FooActions();

                Foo()
                  ..store = theStore
                  ..actions = theActions
                  ..id = '123';
              }
            '''),
          );
        });

        test('store and actions vars in local fn component props with correct types', () async {
          await testSuggestor(
            expectedPatchCount: 2,
            input: withFluxComponentUsage(/*language=dart*/ r'''
              class FooConsumerProps = UiProps with FluxUiPropsMixin<FooActions, FooStore>;
              final FooConsumer = uiFunction<FooConsumerProps>(
                (localProps) {
                  someFunction() {
                    return Foo()
                      ..id = '123';
                  }
                
                  return someFunction()();
                },
                _$FooConsumerConfig, // ignore: undefined_identifier
              );
            '''),
            expectedOutput: withFluxComponentUsage(/*language=dart*/ r'''
              class FooConsumerProps = UiProps with FluxUiPropsMixin<FooActions, FooStore>;
              final FooConsumer = uiFunction<FooConsumerProps>(
                (localProps) {
                  someFunction() {
                    return Foo()
                      ..store = localProps.store
                      ..actions = localProps.actions
                      ..id = '123';
                  }
                
                  return someFunction()();
                },
                _$FooConsumerConfig, // ignore: undefined_identifier
              );
            '''),
          );
        });

        test('store and actions vars in class component props with correct types', () async {
          await testSuggestor(
            expectedPatchCount: 2,
            input: withFluxComponentUsage(/*language=dart*/ r'''
              // ignore: undefined_identifier
              UiFactory<FooConsumerProps> FooConsumer = castUiFactory(_$FooConsumer);
              class FooConsumerProps = UiProps with FluxUiPropsMixin<FooActions, FooStore>;
              class FooConsumerComponent extends FluxUiComponent2<FooConsumerProps> {
                someMethod() {
                  return Foo()
                    ..id = '123';
                }

                @override
                render() => null;
              }
            '''),
            expectedOutput: withFluxComponentUsage(/*language=dart*/ r'''
              // ignore: undefined_identifier
              UiFactory<FooConsumerProps> FooConsumer = castUiFactory(_$FooConsumer);
              class FooConsumerProps = UiProps with FluxUiPropsMixin<FooActions, FooStore>;
              class FooConsumerComponent extends FluxUiComponent2<FooConsumerProps> {
                someMethod() {
                  return Foo()
                    ..store = props.store
                    ..actions = props.actions
                    ..id = '123';
                }

                @override
                render() => null;
              }
            '''),
          );
        });

        test('store var in local fn scope with correct type', () async {
          await testSuggestor(
            isExpectedError: (err) => err.message.contains('theStore'),
            expectedPatchCount: 2,
            input: withFluxComponentUsage(/*language=dart*/ r'''
              main() {
                final theStore = FooStore();

                Foo()
                  ..id = '123';
              }
            '''),
            expectedOutput: withFluxComponentUsage(/*language=dart*/ r'''
              main() {
                final theStore = FooStore();

                Foo()
                  ..store = theStore
                  ..actions = null
                  ..id = '123';
              }
            '''),
          );
        });

        test('actions var in local fn scope with correct type', () async {
          await testSuggestor(
            isExpectedError: (err) => err.message.contains('theActions'),
            expectedPatchCount: 2,
            input: withFluxComponentUsage(/*language=dart*/ r'''
              main() {
                final theActions = FooActions();

                Foo()
                  ..id = '123';
              }
            '''),
            expectedOutput: withFluxComponentUsage(/*language=dart*/ r'''
              main() {
                final theActions = FooActions();

                Foo()
                  ..store = null
                  ..actions = theActions
                  ..id = '123';
              }
            '''),
          );
        });

        test('store and actions vars in global scope with correct types', () async {
          await testSuggestor(
            isExpectedError: (err) => err.message.contains(RegExp(r'theStore|theActions')),
            expectedPatchCount: 2,
            input: withFluxComponentUsage(/*language=dart*/ r'''
              final theStore = FooStore();
              final theActions = FooActions();
              main() {
                Foo()
                  ..id = '123';
              }
            '''),
            expectedOutput: withFluxComponentUsage(/*language=dart*/ r'''
              final theStore = FooStore();
              final theActions = FooActions();
              main() {
                Foo()
                  ..store = theStore
                  ..actions = theActions
                  ..id = '123';
              }
            '''),
          );
        });

        test('store var in global scope with correct type', () async {
          await testSuggestor(
            isExpectedError: (err) => err.message.contains('theStore'),
            expectedPatchCount: 2,
            input: withFluxComponentUsage(/*language=dart*/ r'''
              final theStore = FooStore();
              main() {
                Foo()
                  ..id = '123';
              }
            '''),
            expectedOutput: withFluxComponentUsage(/*language=dart*/ r'''
              final theStore = FooStore();
              main() {
                Foo()
                  ..store = theStore
                  ..actions = null
                  ..id = '123';
              }
            '''),
          );
        });

        test('actions var in global scope with correct type', () async {
          await testSuggestor(
            isExpectedError: (err) => err.message.contains('theActions'),
            expectedPatchCount: 2,
            input: withFluxComponentUsage(/*language=dart*/ r'''
              final theActions = FooActions();
              main() {
                Foo()
                  ..id = '123';
              }
            '''),
            expectedOutput: withFluxComponentUsage(/*language=dart*/ r'''
              final theActions = FooActions();
              main() {
                Foo()
                  ..store = null
                  ..actions = theActions
                  ..id = '123';
              }
            '''),
          );
        });
      });
    });

    // TODO (adl): Make this shared with uninvoked tests to reduce duplication
    // group('patches invoked builders that use FluxUiPropsMixin', () {
    //   group('and do not have props.actions set', () {
    //     test('no actions var in scope', () async {
    //       await testSuggestor(
    //         expectedPatchCount: 1,
    //         input: withFluxComponentUsage(/*language=dart*/ r'''
    //           main() {
    //             final theStore = FooStore();
    //
    //             return (Foo()
    //               ..store = theStore
    //             )();
    //           }
    //         '''),
    //         expectedOutput: withFluxComponentUsage(/*language=dart*/ r'''
    //           main() {
    //             final theStore = FooStore();
    //
    //             return (Foo()
    //               ..actions = null
    //               ..store = theStore
    //             )();
    //           }
    //         '''),
    //       );
    //     });
    //
    //     test('actions var in local fn scope with incorrect type', () async {
    //       await testSuggestor(
    //         isExpectedError: (err) => err.message.contains('theActions'),
    //         expectedPatchCount: 1,
    //         input: withFluxComponentUsage(/*language=dart*/ r'''
    //           main() {
    //             final theStore = FooStore();
    //             final theActions = BazFooActions();
    //
    //             return (Foo()
    //               ..store = theStore
    //             )();
    //           }
    //         '''),
    //         expectedOutput: withFluxComponentUsage(/*language=dart*/ r'''
    //           main() {
    //             final theStore = FooStore();
    //             final theActions = BazFooActions();
    //
    //             return (Foo()
    //               ..actions = null
    //               ..store = theStore
    //             )();
    //           }
    //         '''),
    //       );
    //     });
    //
    //     test('actions var in global scope with incorrect type', () async {
    //       await testSuggestor(
    //         isExpectedError: (err) => err.message.contains('theActions'),
    //         expectedPatchCount: 1,
    //         input: withFluxComponentUsage(/*language=dart*/ r'''
    //           final theActions = BazFooActions();
    //           main() {
    //             final theStore = FooStore();
    //
    //             return (Foo()
    //               ..store = theStore
    //             )();
    //           }
    //         '''),
    //         expectedOutput: withFluxComponentUsage(/*language=dart*/ r'''
    //           final theActions = BazFooActions();
    //           main() {
    //             final theStore = FooStore();
    //
    //             return (Foo()
    //               ..actions = null
    //               ..store = theStore
    //             )();
    //           }
    //         '''),
    //       );
    //     });
    //
    //     test('actions var in local fn scope with correct type', () async {
    //       await testSuggestor(
    //         isExpectedError: (err) => err.message.contains('theActions'),
    //         expectedPatchCount: 1,
    //         input: withFluxComponentUsage(/*language=dart*/ r'''
    //           main() {
    //             final theStore = FooStore();
    //             final theActions = FooActions();
    //
    //             return (Foo()
    //               ..store = theStore
    //             )();
    //           }
    //         '''),
    //         expectedOutput: withFluxComponentUsage(/*language=dart*/ r'''
    //           main() {
    //             final theStore = FooStore();
    //             final theActions = FooActions();
    //
    //             return (Foo()
    //               ..actions = theActions
    //               ..store = theStore
    //             )();
    //           }
    //         '''),
    //       );
    //     });
    //
    //     test('actions var in global scope with correct type', () async {
    //       await testSuggestor(
    //         isExpectedError: (err) => err.message.contains('theActions'),
    //         expectedPatchCount: 1,
    //         input: withFluxComponentUsage(/*language=dart*/ r'''
    //           final theActions = FooActions();
    //           main() {
    //             final theStore = FooStore();
    //
    //             return (Foo()
    //               ..store = theStore
    //             )();
    //           }
    //         '''),
    //         expectedOutput: withFluxComponentUsage(/*language=dart*/ r'''
    //           final theActions = FooActions();
    //           main() {
    //             final theStore = FooStore();
    //
    //             return (Foo()
    //               ..actions = theActions
    //               ..store = theStore
    //             )();
    //           }
    //         '''),
    //       );
    //     });
    //   });
    //
    //   group('and do not have props.store set', () {
    //     test('no store var in scope', () async {
    //       await testSuggestor(
    //         expectedPatchCount: 1,
    //         input: withFluxComponentUsage(/*language=dart*/ r'''
    //           main() {
    //             final theActions = FooActions();
    //
    //             return (Foo()
    //               ..actions = theActions
    //             )();
    //           }
    //         '''),
    //         expectedOutput: withFluxComponentUsage(/*language=dart*/ r'''
    //           main() {
    //             final theActions = FooActions();
    //
    //             return (Foo()
    //               ..store = null
    //               ..actions = theActions
    //             )();
    //           }
    //         '''),
    //       );
    //     });
    //
    //     test('store var in local fn scope with incorrect type', () async {
    //       await testSuggestor(
    //         isExpectedError: (err) => err.message.contains('theStore'),
    //         expectedPatchCount: 1,
    //         input: withFluxComponentUsage(/*language=dart*/ r'''
    //           main() {
    //             final theStore = BazFooStore();
    //             final theActions = FooActions();
    //
    //             return (Foo()
    //               ..actions = theActions
    //             )();
    //           }
    //         '''),
    //         expectedOutput: withFluxComponentUsage(/*language=dart*/ r'''
    //           main() {
    //             final theStore = BazFooStore();
    //             final theActions = FooActions();
    //
    //             return (Foo()
    //               ..store = null
    //               ..actions = theActions
    //             )();
    //           }
    //         '''),
    //       );
    //     });
    //
    //     test('store var in global scope with incorrect type', () async {
    //       await testSuggestor(
    //         isExpectedError: (err) => err.message.contains('theStore'),
    //         expectedPatchCount: 1,
    //         input: withFluxComponentUsage(/*language=dart*/ r'''
    //           final theStore = BazFooStore();
    //           main() {
    //             final theActions = FooActions();
    //
    //             return (Foo()
    //               ..actions = theActions
    //             )();
    //           }
    //         '''),
    //         expectedOutput: withFluxComponentUsage(/*language=dart*/ r'''
    //           final theStore = BazFooStore();
    //           main() {
    //             final theActions = FooActions();
    //
    //             return (Foo()
    //               ..store = null
    //               ..actions = theActions
    //             )();
    //           }
    //         '''),
    //       );
    //     });
    //
    //     test('store var in local fn scope with correct type', () async {
    //       await testSuggestor(
    //         isExpectedError: (err) => err.message.contains('theStore'),
    //         expectedPatchCount: 1,
    //         input: withFluxComponentUsage(/*language=dart*/ r'''
    //           main() {
    //             final theStore = FooStore();
    //             final theActions = FooActions();
    //
    //             return (Foo()
    //               ..actions = theActions
    //             )();
    //           }
    //         '''),
    //         expectedOutput: withFluxComponentUsage(/*language=dart*/ r'''
    //           main() {
    //             final theStore = FooStore();
    //             final theActions = FooActions();
    //
    //             return (Foo()
    //               ..store = theStore
    //               ..actions = theActions
    //             )();
    //           }
    //         '''),
    //       );
    //     });
    //
    //     test('store var in global scope with correct type', () async {
    //       await testSuggestor(
    //         isExpectedError: (err) => err.message.contains('theStore'),
    //         expectedPatchCount: 1,
    //         input: withFluxComponentUsage(/*language=dart*/ r'''
    //           final theStore = FooStore();
    //           main() {
    //             final theActions = FooActions();
    //
    //             return (Foo()
    //               ..actions = theActions
    //             )();
    //           }
    //         '''),
    //         expectedOutput: withFluxComponentUsage(/*language=dart*/ r'''
    //           final theStore = FooStore();
    //           main() {
    //             final theActions = FooActions();
    //
    //             return (Foo()
    //               ..store = theStore
    //               ..actions = theActions
    //             )();
    //           }
    //         '''),
    //       );
    //     });
    //   });
    // });
  });
}

String withFluxComponentUsage(String source, {String? actionsName = 'FooActions', String? storeName = 'FooStore'}) {
  String getActionsClasses() => actionsName == null ? '' : '''
class $actionsName {
  $actionsName();
}

class Baz$actionsName {
  Baz$actionsName();
}
''';

  String getStoreClasses() => storeName == null ? '' : '''
class $storeName {
  $storeName();
}

class Baz$storeName {
  Baz$storeName();
}
''';

  return withOverReactImport('''$source

${getActionsClasses()}

${getStoreClasses()}

UiFactory<FooProps> Foo = castUiFactory(_\$Foo); // ignore: undefined_identifier

class FooProps = UiProps with FluxUiPropsMixin<${actionsName ?? 'Null'}, ${storeName ?? 'Null'}>;

class FooComponent extends FluxUiComponent2<FooProps> {
  @override
  render() => null;
}

UiFactory<NotFooProps> NotFoo = castUiFactory(_\$NotFoo); // ignore: undefined_identifier

// FIXME (adl): Do we need to have a mixin that has store/actions with the correct type? (See FIXME in impl regarding out-of-scope vars being used) 
mixin NotFooPropsMixin on UiProps {
  Baz$storeName store;
  Baz$actionsName actions;
}

class NotFooProps = UiProps with NotFooPropsMixin;

class NotFooComponent extends UiComponent2<NotFooProps> {
  @override
  render() => null;
}''');
}

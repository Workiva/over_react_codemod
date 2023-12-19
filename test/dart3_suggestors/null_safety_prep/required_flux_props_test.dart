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

import 'package:meta/meta.dart';
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

    test(
        'leaves builders alone if they don\'t use FluxUiPropsMixin, '
        'even if they have props named store/actions', () async {
      await testSuggestor(
        isExpectedError: (err) => err.message
            .contains(RegExp(r"'(theStore|theActions)' isn't used.")),
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

    test('leaves defaultProps/getDefaultProps alone', () async {
      await testSuggestor(
        expectedPatchCount: 0,
        input: withFluxComponentUsage(/*language=dart*/ r'''
          class FizComponent extends FluxUiComponent2<FooProps> {
            @override
            getDefaultProps() => newProps()..id = '123';
            
            @override
            get defaultProps => newProps()..id = '123';
          
            @override
            render() => null;
          }
        '''),
      );
    });

    @isTestGroup
    void sharedTests({required bool invokeBuilder}) {
      String maybeInvokeBuilder(String builderString) {
        return (!invokeBuilder ? builderString : '($builderString)()') + ';';
      }

      group(
          'patches ${invokeBuilder ? 'invoked' : 'un-invoked'} builders that use FluxUiPropsMixin and',
          () {
        group('have no actions setter', () {
          test('when no actions var is available in scope', () async {
            await testSuggestor(
              expectedPatchCount: 1,
              input: withFluxComponentUsage('''
                main() {
                  final theStore = FooStore();
                  ${maybeInvokeBuilder('''Foo()..store = theStore''')}
                }
              '''),
              expectedOutput: withFluxComponentUsage('''
                main() {
                  final theStore = FooStore();
                  ${maybeInvokeBuilder('''
                  Foo()
                    ..actions = null
                    ..store = theStore
                  ''')}
                }
              '''),
            );
          });

          test('when a dynamic var is available in scope', () async {
            await testSuggestor(
              isExpectedError: (err) =>
                  err.message.contains(RegExp(r"'notTheActions' isn't used.")),
              expectedPatchCount: 1,
              input: withFluxComponentUsage('''
                main() {
                  dynamic notTheActions = 123;
                  final theStore = FooStore();
                  
                  ${maybeInvokeBuilder('''Foo()..store = theStore''')}
                }
              '''),
              expectedOutput: withFluxComponentUsage('''
                main() {
                  dynamic notTheActions = 123;
                  final theStore = FooStore();

                  ${maybeInvokeBuilder('''
                  Foo()
                    ..actions = null
                    ..store = theStore
                  ''')}
                }
              '''),
            );
          });

          group('when a top-level actions var is available', () {
            test('unless the type does not match (uses null instead)',
                () async {
              await testSuggestor(
                isExpectedError: (err) =>
                    err.message.contains(RegExp(r"'theActions' isn't used.")),
                expectedPatchCount: 1,
                input: withFluxComponentUsage('''
                  final theActions = BazFooActions();
                  main() {
                    final theStore = FooStore();
                    ${maybeInvokeBuilder('''
                    Foo()
                      ..store = theStore
                    ''')}
                  }
                '''),
                expectedOutput: withFluxComponentUsage('''
                  final theActions = BazFooActions();
                  main() {
                    final theStore = FooStore();
                    ${maybeInvokeBuilder('''
                    Foo()
                      ..actions = null
                      ..store = theStore
                    ''')}
                  }
                '''),
              );
            });

            test('and the type matches', () async {
              await testSuggestor(
                isExpectedError: (err) =>
                    err.message.contains(RegExp(r"'theActions' isn't used.")),
                expectedPatchCount: 1,
                input: withFluxComponentUsage('''
                  final theActions = FooActions();
                  main() {
                    final theStore = FooStore();
                    ${maybeInvokeBuilder('''
                    Foo()
                      ..store = theStore
                    ''')}
                  }
                '''),
                expectedOutput: withFluxComponentUsage('''
                  final theActions = FooActions();
                  main() {
                    final theStore = FooStore();
                    ${maybeInvokeBuilder('''
                    Foo()
                      ..actions = theActions
                      ..store = theStore
                    ''')}
                  }
                '''),
              );
            });
          });

          group('when an actions var is available in block function scope', () {
            test('unless the type does not match (uses null instead)',
                () async {
              await testSuggestor(
                isExpectedError: (err) =>
                    err.message.contains(RegExp(r"'theActions' isn't used.")),
                expectedPatchCount: 1,
                input: withFluxComponentUsage('''
                  main() {
                    final theStore = FooStore();
                    final theActions = BazFooActions();
    
                    ${maybeInvokeBuilder('''
                    Foo()
                      ..store = theStore
                    ''')}
                  }
                '''),
                expectedOutput: withFluxComponentUsage('''
                  main() {
                    final theStore = FooStore();
                    final theActions = BazFooActions();
    
                    ${maybeInvokeBuilder('''
                    Foo()
                      ..actions = null
                      ..store = theStore
                    ''')}
                  }
                '''),
              );
            });

            test('and the type matches', () async {
              await testSuggestor(
                isExpectedError: (err) =>
                    err.message.contains(RegExp(r"'theActions' isn't used.")),
                expectedPatchCount: 1,
                input: withFluxComponentUsage('''
                  main() {
                    final theStore = FooStore();
                    final theActions = FooActions();
    
                    ${maybeInvokeBuilder('''
                    Foo()
                      ..store = theStore
                    ''')}
                  }
                '''),
                expectedOutput: withFluxComponentUsage('''
                  main() {
                    final theStore = FooStore();
                    final theActions = FooActions();
    
                    ${maybeInvokeBuilder('''
                    Foo()
                      ..actions = theActions
                      ..store = theStore
                    ''')}
                  }
                '''),
              );
            });
          });

          group('when an actions var is available as a function argument', () {
            test('unless the type does not match (uses null instead)',
                () async {
              await testSuggestor(
                isExpectedError: (err) =>
                    err.message.contains(RegExp(r"'theActions' isn't used.")),
                expectedPatchCount: 1,
                input: withFluxComponentUsage('''
                  main(BazFooActions theActions) {
                    final theStore = FooStore();
    
                    ${maybeInvokeBuilder('''
                    Foo()
                      ..store = theStore
                    ''')}
                  }
                '''),
                expectedOutput: withFluxComponentUsage('''
                  main(BazFooActions theActions) {
                    final theStore = FooStore();
    
                    ${maybeInvokeBuilder('''
                    Foo()
                      ..actions = null
                      ..store = theStore
                    ''')}
                  }
                '''),
              );
            });

            test('and the type matches', () async {
              await testSuggestor(
                isExpectedError: (err) =>
                    err.message.contains(RegExp(r"'theActions' isn't used.")),
                expectedPatchCount: 1,
                input: withFluxComponentUsage('''
                  main(FooActions theActions) {
                    final theStore = FooStore();
    
                    ${maybeInvokeBuilder('''
                    Foo()
                      ..store = theStore
                    ''')}
                  }
                '''),
                expectedOutput: withFluxComponentUsage('''
                  main(FooActions theActions) {
                    final theStore = FooStore();
    
                    ${maybeInvokeBuilder('''
                    Foo()
                      ..actions = theActions
                      ..store = theStore
                    ''')}
                  }
                '''),
              );
            });
          });

          group('when an actions var is available as a class field', () {
            test('unless the type does not match (uses null instead)',
                () async {
              await testSuggestor(
                isExpectedError: (err) =>
                    err.message.contains(RegExp(r"'theActions' isn't used.")),
                expectedPatchCount: 1,
                input: withFluxComponentUsage('''
                  class TheBaz {
                    final BazFooActions theActions;
                    final FooStore theStore;
                    TheBaz(this.theActions, this.theStore);
                    
                    someMethod() {
                      ${maybeInvokeBuilder('''
                      Foo()
                        ..store = theStore
                      ''')}
                    }
                  }
                '''),
                expectedOutput: withFluxComponentUsage('''
                  class TheBaz {
                    final BazFooActions theActions;
                    final FooStore theStore;
                    TheBaz(this.theActions, this.theStore);
                    
                    someMethod() {
                      ${maybeInvokeBuilder('''
                      Foo()
                        ..actions = null
                        ..store = theStore
                      ''')}
                    }
                  }
                '''),
              );
            });

            test('and the type matches', () async {
              await testSuggestor(
                isExpectedError: (err) =>
                    err.message.contains(RegExp(r"'theActions' isn't used.")),
                expectedPatchCount: 1,
                input: withFluxComponentUsage('''
                  class TheFoo {
                    final FooActions theActions;
                    final FooStore theStore;
                    TheFoo(this.theActions, this.theStore);
                    
                    someMethod() {
                      ${maybeInvokeBuilder('''
                      Foo()
                        ..store = theStore
                      ''')}
                    }
                  }
                '''),
                expectedOutput: withFluxComponentUsage('''
                  class TheFoo {
                    final FooActions theActions;
                    final FooStore theStore;
                    TheFoo(this.theActions, this.theStore);
                    
                    someMethod() {
                      ${maybeInvokeBuilder('''
                      Foo()
                        ..actions = theActions
                        ..store = theStore
                      ''')}
                    }
                  }
                '''),
              );
            });
          });

          group('when an actions var is available in function component props',
              () {
            test('unless the type does not match (uses null instead)',
                () async {
              await testSuggestor(
                isExpectedError: (err) => err.message.contains('someFunction'),
                expectedPatchCount: 1,
                input: withFluxComponentUsage('''
                  class FooConsumerProps = UiProps with FluxUiPropsMixin<BazFooActions, BazFooStore>;
                  final FooConsumer = uiFunction<FooConsumerProps>(
                    (localProps) {
                      someFunction() {
                        return ${maybeInvokeBuilder('''Foo()
                          ..store = FooStore()
                        ''')}
                      }
                    
                      return null;
                    },
                    _\$FooConsumerConfig, // ignore: undefined_identifier
                  );
                '''),
                expectedOutput: withFluxComponentUsage('''
                  class FooConsumerProps = UiProps with FluxUiPropsMixin<BazFooActions, BazFooStore>;
                  final FooConsumer = uiFunction<FooConsumerProps>(
                    (localProps) {
                      someFunction() {
                        return ${maybeInvokeBuilder('''Foo()
                          ..actions = null
                          ..store = FooStore()
                        ''')}
                      }
                    
                      return null;
                    },
                    _\$FooConsumerConfig, // ignore: undefined_identifier
                  );
                '''),
              );
            });

            test('and the type matches', () async {
              await testSuggestor(
                isExpectedError: (err) => err.message.contains('someFunction'),
                expectedPatchCount: 1,
                input: withFluxComponentUsage('''
                  class FooConsumerProps = UiProps with FluxUiPropsMixin<FooActions, FooStore>;
                  final FooConsumer = uiFunction<FooConsumerProps>(
                    (localProps) {
                      someFunction() {
                        return ${maybeInvokeBuilder('''Foo()
                          ..store = localProps.store
                        ''')}
                      }
                    
                      return null;
                    },
                    _\$FooConsumerConfig, // ignore: undefined_identifier
                  );
                '''),
                expectedOutput: withFluxComponentUsage('''
                  class FooConsumerProps = UiProps with FluxUiPropsMixin<FooActions, FooStore>;
                  final FooConsumer = uiFunction<FooConsumerProps>(
                    (localProps) {
                      someFunction() {
                        return ${maybeInvokeBuilder('''Foo()
                          ..actions = localProps.actions
                          ..store = localProps.store
                        ''')}
                      }
                    
                      return null;
                    },
                    _\$FooConsumerConfig, // ignore: undefined_identifier
                  );
                '''),
              );
            });
          });

          group('when an actions var is available in class component props',
              () {
            test('unless the type does not match (uses null instead)',
                () async {
              await testSuggestor(
                expectedPatchCount: 1,
                input: withFluxComponentUsage('''
                  // ignore: undefined_identifier
                  UiFactory<FooConsumerProps> FooConsumer = castUiFactory(_\$FooConsumer);
                  class FooConsumerProps = UiProps with FluxUiPropsMixin<BazFooActions, BazFooStore>;
                  class FooConsumerComponent extends FluxUiComponent2<FooConsumerProps> {
                    someMethod() {
                      return ${maybeInvokeBuilder('''Foo()
                        ..store = FooStore()
                      ''')}
                    }
    
                    @override
                    render() => null;
                  }
                '''),
                expectedOutput: withFluxComponentUsage('''
                  // ignore: undefined_identifier
                  UiFactory<FooConsumerProps> FooConsumer = castUiFactory(_\$FooConsumer);
                  class FooConsumerProps = UiProps with FluxUiPropsMixin<BazFooActions, BazFooStore>;
                  class FooConsumerComponent extends FluxUiComponent2<FooConsumerProps> {
                    someMethod() {
                      return ${maybeInvokeBuilder('''Foo()
                        ..actions = null
                        ..store = FooStore()
                      ''')}
                    }
    
                    @override
                    render() => null;
                  }
                '''),
              );
            });

            test('and the type matches', () async {
              await testSuggestor(
                expectedPatchCount: 1,
                input: withFluxComponentUsage('''
                  // ignore: undefined_identifier
                  UiFactory<FooConsumerProps> FooConsumer = castUiFactory(_\$FooConsumer);
                  class FooConsumerProps = UiProps with FluxUiPropsMixin<FooActions, FooStore>;
                  class FooConsumerComponent extends FluxUiComponent2<FooConsumerProps> {
                    someMethod() {
                      return ${maybeInvokeBuilder('''Foo()
                        ..store = props.store
                      ''')}
                    }
    
                    @override
                    render() => null;
                  }
                '''),
                expectedOutput: withFluxComponentUsage('''
                  // ignore: undefined_identifier
                  UiFactory<FooConsumerProps> FooConsumer = castUiFactory(_\$FooConsumer);
                  class FooConsumerProps = UiProps with FluxUiPropsMixin<FooActions, FooStore>;
                  class FooConsumerComponent extends FluxUiComponent2<FooConsumerProps> {
                    someMethod() {
                      return ${maybeInvokeBuilder('''Foo()
                        ..actions = props.actions
                        ..store = props.store
                      ''')}
                    }
    
                    @override
                    render() => null;
                  }
                '''),
              );
            });
          });
        });

        group('have no store setter', () {
          test('when no store var is available in scope', () async {
            await testSuggestor(
              expectedPatchCount: 1,
              input: withFluxComponentUsage('''
                main() {
                  final theActions = FooActions();
  
                  ${maybeInvokeBuilder('''Foo()
                    ..actions = theActions
                  ''')}
                }
              '''),
              expectedOutput: withFluxComponentUsage('''
                main() {
                  final theActions = FooActions();
  
                  ${maybeInvokeBuilder('''Foo()
                    ..store = null
                    ..actions = theActions
                  ''')}
                }
              '''),
            );
          });

          group('when a top-level store var is available', () {
            test('unless the type does not match (uses null instead)',
                () async {
              await testSuggestor(
                isExpectedError: (err) =>
                    err.message.contains(RegExp(r"'theStore' isn't used.")),
                expectedPatchCount: 1,
                input: withFluxComponentUsage('''
                  final theStore = BazFooStore();
                  main() {
                    final theActions = FooActions();
    
                    ${maybeInvokeBuilder('''Foo()
                      ..actions = theActions
                    ''')}
                  }
                '''),
                expectedOutput: withFluxComponentUsage('''
                  final theStore = BazFooStore();
                  main() {
                    final theActions = FooActions();
    
                    ${maybeInvokeBuilder('''Foo()
                      ..store = null
                      ..actions = theActions
                    ''')}
                  }
                '''),
              );
            });

            test('and the type matches', () async {
              await testSuggestor(
                isExpectedError: (err) =>
                    err.message.contains(RegExp(r"'theStore' isn't used.")),
                expectedPatchCount: 1,
                input: withFluxComponentUsage('''
                  final theStore = FooStore();
                  main() {
                    final theActions = FooActions();
    
                    ${maybeInvokeBuilder('''Foo()
                      ..actions = theActions
                    ''')}
                  }
                '''),
                expectedOutput: withFluxComponentUsage('''
                  final theStore = FooStore();
                  main() {
                    final theActions = FooActions();
    
                    ${maybeInvokeBuilder('''Foo()
                      ..store = theStore
                      ..actions = theActions
                    ''')}
                  }
                '''),
              );
            });
          });

          group('when a store var is available in block function scope', () {
            test('unless the type does not match (uses null instead)',
                () async {
              await testSuggestor(
                isExpectedError: (err) =>
                    err.message.contains(RegExp(r"'theStore' isn't used.")),
                expectedPatchCount: 1,
                input: withFluxComponentUsage('''
                  main() {
                    final theStore = BazFooStore();
                    final theActions = FooActions();
    
                    ${maybeInvokeBuilder('''Foo()
                      ..actions = theActions
                    ''')}
                  }
                '''),
                expectedOutput: withFluxComponentUsage('''
                  main() {
                    final theStore = BazFooStore();
                    final theActions = FooActions();
    
                    ${maybeInvokeBuilder('''Foo()
                      ..store = null
                      ..actions = theActions
                    ''')}
                  }
                '''),
              );
            });

            test('and the type matches', () async {
              await testSuggestor(
                isExpectedError: (err) =>
                    err.message.contains(RegExp(r"'theStore' isn't used.")),
                expectedPatchCount: 1,
                input: withFluxComponentUsage('''
                  main() {
                    final theStore = FooStore();
                    final theActions = FooActions();
    
                    ${maybeInvokeBuilder('''Foo()
                      ..actions = theActions
                    ''')}
                  }
                '''),
                expectedOutput: withFluxComponentUsage('''
                  main() {
                    final theStore = FooStore();
                    final theActions = FooActions();
    
                    ${maybeInvokeBuilder('''Foo()
                      ..store = theStore
                      ..actions = theActions
                    ''')}
                  }
                '''),
              );
            });
          });

          group('when a store var is available as a function argument', () {
            test('unless the type does not match (uses null instead)',
                () async {
              await testSuggestor(
                isExpectedError: (err) =>
                    err.message.contains(RegExp(r"'theStore' isn't used.")),
                expectedPatchCount: 1,
                input: withFluxComponentUsage('''
                  main(BazFooStore theStore) {
                    final theActions = FooActions();
    
                    ${maybeInvokeBuilder('''
                    Foo()
                      ..actions = theActions
                    ''')}
                  }
                '''),
                expectedOutput: withFluxComponentUsage('''
                  main(BazFooStore theStore) {
                    final theActions = FooActions();
    
                    ${maybeInvokeBuilder('''
                    Foo()
                      ..store = null
                      ..actions = theActions
                    ''')}
                  }
                '''),
              );
            });

            test('and the type matches', () async {
              await testSuggestor(
                isExpectedError: (err) =>
                    err.message.contains(RegExp(r"'theStore' isn't used.")),
                expectedPatchCount: 1,
                input: withFluxComponentUsage('''
                  main(FooStore theStore) {
                    final theActions = FooActions();
    
                    ${maybeInvokeBuilder('''
                    Foo()
                      ..actions = theActions
                    ''')}
                  }
                '''),
                expectedOutput: withFluxComponentUsage('''
                  main(FooStore theStore) {
                    final theActions = FooActions();
    
                    ${maybeInvokeBuilder('''
                    Foo()
                      ..store = theStore
                      ..actions = theActions
                    ''')}
                  }
                '''),
              );
            });
          });

          group('when a store var is available as a class field', () {
            test('unless the type does not match (uses null instead)',
                () async {
              await testSuggestor(
                isExpectedError: (err) =>
                    err.message.contains(RegExp(r"'theStore' isn't used.")),
                expectedPatchCount: 1,
                input: withFluxComponentUsage('''
                  class TheBaz {
                    final FooActions theActions;
                    final BazFooStore theStore;
                    TheBaz(this.theActions, this.theStore);
                    
                    someMethod() {
                      ${maybeInvokeBuilder('''
                      Foo()
                        ..actions = theActions
                      ''')}
                    }
                  }
                '''),
                expectedOutput: withFluxComponentUsage('''
                  class TheBaz {
                    final FooActions theActions;
                    final BazFooStore theStore;
                    TheBaz(this.theActions, this.theStore);
                    
                    someMethod() {
                      ${maybeInvokeBuilder('''
                      Foo()
                        ..store = null
                        ..actions = theActions
                      ''')}
                    }
                  }
                '''),
              );
            });

            test('and the type matches', () async {
              await testSuggestor(
                isExpectedError: (err) =>
                    err.message.contains(RegExp(r"'theStore' isn't used.")),
                expectedPatchCount: 1,
                input: withFluxComponentUsage('''
                  class TheFoo {
                    final FooActions theActions;
                    final FooStore theStore;
                    TheFoo(this.theActions, this.theStore);
                    
                    someMethod() {
                      ${maybeInvokeBuilder('''
                      Foo()
                        ..store = theStore
                      ''')}
                    }
                  }
                '''),
                expectedOutput: withFluxComponentUsage('''
                  class TheFoo {
                    final FooActions theActions;
                    final FooStore theStore;
                    TheFoo(this.theActions, this.theStore);
                    
                    someMethod() {
                      ${maybeInvokeBuilder('''
                      Foo()
                        ..actions = theActions
                        ..store = theStore
                      ''')}
                    }
                  }
                '''),
              );
            });
          });

          group('when a store var is available in function component props',
              () {
            test('unless the type does not match (uses null instead)',
                () async {
              await testSuggestor(
                isExpectedError: (err) => err.message.contains('someFunction'),
                expectedPatchCount: 1,
                input: withFluxComponentUsage('''
                  class FooConsumerProps = UiProps with FluxUiPropsMixin<BazFooActions, BazFooStore>;
                  final FooConsumer = uiFunction<FooConsumerProps>(
                    (localProps) {
                      someFunction() {
                        return ${maybeInvokeBuilder('''Foo()
                          ..actions = FooActions()
                        ''')}
                      }
                    
                      return null;
                    },
                    _\$FooConsumerConfig, // ignore: undefined_identifier
                  );
                '''),
                expectedOutput: withFluxComponentUsage('''
                  class FooConsumerProps = UiProps with FluxUiPropsMixin<BazFooActions, BazFooStore>;
                  final FooConsumer = uiFunction<FooConsumerProps>(
                    (localProps) {
                      someFunction() {
                        return ${maybeInvokeBuilder('''Foo()
                          ..store = null
                          ..actions = FooActions()
                        ''')}
                      }
                    
                      return null;
                    },
                    _\$FooConsumerConfig, // ignore: undefined_identifier
                  );
                '''),
              );
            });

            test('and the type matches', () async {
              await testSuggestor(
                isExpectedError: (err) => err.message.contains('someFunction'),
                expectedPatchCount: 1,
                input: withFluxComponentUsage('''
                  class FooConsumerProps = UiProps with FluxUiPropsMixin<FooActions, FooStore>;
                  final FooConsumer = uiFunction<FooConsumerProps>(
                    (localProps) {
                      someFunction() {
                        return ${maybeInvokeBuilder('''Foo()
                          ..actions = localProps.actions
                        ''')}
                      }
                    
                      return null;
                    },
                    _\$FooConsumerConfig, // ignore: undefined_identifier
                  );
                '''),
                expectedOutput: withFluxComponentUsage('''
                  class FooConsumerProps = UiProps with FluxUiPropsMixin<FooActions, FooStore>;
                  final FooConsumer = uiFunction<FooConsumerProps>(
                    (localProps) {
                      someFunction() {
                        return ${maybeInvokeBuilder('''Foo()
                          ..store = localProps.store
                          ..actions = localProps.actions
                        ''')}
                      }
                    
                      return null;
                    },
                    _\$FooConsumerConfig, // ignore: undefined_identifier
                  );
                '''),
              );
            });
          });

          group('when a store var is available in class component props', () {
            test('unless the type does not match (uses null instead)',
                () async {
              await testSuggestor(
                expectedPatchCount: 1,
                input: withFluxComponentUsage('''
                  // ignore: undefined_identifier
                  UiFactory<FooConsumerProps> FooConsumer = castUiFactory(_\$FooConsumer);
                  class FooConsumerProps = UiProps with FluxUiPropsMixin<BazFooActions, BazFooStore>;
                  class FooConsumerComponent extends FluxUiComponent2<FooConsumerProps> {
                    someMethod() {
                      return ${maybeInvokeBuilder('''Foo()
                        ..actions = FooActions()
                      ''')}
                    }
    
                    @override
                    render() => null;
                  }
                '''),
                expectedOutput: withFluxComponentUsage('''
                  // ignore: undefined_identifier
                  UiFactory<FooConsumerProps> FooConsumer = castUiFactory(_\$FooConsumer);
                  class FooConsumerProps = UiProps with FluxUiPropsMixin<BazFooActions, BazFooStore>;
                  class FooConsumerComponent extends FluxUiComponent2<FooConsumerProps> {
                    someMethod() {
                      return ${maybeInvokeBuilder('''Foo()
                        ..store = null
                        ..actions = FooActions()
                      ''')}
                    }
    
                    @override
                    render() => null;
                  }
                '''),
              );
            });

            test('and the type matches', () async {
              await testSuggestor(
                expectedPatchCount: 1,
                input: withFluxComponentUsage('''
                  // ignore: undefined_identifier
                  UiFactory<FooConsumerProps> FooConsumer = castUiFactory(_\$FooConsumer);
                  class FooConsumerProps = UiProps with FluxUiPropsMixin<FooActions, FooStore>;
                  class FooConsumerComponent extends FluxUiComponent2<FooConsumerProps> {
                    someMethod() {
                      return ${maybeInvokeBuilder('''Foo()
                        ..actions = props.actions
                      ''')}
                    }
    
                    @override
                    render() => null;
                  }
                '''),
                expectedOutput: withFluxComponentUsage('''
                  // ignore: undefined_identifier
                  UiFactory<FooConsumerProps> FooConsumer = castUiFactory(_\$FooConsumer);
                  class FooConsumerProps = UiProps with FluxUiPropsMixin<FooActions, FooStore>;
                  class FooConsumerComponent extends FluxUiComponent2<FooConsumerProps> {
                    someMethod() {
                      return ${maybeInvokeBuilder('''Foo()
                        ..store = props.store
                        ..actions = props.actions
                      ''')}
                    }
    
                    @override
                    render() => null;
                  }
                '''),
              );
            });
          });
        });

        group('have no store or actions setter', () {
          test('when no store or actions var is available in scope', () async {
            await testSuggestor(
              expectedPatchCount: 2,
              input: withFluxComponentUsage('''
                main() {
                  ${maybeInvokeBuilder('''Foo()
                    ..id = '123'
                  ''')}
                }
              '''),
              expectedOutput: withFluxComponentUsage('''
                main() {
                  ${maybeInvokeBuilder('''Foo()
                    ..store = null
                    ..actions = null
                    ..id = '123'
                  ''')}
                }
              '''),
            );
          });

          group('when store and/or actions var(s) are available', () {
            group('in top-level scope', () {
              test('unless the type(s) do not match (uses null instead):',
                  () async {
                await testSuggestor(
                  isExpectedError: (err) => err.message
                      .contains(RegExp(r"'(theStore|theActions)' isn't used.")),
                  expectedPatchCount: 2,
                  input: withFluxComponentUsage('''
                    final theStore = BazFooStore();
                    final theActions = BazFooActions();
                    main() {
                      ${maybeInvokeBuilder('''Foo()
                        ..id = '123'
                      ''')}
                    }
                  '''),
                  expectedOutput: withFluxComponentUsage('''
                    final theStore = BazFooStore();
                    final theActions = BazFooActions();
                    main() {
                      ${maybeInvokeBuilder('''Foo()
                        ..store = null
                        ..actions = null
                        ..id = '123'
                      ''')}
                    }
                  '''),
                );
              });

              group('and the type(s) match:', () {
                test('store AND actions', () async {
                  await testSuggestor(
                    isExpectedError: (err) => err.message.contains(
                        RegExp(r"'(theStore|theActions)' isn't used.")),
                    expectedPatchCount: 2,
                    input: withFluxComponentUsage('''
                      final theStore = FooStore();
                      final theActions = FooActions();
                      main() {
                        ${maybeInvokeBuilder('''Foo()
                          ..id = '123'
                        ''')}
                      }
                    '''),
                    expectedOutput: withFluxComponentUsage('''
                      final theStore = FooStore();
                      final theActions = FooActions();
                      main() {
                        ${maybeInvokeBuilder('''Foo()
                          ..store = theStore
                          ..actions = theActions
                          ..id = '123'
                        ''')}
                      }
                    '''),
                  );
                });

                test('store only', () async {
                  await testSuggestor(
                    isExpectedError: (err) =>
                        err.message.contains(RegExp(r"'theStore' isn't used.")),
                    expectedPatchCount: 2,
                    input: withFluxComponentUsage('''
                      final theStore = FooStore();
                      main() {
                        ${maybeInvokeBuilder('''Foo()
                          ..id = '123'
                        ''')}
                      }
                    '''),
                    expectedOutput: withFluxComponentUsage('''
                      final theStore = FooStore();
                      main() {
                        ${maybeInvokeBuilder('''Foo()
                          ..store = theStore
                          ..actions = null
                          ..id = '123'
                        ''')}
                      }
                    '''),
                  );
                });

                test('actions only', () async {
                  await testSuggestor(
                    isExpectedError: (err) => err.message
                        .contains(RegExp(r"'theActions' isn't used.")),
                    expectedPatchCount: 2,
                    input: withFluxComponentUsage('''
                      final theActions = FooActions();
                      main() {
                        ${maybeInvokeBuilder('''Foo()
                          ..id = '123'
                        ''')}
                      }
                    '''),
                    expectedOutput: withFluxComponentUsage('''
                    final theActions = FooActions();
                      main() {
                        ${maybeInvokeBuilder('''Foo()
                          ..store = null
                          ..actions = theActions
                          ..id = '123'
                        ''')}
                      }
                    '''),
                  );
                });
              });
            });

            group('in block function scope', () {
              test('unless the type(s) do not match (uses null instead):',
                  () async {
                await testSuggestor(
                  isExpectedError: (err) => err.message
                      .contains(RegExp(r"'(theStore|theActions)' isn't used.")),
                  expectedPatchCount: 2,
                  input: withFluxComponentUsage('''
                    main() {
                      final theStore = BazFooStore();
                      final theActions = BazFooActions();
      
                      ${maybeInvokeBuilder('''Foo()
                        ..id = '123'
                      ''')}
                    }
                  '''),
                  expectedOutput: withFluxComponentUsage('''
                    main() {
                      final theStore = BazFooStore();
                      final theActions = BazFooActions();
      
                      ${maybeInvokeBuilder('''Foo()
                        ..store = null
                        ..actions = null
                        ..id = '123'
                      ''')}
                    }
                  '''),
                );
              });

              group('and the type(s) match:', () {
                test('store AND actions', () async {
                  await testSuggestor(
                    isExpectedError: (err) => err.message.contains(
                        RegExp(r"'(theStore|theActions)' isn't used.")),
                    expectedPatchCount: 2,
                    input: withFluxComponentUsage('''
                      main() {
                        final theStore = FooStore();
                        final theActions = FooActions();
        
                        ${maybeInvokeBuilder('''Foo()
                          ..id = '123'
                        ''')}
                      }
                    '''),
                    expectedOutput: withFluxComponentUsage('''
                      main() {
                        final theStore = FooStore();
                        final theActions = FooActions();
        
                        ${maybeInvokeBuilder('''Foo()
                          ..store = theStore
                          ..actions = theActions
                          ..id = '123'
                        ''')}
                      }
                    '''),
                  );
                });

                test('store only', () async {
                  await testSuggestor(
                    isExpectedError: (err) =>
                        err.message.contains(RegExp(r"'theStore' isn't used.")),
                    expectedPatchCount: 2,
                    input: withFluxComponentUsage('''
                      main() {
                        final theStore = FooStore();
        
                        ${maybeInvokeBuilder('''Foo()
                          ..id = '123'
                        ''')}
                      }
                    '''),
                    expectedOutput: withFluxComponentUsage('''
                      main() {
                        final theStore = FooStore();
        
                        ${maybeInvokeBuilder('''Foo()
                          ..store = theStore
                          ..actions = null
                          ..id = '123'
                        ''')}
                      }
                    '''),
                  );
                });

                test('actions only', () async {
                  await testSuggestor(
                    isExpectedError: (err) => err.message
                        .contains(RegExp(r"'theActions' isn't used.")),
                    expectedPatchCount: 2,
                    input: withFluxComponentUsage('''
                      main() {
                        final theActions = FooActions();
        
                        ${maybeInvokeBuilder('''Foo()
                          ..id = '123'
                        ''')}
                      }
                    '''),
                    expectedOutput: withFluxComponentUsage('''
                      main() {
                        final theActions = FooActions();
        
                        ${maybeInvokeBuilder('''Foo()
                          ..store = null
                          ..actions = theActions
                          ..id = '123'
                        ''')}
                      }
                    '''),
                  );
                });
              });
            });

            group('in function component props', () {
              test('unless the types do not match (uses null instead):',
                  () async {
                await testSuggestor(
                  isExpectedError: (err) =>
                      err.message.contains('someFunction'),
                  expectedPatchCount: 2,
                  input: withFluxComponentUsage('''
                    class FooConsumerProps = UiProps with FluxUiPropsMixin<BazFooActions, BazFooStore>;
                    final FooConsumer = uiFunction<FooConsumerProps>(
                      (localProps) {
                        someFunction() {
                          return ${maybeInvokeBuilder('''Foo()
                            ..id = '123'
                          ''')}
                        }
                      
                        return null;
                      },
                      _\$FooConsumerConfig, // ignore: undefined_identifier
                    );
                '''),
                  expectedOutput: withFluxComponentUsage('''
                    class FooConsumerProps = UiProps with FluxUiPropsMixin<BazFooActions, BazFooStore>;
                    final FooConsumer = uiFunction<FooConsumerProps>(
                      (localProps) {
                        someFunction() {
                          return ${maybeInvokeBuilder('''Foo()
                            ..store = null
                            ..actions = null
                            ..id = '123'
                          ''')}
                        }
                      
                        return null;
                      },
                      _\$FooConsumerConfig, // ignore: undefined_identifier
                    );
                  '''),
                );
              });

              test('and the types match:', () async {
                await testSuggestor(
                  isExpectedError: (err) =>
                      err.message.contains('someFunction'),
                  expectedPatchCount: 2,
                  input: withFluxComponentUsage('''
                    class FooConsumerProps = UiProps with FluxUiPropsMixin<FooActions, FooStore>;
                    final FooConsumer = uiFunction<FooConsumerProps>(
                      (localProps) {
                        someFunction() {
                          return ${maybeInvokeBuilder('''Foo()
                            ..id = '123'
                          ''')}
                        }
                      
                        return null;
                      },
                      _\$FooConsumerConfig, // ignore: undefined_identifier
                    );
                  '''),
                  expectedOutput: withFluxComponentUsage('''
                    class FooConsumerProps = UiProps with FluxUiPropsMixin<FooActions, FooStore>;
                    final FooConsumer = uiFunction<FooConsumerProps>(
                      (localProps) {
                        someFunction() {
                          return ${maybeInvokeBuilder('''Foo()
                            ..store = localProps.store
                            ..actions = localProps.actions
                            ..id = '123'
                          ''')}
                        }
                      
                        return null;
                      },
                      _\$FooConsumerConfig, // ignore: undefined_identifier
                    );
                  '''),
                );
              });
            });

            group('in class component props', () {
              test('unless the types do not match (uses null instead):',
                  () async {
                await testSuggestor(
                  expectedPatchCount: 2,
                  input: withFluxComponentUsage('''
                    // ignore: undefined_identifier
                    UiFactory<FooConsumerProps> FooConsumer = castUiFactory(_\$FooConsumer);
                    class FooConsumerProps = UiProps with FluxUiPropsMixin<BazFooActions, BazFooStore>;
                    class FooConsumerComponent extends FluxUiComponent2<FooConsumerProps> {
                      someMethod() {
                        return ${maybeInvokeBuilder('''Foo()
                          ..id = '123'
                        ''')}
                      }
      
                      @override
                      render() => null;
                    }
                  '''),
                  expectedOutput: withFluxComponentUsage('''
                    // ignore: undefined_identifier
                    UiFactory<FooConsumerProps> FooConsumer = castUiFactory(_\$FooConsumer);
                    class FooConsumerProps = UiProps with FluxUiPropsMixin<BazFooActions, BazFooStore>;
                    class FooConsumerComponent extends FluxUiComponent2<FooConsumerProps> {
                      someMethod() {
                        return ${maybeInvokeBuilder('''Foo()
                          ..store = null
                          ..actions = null
                          ..id = '123'
                        ''')}
                      }
      
                      @override
                      render() => null;
                    }
                  '''),
                );
              });

              test('and the types match:', () async {
                await testSuggestor(
                  expectedPatchCount: 2,
                  input: withFluxComponentUsage('''
                    // ignore: undefined_identifier
                    UiFactory<FooConsumerProps> FooConsumer = castUiFactory(_\$FooConsumer);
                    class FooConsumerProps = UiProps with FluxUiPropsMixin<FooActions, FooStore>;
                    class FooConsumerComponent extends FluxUiComponent2<FooConsumerProps> {
                      someMethod() {
                        return ${maybeInvokeBuilder('''Foo()
                          ..id = '123'
                        ''')}
                      }
      
                      @override
                      render() => null;
                    }
                  '''),
                  expectedOutput: withFluxComponentUsage('''
                    // ignore: undefined_identifier
                    UiFactory<FooConsumerProps> FooConsumer = castUiFactory(_\$FooConsumer);
                    class FooConsumerProps = UiProps with FluxUiPropsMixin<FooActions, FooStore>;
                    class FooConsumerComponent extends FluxUiComponent2<FooConsumerProps> {
                      someMethod() {
                        return ${maybeInvokeBuilder('''Foo()
                          ..store = props.store
                          ..actions = props.actions
                          ..id = '123'
                        ''')}
                      }
      
                      @override
                      render() => null;
                    }
                  '''),
                );
              });
            });
          });
        });
      });
    }

    sharedTests(invokeBuilder: false);
    sharedTests(invokeBuilder: true);
  });
}

String withFluxComponentUsage(String source,
    {String? actionsName = 'FooActions', String? storeName = 'FooStore'}) {
  String getActionsClasses() => actionsName == null
      ? ''
      : '''
class $actionsName {
  $actionsName();
}

class Baz$actionsName {
  Baz$actionsName();
}
''';

  String getStoreClasses() => storeName == null
      ? ''
      : '''
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

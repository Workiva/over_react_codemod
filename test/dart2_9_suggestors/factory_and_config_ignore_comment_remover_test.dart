// Copyright 2021 Workiva Inc.
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

import 'package:over_react_codemod/src/dart2_9_suggestors/dart2_9_constants.dart';
import 'package:over_react_codemod/src/dart2_9_suggestors/factory_and_config_ignore_comment_remover.dart';
import 'package:test/test.dart';

import '../util.dart';

main() {
  group('FactoryAndConfigIgnoreCommentRemover', () {
    group('removing `undefined_identifier` ignore comments', () {
      ignoreRemoverTestHelper('undefined_identifier');
    });

    group('removing `argument_type_not_assignable` ignore comments', () {
      ignoreRemoverTestHelper('argument_type_not_assignable');
    });
  });
}

void ignoreRemoverTestHelper(String ignoreToRemove) {
  final testSuggestor =
      getSuggestorTester(FactoryAndConfigIgnoreCommentRemover(ignoreToRemove));

  test('empty file', () {
    testSuggestor(expectedPatchCount: 0, input: '');
  });

  test('no matches', () {
    testSuggestor(
      expectedPatchCount: 0,
      input: '''
        library foo;
        var a = 'b';
        class Foo {}
      ''',
    );
  });

  group('on Component Factory Declarations:', () {
    group('does not remove', () {
      test('ignore comments from legacy boilerplate', () {
        testSuggestor(
          expectedPatchCount: 0,
          input: '''
            @Factory()
            // ignore: $ignoreToRemove
            UiFactory<FooProps> Foo =
              // ignore: $ignoreToRemove
              _\$Foo; // ignore: $ignoreToRemove
          ''',
        );
      });

      test('other ignore comments', () {
        testSuggestor(
          expectedPatchCount: 0,
          input: '''
            // ignore: invalid_assignment
            UiFactory<FooProps> Foo =
              // ignore: unused_element
              _\$Foo; // ignore: unused_element
          ''',
        );
      });

      test('from a non-component factory declaration', () {
        testSuggestor(
          expectedPatchCount: 0,
          input: '''
            DriverFactory driverFactory = createDriver; // ignore: $ignoreToRemove
          ''',
        );
      });
    });

    group('correctly removes $ignoreToRemove ignore comments', () {
      test('when the comment is on the same line', () {
        testSuggestor(
          expectedPatchCount: 1,
          input: '''
            UiFactory<FooProps> Foo = _\$Foo; // ignore: $ignoreToRemove
          ''',
          expectedOutput: '''
            UiFactory<FooProps> Foo = _\$Foo;
          ''',
        );
      });

      test('when the comment is on the initializer', () {
        testSuggestor(
          expectedPatchCount: 1,
          input: '''
            UiFactory<FooProps> Foo =
              // ignore: $ignoreToRemove
              _\$Foo;
          ''',
          expectedOutput: '''
            UiFactory<FooProps> Foo = _\$Foo;
          ''',
        );
      });

      test('when the comment is on the preceding line', () {
        testSuggestor(
          expectedPatchCount: 1,
          input: '''
            // ignore: $ignoreToRemove
            UiFactory<FooProps> Foo = _\$Foo;
          ''',
          expectedOutput: '''
            UiFactory<FooProps> Foo = _\$Foo;
          ''',
        );
      });

      test('when there is another comment above it', () {
        testSuggestor(
          expectedPatchCount: 1,
          input: '''
            // this is another comment
            // ignore: $ignoreToRemove
            UiFactory<FooProps> Foo = _\$Foo; 
          ''',
          expectedOutput: '''
            // this is another comment
            UiFactory<FooProps> Foo = _\$Foo; 
          ''',
        );
      });

      test('when there is a doc comment above it', () {
        testSuggestor(
          expectedPatchCount: 1,
          input: '''
            /// this is a doc comment
            // ignore: $ignoreToRemove
            UiFactory<FooProps> Foo = _\$Foo; 
          ''',
          expectedOutput: '''
            /// this is a doc comment
            UiFactory<FooProps> Foo = _\$Foo; 
          ''',
        );
      });

      test('when there are multiple factories', () {
        testSuggestor(
          expectedPatchCount: 3,
          input: '''
            UiFactory<FooProps> Foo = _\$Foo; // ignore: $ignoreToRemove
            
            UiFactory<BarProps> Bar = 
              // ignore: $ignoreToRemove
              _\$Bar; 
            
            // ignore: $ignoreToRemove
            UiFactory<BazProps> Baz = _\$Baz;
          ''',
          expectedOutput: '''
            UiFactory<FooProps> Foo = _\$Foo;
            
            UiFactory<BarProps> Bar = _\$Bar;
            
            UiFactory<BazProps> Baz = _\$Baz;
          ''',
        );
      });

      group('when there are multiple ignores', () {
        test('in the same comment', () {
          testSuggestor(
            expectedPatchCount: 1,
            input: '''
              UiFactory<FooProps> Foo = _\$Foo; // ignore: invalid_assignment, $ignoreToRemove, unused_element
            ''',
            expectedOutput: '''
              UiFactory<FooProps> Foo = _\$Foo; // ignore: invalid_assignment, unused_element
            ''',
          );
        });

        test('in different comments', () {
          testSuggestor(
            expectedPatchCount: 3,
            input: '''
              // ignore: $ignoreToRemove, unused_element
              UiFactory<FooProps> Foo = 
                // ignore: $ignoreToRemove
                _\$Foo; // ignore: invalid_assignment, $ignoreToRemove
            ''',
            expectedOutput: '''
              // ignore: unused_element
              UiFactory<FooProps> Foo = _\$Foo; // ignore: invalid_assignment
            ''',
          );
        });
      });

      test('when the factory is already updated', () {
        testSuggestor(
          expectedPatchCount: 1,
          input: '''
            UiFactory<FooProps> Foo = $castFunctionName(_\$Foo); // ignore: $ignoreToRemove
          ''',
          expectedOutput: '''
            UiFactory<FooProps> Foo = $castFunctionName(_\$Foo); 
          ''',
        );
      });
    });
  });

  group('on Connected Components:', () {
    void _testCommentLocations(String generatedArg) {
      group('and the comment is on the same line', () {
        test('after the comma', () {
          testSuggestor(
            expectedPatchCount: 1,
            input: '''
              UiFactory<FooProps> Foo = connect<SomeState, FooProps>(
                mapStateToProps: (state) => (Foo()
                  ..foo = state.foo
                  ..bar = state.bar
                ),
              )(
                $generatedArg, // ignore: $ignoreToRemove
              );
            ''',
            expectedOutput: '''
              UiFactory<FooProps> Foo = connect<SomeState, FooProps>(
                mapStateToProps: (state) => (Foo()
                  ..foo = state.foo
                  ..bar = state.bar
                ),
              )(
                $generatedArg,
              );
            ''',
          );
        });

        test('after the semicolon', () {
          testSuggestor(
            expectedPatchCount: 1,
            input: '''
              UiFactory<FooProps> Foo = connect<SomeState, FooProps>(
                mapStateToProps: (state) => (Foo()
                  ..foo = state.foo
                  ..bar = state.bar
                ),
              )($generatedArg); // ignore: $ignoreToRemove
            ''',
            expectedOutput: '''
              UiFactory<FooProps> Foo = connect<SomeState, FooProps>(
                mapStateToProps: (state) => (Foo()
                  ..foo = state.foo
                  ..bar = state.bar
                ),
              )($generatedArg);
            ''',
          );
        });
      });

      test('and the comment is on the preceding line', () {
        testSuggestor(
          expectedPatchCount: 1,
          input: '''
            UiFactory<FooProps> Foo = connect<SomeState, FooProps>(
              mapStateToProps: (state) => (Foo()
                ..foo = state.foo
                ..bar = state.bar
              ),
            )(
              // ignore: $ignoreToRemove
              $generatedArg,
            );
          ''',
          expectedOutput: '''
            UiFactory<FooProps> Foo = connect<SomeState, FooProps>(
              mapStateToProps: (state) => (Foo()
                ..foo = state.foo
                ..bar = state.bar
              ),
            )(
              $generatedArg,
            );
          ''',
        );
      });
    }

    group('does not remove', () {
      test('other ignore comments', () {
        testSuggestor(
          expectedPatchCount: 0,
          input: '''
            UiFactory<FooProps> Foo = connect<SomeState, FooProps>(
              mapStateToProps: (state) => (Foo()
                ..foo = state.foo
                ..bar = state.bar
              ),
            )(_\$Foo); // ignore: something_else
          ''',
        );
      });
    });

    group('correctly removes $ignoreToRemove ignore comments', () {
      group('when the generated factory is not type casted', () {
        _testCommentLocations('_\$Foo');
      });

      group('when the generated factory is type casted', () {
        _testCommentLocations('$castFunctionName(_\$Foo)');
      });

      test('for `connectFlux` function', () {
        testSuggestor(
          expectedPatchCount: 1,
          input: '''
              UiFactory<FooProps> Foo = connectFlux<SomeState, FooProps>(
                mapStateToProps: (state) => (Foo()
                  ..foo = state.foo
                  ..bar = state.bar
                ),
              )(_\$Foo); // ignore: $ignoreToRemove
            ''',
          expectedOutput: '''
              UiFactory<FooProps> Foo = connectFlux<SomeState, FooProps>(
                mapStateToProps: (state) => (Foo()
                  ..foo = state.foo
                  ..bar = state.bar
                ),
              )(_\$Foo);
            ''',
        );
      });

      test('for `composeHocs` function', () {
        testSuggestor(
          expectedPatchCount: 1,
          input: '''
            UiFactory<FooProps> Foo = composeHocs([
              connect<RandomColorStore, FooProps>(
                context: randomColorStoreContext,
                mapStateToProps: (_) => {},
                pure: false,
              ),
              connect<LowLevelStore, FooProps>(
                context: lowLevelStoreContext,
                mapStateToProps: (_) => {},
                pure: false,
              ),
            ])(_\$Foo); // ignore: undefined_identifier
          ''',
          expectedOutput: '''
            UiFactory<FooProps> Foo = composeHocs([
              connect<RandomColorStore, FooProps>(
                context: randomColorStoreContext,
                mapStateToProps: (_) => {},
                pure: false,
              ),
              connect<LowLevelStore, FooProps>(
                context: lowLevelStoreContext,
                mapStateToProps: (_) => {},
                pure: false,
              ),
            ])(_\$Foo);
          ''',
        );
      });

      test('when there are two factories', () {
        testSuggestor(
          expectedPatchCount: 1,
          input: '''
            UiFactory<FooProps> UnconnectedFoo = _\$UnconnectedFoo; // ignore: $ignoreToRemove
            
            UiFactory<FooProps> Foo =
                connect<SomeState, FooProps>(
              mapStateToProps: (state) => (UnconnectedFoo()
                ..foo = state.foo
                ..bar = state.bar
              ),
            )(UnconnectedFoo);
          ''',
          expectedOutput: '''
            UiFactory<FooProps> UnconnectedFoo = _\$UnconnectedFoo;
            
            UiFactory<FooProps> Foo =
                connect<SomeState, FooProps>(
              mapStateToProps: (state) => (UnconnectedFoo()
                ..foo = state.foo
                ..bar = state.bar
              ),
            )(UnconnectedFoo);
          ''',
        );
      });

      test('when there are multiple ignores', () {
        testSuggestor(
          expectedPatchCount: 1,
          input: '''
            UiFactory<FooProps> Foo = connect<SomeState, FooProps>(
              mapStateToProps: (state) => (Foo()
                ..foo = state.foo
                ..bar = state.bar
              ),
            )(_\$Foo); // ignore: $ignoreToRemove, another_ignore
          ''',
          expectedOutput: '''
            UiFactory<FooProps> Foo = connect<SomeState, FooProps>(
              mapStateToProps: (state) => (Foo()
                ..foo = state.foo
                ..bar = state.bar
              ),
            )(_\$Foo); // ignore: another_ignore
          ''',
        );
      });
    });
  });

  group('on Factory Configs:', () {
    void _testCommentLocations(String configArg) {
      group('and the comment is on the same line', () {
        test('after the comma', () {
          testSuggestor(
            expectedPatchCount: 1,
            input: '''
              final Foo = uiForwardRef<FooProps>(
                (props, ref) {},
                $configArg, // ignore: $ignoreToRemove
              );
            ''',
            expectedOutput: '''
              final Foo = uiForwardRef<FooProps>(
                (props, ref) {},
                $configArg,
              );
            ''',
          );
        });

        test('after the semicolon', () {
          testSuggestor(
            expectedPatchCount: 1,
            input: '''
              UiFactory<FooProps> Foo = uiFunction(
                (props) {},
                $configArg); // ignore: $ignoreToRemove
            ''',
            expectedOutput: '''
              UiFactory<FooProps> Foo = uiFunction(
                (props) {}, 
                $configArg);
            ''',
          );
        });
      });

      test('and the comment is on the preceding line', () {
        testSuggestor(
          expectedPatchCount: 1,
          input: '''
            UiFactory<FooProps> Foo = uiFunction(
              (props) {}, 
              // ignore: $ignoreToRemove
              $configArg, 
            );
          ''',
          expectedOutput: '''
            UiFactory<FooProps> Foo = uiFunction(
              (props) {}, 
              $configArg, 
            );
          ''',
        );
      });
    }

    group('does not remove', () {
      test('other ignore comments', () {
        testSuggestor(
          expectedPatchCount: 0,
          input: '''
            final Foo = uiFunction<FooProps>(
              (props) {}, 
              // ignore: invalid_assignment
              \$FooConfig, // ignore: unused_element
            );
          ''',
        );
      });
    });

    group('correctly removes $ignoreToRemove ignore comments', () {
      group('when the generated config is public', () {
        _testCommentLocations('\$FooConfig');
      });

      group('when the generated config is private', () {
        _testCommentLocations('_\$FooConfig');
      });

      test('when there are multiple factories', () {
        testSuggestor(
          expectedPatchCount: 2,
          input: '''
            final Foo = uiForwardRef<FooProps>(
              (props, ref) {},
              \$FooConfig, // ignore: $ignoreToRemove
            );
            
            UiFactory<BarProps> Bar = uiFunction(
              (props) {}, 
              // ignore: $ignoreToRemove
              \$BarConfig, 
            );
          ''',
          expectedOutput: '''
            final Foo = uiForwardRef<FooProps>(
              (props, ref) {},
              \$FooConfig,
            );
            
            UiFactory<BarProps> Bar = uiFunction(
              (props) {}, 
              \$BarConfig, 
            );
          ''',
        );
      });

      group('when there are multiple ignores', () {
        test('in the same comment', () {
          testSuggestor(
            expectedPatchCount: 1,
            input: '''
              UiFactory<FooProps> Foo = uiFunction(
                (props) {}, 
                \$FooConfig, // ignore: invalid_assignment, $ignoreToRemove, unused_element
              );
            ''',
            expectedOutput: '''
              UiFactory<FooProps> Foo = uiFunction(
                (props) {}, 
                \$FooConfig, // ignore: invalid_assignment, unused_element
              );
            ''',
          );
        });

        test('in different comments', () {
          testSuggestor(
            expectedPatchCount: 2,
            input: '''
              final Foo = uiFunction<FooProps>(
                (props) {}, 
                // ignore: $ignoreToRemove
                \$FooConfig, // ignore: $ignoreToRemove, unused_element
              );
            ''',
            expectedOutput: '''
              final Foo = uiFunction<FooProps>(
                (props) {}, 
                
                \$FooConfig, // ignore: unused_element
              );
            ''',
          );
        });
      });

      test('when wrapped in an hoc', () {
        testSuggestor(
          expectedPatchCount: 1,
          input: '''
            UiFactory<FooProps> Foo = someHOC(uiFunction(
              (props) {}, 
              \$FooConfig, // ignore: $ignoreToRemove
            ));
          ''',
          expectedOutput: '''
            UiFactory<FooProps> Foo = someHOC(uiFunction(
              (props) {}, 
              \$FooConfig,
            ));
          ''',
        );
      });
    });
  });
}

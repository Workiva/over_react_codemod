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
import 'package:over_react_codemod/src/dart2_9_suggestors/generated_factory_migrator.dart';
import 'package:test/test.dart';

import '../util.dart';

main() {
  group('GeneratedFactoryMigrator', () {
    final testSuggestor = getSuggestorTester(GeneratedFactoryMigrator());

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
      group('does not update', () {
        test('legacy boilerplate', () {
          testSuggestor(
            expectedPatchCount: 0,
            input: '''
              @Factory()
              UiFactory<FooProps> Foo = _\$Foo; // ignore: undefined_identifier
            ''',
          );
        });

        test('a non-component factory declaration', () {
          testSuggestor(
            expectedPatchCount: 0,
            input: '''
              DriverFactory driverFactory = createDriver;
            ''',
          );
        });

        test('if already updated', () {
          testSuggestor(
            expectedPatchCount: 0,
            input: '''
              UiFactory<FooProps> Foo = $castFunctionName(_\$Foo); // ignore: undefined_identifier
            ''',
          );
        });
      });

      test('correctly updates declaration', () {
        testSuggestor(
          expectedPatchCount: 2,
          input: '''
            UiFactory<FooProps> Foo = _\$Foo; // ignore: undefined_identifier
          ''',
          expectedOutput: '''
            UiFactory<FooProps> Foo = $castFunctionName(_\$Foo); // ignore: undefined_identifier
          ''',
        );
      });

      test('when there are multiple factories', () {
        testSuggestor(
          expectedPatchCount: 6,
          input: '''
            UiFactory<FooProps> Foo = _\$Foo; // ignore: undefined_identifier
            
            UiFactory<BarProps> Bar = 
              // ignore: undefined_identifier
              _\$Bar; 
            
            // ignore: undefined_identifier
            UiFactory<BazProps> Baz = _\$Baz;
          ''',
          expectedOutput: '''
            UiFactory<FooProps> Foo = $castFunctionName(_\$Foo); // ignore: undefined_identifier
            
            UiFactory<BarProps> Bar = 
              // ignore: undefined_identifier
              $castFunctionName(_\$Bar); 
            
            // ignore: undefined_identifier
            UiFactory<BazProps> Baz = $castFunctionName(_\$Baz);
          ''',
        );
      });
    });

    group('on Connected Components:', () {
      group('does not update', () {
        test('if already updated', () {
          testSuggestor(
            expectedPatchCount: 0,
            input: '''
              UiFactory<FooProps> Foo = connect<SomeState, FooProps>(
                mapStateToProps: (state) => (Foo()
                  ..foo = state.foo
                  ..bar = state.bar
                ),
              )($castFunctionName(_\$Foo)); // ignore: undefined_identifier
            ''',
          );
        });

        test('factory config arguments', () {
          testSuggestor(
            expectedPatchCount: 0,
            input: '''
              UiFactory<FooProps> Foo = uiFunction(
                (props) {},
                _\$FooConfig, // ignore: undefined_identifier
              );
            ''',
          );
        });

        test('generated arguments in non-connect method calls', () {
          testSuggestor(
            expectedPatchCount: 0,
            input: '''
              UiFactory<FooProps> Foo = someMethod(_\$Foo);
            ''',
          );
        });
      });

      test('with `connectFlux` function', () {
        testSuggestor(
          expectedPatchCount: 2,
          input: '''
            UiFactory<FooProps> Foo = connectFlux<SomeState, FooProps>(
              mapStateToProps: (state) => (Foo()
                ..foo = state.foo
                ..bar = state.bar
              ),
            )(_\$Foo); // ignore: undefined_identifier
          ''',
          expectedOutput: '''
            UiFactory<FooProps> Foo = connectFlux<SomeState, FooProps>(
              mapStateToProps: (state) => (Foo()
                ..foo = state.foo
                ..bar = state.bar
              ),
            )($castFunctionName(_\$Foo)); // ignore: undefined_identifier
          ''',
        );
      });

      test('with `composeHocs` function', () {
        testSuggestor(
          expectedPatchCount: 2,
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
            ])(castUiFactory(_\$Foo)); // ignore: undefined_identifier
          ''',
        );
      });

      test('without trailing comma', () {
        testSuggestor(
          expectedPatchCount: 2,
          input: '''
            UiFactory<FooProps> Foo = connect<SomeState, FooProps>(
              mapStateToProps: (state) => (Foo()
                ..foo = state.foo
                ..bar = state.bar
              ),
            )(_\$Foo); // ignore: undefined_identifier
          ''',
          expectedOutput: '''
            UiFactory<FooProps> Foo = connect<SomeState, FooProps>(
              mapStateToProps: (state) => (Foo()
                ..foo = state.foo
                ..bar = state.bar
              ),
            )($castFunctionName(_\$Foo)); // ignore: undefined_identifier
          ''',
        );
      });

      test('with trailing comma', () {
        testSuggestor(
          expectedPatchCount: 2,
          input: '''
            UiFactory<FooProps> Foo = connect<SomeState, FooProps>(
              mapStateToProps: (state) => (Foo()
                ..foo = state.foo
                ..bar = state.bar
              ),
            )(
              _\$Foo, // ignore: undefined_identifier
            );
          ''',
          expectedOutput: '''
            UiFactory<FooProps> Foo = connect<SomeState, FooProps>(
              mapStateToProps: (state) => (Foo()
                ..foo = state.foo
                ..bar = state.bar
              ),
            )(
              $castFunctionName(_\$Foo), // ignore: undefined_identifier
            );
          ''',
        );
      });

      test('when there are two factories', () {
        testSuggestor(
          expectedPatchCount: 2,
          input: '''
            UiFactory<FooProps> UnconnectedFoo = _\$UnconnectedFoo; // ignore: undefined_identifier
            
            UiFactory<FooProps> Foo =
                connect<SomeState, FooProps>(
              mapStateToProps: (state) => (UnconnectedFoo()
                ..foo = state.foo
                ..bar = state.bar
              ),
            )(UnconnectedFoo);
          ''',
          expectedOutput: '''
            UiFactory<FooProps> UnconnectedFoo = $castFunctionName(_\$UnconnectedFoo); // ignore: undefined_identifier
            
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
    });
  });
}

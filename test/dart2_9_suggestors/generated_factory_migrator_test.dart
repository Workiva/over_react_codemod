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
            input: r'''
              @Factory()
              UiFactory<FooProps> Foo = _$Foo; // ignore: undefined_identifier
            ''',
          );
        });

        test('a non-component factory declaration', () {
          testSuggestor(
            expectedPatchCount: 0,
            input: r'''
              DriverFactory driverFactory = createDriver;
            ''',
          );
        });

        test('if already updated', () {
          testSuggestor(
            expectedPatchCount: 0,
            input: r'''
              final Foo = _$Foo as UiFactory<FooProps>; // ignore: undefined_identifier
            ''',
          );
        });
      });

      test('correctly updates declaration', () {
        testSuggestor(
          expectedPatchCount: 2,
          input: r'''
            UiFactory<FooProps> Foo = _$Foo; // ignore: undefined_identifier
          ''',
          expectedOutput: r'''
            final Foo = _$Foo as UiFactory<FooProps>; // ignore: undefined_identifier
          ''',
        );
      });

      test('when there are multiple factories', () {
        testSuggestor(
          expectedPatchCount: 6,
          input: r'''
            UiFactory<FooProps> Foo = _$Foo; // ignore: undefined_identifier
            
            UiFactory<BarProps> Bar = 
              // ignore: undefined_identifier
              _$Bar; 
            
            // ignore: undefined_identifier
            UiFactory<BazProps> Baz = _$Baz;
          ''',
          expectedOutput: r'''
            final Foo = _$Foo as UiFactory<FooProps>; // ignore: undefined_identifier
            
            final Bar = 
              // ignore: undefined_identifier
              _$Bar as UiFactory<BarProps>; 
            
            // ignore: undefined_identifier
            final Baz = _$Baz as UiFactory<BazProps>;
          ''',
        );
      });
    });

    group('on Connected Components:', () {
      test('does not update if already updated', () {
        testSuggestor(
          expectedPatchCount: 0,
          input: r'''
            UiFactory<FooProps> Foo = connect<SomeState, FooProps>(
              mapStateToProps: (state) => (Foo()
                ..foo = state.foo
                ..bar = state.bar
              ),
            )(_$Foo as UiFactoryConfig<FooProps>); // ignore: undefined_identifier
          ''',
        );
      });

      test('without trailing comma', () {
        testSuggestor(
          expectedPatchCount: 1,
          input: r'''
            UiFactory<FooProps> Foo = connect<SomeState, FooProps>(
              mapStateToProps: (state) => (Foo()
                ..foo = state.foo
                ..bar = state.bar
              ),
            )(_$Foo); // ignore: undefined_identifier
          ''',
          expectedOutput: r'''
            UiFactory<FooProps> Foo = connect<SomeState, FooProps>(
              mapStateToProps: (state) => (Foo()
                ..foo = state.foo
                ..bar = state.bar
              ),
            )(_$Foo as UiFactory<FooProps>); // ignore: undefined_identifier
          ''',
        );
      });

      test('with trailing comma', () {
        testSuggestor(
          expectedPatchCount: 1,
          input: r'''
            UiFactory<FooProps> Foo = connect<SomeState, FooProps>(
              mapStateToProps: (state) => (Foo()
                ..foo = state.foo
                ..bar = state.bar
              ),
            )(
              _$Foo, // ignore: undefined_identifier
            );
          ''',
          expectedOutput: r'''
            UiFactory<FooProps> Foo = connect<SomeState, FooProps>(
              mapStateToProps: (state) => (Foo()
                ..foo = state.foo
                ..bar = state.bar
              ),
            )(
              _$Foo as UiFactory<FooProps>, // ignore: undefined_identifier
            );
          ''',
        );
      });

      test('when there are multiple components', () {
        testSuggestor(
          expectedPatchCount: 2,
          input: r'''
            UiFactory<FooProps> Foo = connect<SomeState, FooProps>(
              mapStateToProps: (state) => (Foo()
                ..foo = state.foo
                ..bar = state.bar
              ),
            )(_$Foo); // ignore: undefined_identifier
            
            UiFactory<BarProps> Bar = connect<SomeState, BarProps>(
              mapStateToProps: (state) => (Bar()
                ..foo = state.foo
                ..bar = state.bar
              ),
            )(_$Bar); // ignore: undefined_identifier
          ''',
          expectedOutput: r'''
            UiFactory<FooProps> Foo = connect<SomeState, FooProps>(
              mapStateToProps: (state) => (Foo()
                ..foo = state.foo
                ..bar = state.bar
              ),
            )(_$Foo as UiFactory<FooProps>); // ignore: undefined_identifier
            
            UiFactory<BarProps> Bar = connect<SomeState, BarProps>(
              mapStateToProps: (state) => (Bar()
                ..foo = state.foo
                ..bar = state.bar
              ),
            )(_$Bar as UiFactory<BarProps>); // ignore: undefined_identifier
          ''',
        );
      });
    });

    group('on Factory Configs:', () {
      test('does not update if already updated', () {
        testSuggestor(
          expectedPatchCount: 0,
          input: r'''
            final Foo = uiFunction<FooProps>(
              (props) {}, 
              _$FooConfig as UiFactoryConfig<FooProps>, // ignore: undefined_identifier
            );
          ''',
        );
      });

      test('with left hand typing', () {
        testSuggestor(
          expectedPatchCount: 4,
          input: r'''
          UiFactory<BarProps> Bar = uiFunction(
            (props) {}, 
            $BarConfig, // ignore: undefined_identifier
          );
        ''',
          expectedOutput: r'''
          final Bar = uiFunction<BarProps>(
            (props) {}, 
            _$BarConfig as UiFactoryConfig<BarProps>, // ignore: undefined_identifier
          );
        ''',
        );
      });

      test('without left hand typing', () {
        testSuggestor(
          expectedPatchCount: 2,
          input: r'''
            final Foo = uiForwardRef<FooProps>(
              (props, ref) {},
              $FooConfig, // ignore: undefined_identifier
            );
          ''',
          expectedOutput: r'''
            final Foo = uiForwardRef<FooProps>(
              (props, ref) {},
              _$FooConfig as UiFactoryConfig<FooProps>, // ignore: undefined_identifier
            );
          ''',
        );
      });

      test('when the config is already private', () {
        testSuggestor(
          expectedPatchCount: 3,
          input: r'''
            UiFactory<BarProps> Bar = uiFunction(
              (props) {}, 
              _$BarConfig, // ignore: undefined_identifier
            );
          ''',
          expectedOutput: r'''
            final Bar = uiFunction<BarProps>(
              (props) {}, 
              _$BarConfig as UiFactoryConfig<BarProps>, // ignore: undefined_identifier
            );
          ''',
        );
      });

      test('already updated, but the config is public', () {
        testSuggestor(
          expectedPatchCount: 1,
          input: r'''
            final Foo = uiFunction<FooProps>(
              (props) {}, 
              $FooConfig as UiFactoryConfig<FooProps>, // ignore: undefined_identifier
            );
          ''',
          expectedOutput: r'''
            final Foo = uiFunction<FooProps>(
              (props) {}, 
              _$FooConfig as UiFactoryConfig<FooProps>, // ignore: undefined_identifier
            );
          ''',
        );
      });

      test('without trailing comma', () {
        testSuggestor(
          expectedPatchCount: 4,
          input: r'''
            UiFactory<BarProps> Bar = uiFunction((props) {}, $BarConfig); // ignore: undefined_identifier
          ''',
          expectedOutput: r'''
            final Bar = uiFunction<BarProps>((props) {}, _$BarConfig as UiFactoryConfig<BarProps>); // ignore: undefined_identifier
          ''',
        );
      });

      test('when there are multiple factories', () {
        testSuggestor(
          expectedPatchCount: 6,
          input: r'''
            final Foo = uiForwardRef<FooProps>(
              (props, ref) {},
              $FooConfig, // ignore: undefined_identifier
            );
            
            UiFactory<BarProps> Bar = uiFunction(
              (props) {}, 
              $BarConfig, // ignore: undefined_identifier
            );
          ''',
          expectedOutput: r'''
            final Foo = uiForwardRef<FooProps>(
              (props, ref) {},
              _$FooConfig as UiFactoryConfig<FooProps>, // ignore: undefined_identifier
            );
            
            final Bar = uiFunction<BarProps>(
              (props) {}, 
              _$BarConfig as UiFactoryConfig<BarProps>, // ignore: undefined_identifier
            );
          ''',
        );
      });

      test('when wrapped in an hoc', () {
        testSuggestor(
          expectedPatchCount: 4,
          input: r'''
            UiFactory<FooProps> Foo = someHOC(uiFunction(
              (props) {}, 
              $FooConfig, // ignore: undefined_identifier
            ));
          ''',
          expectedOutput: r'''
            final Foo = someHOC(uiFunction<FooProps>(
              (props) {}, 
              _$FooConfig as UiFactoryConfig<FooProps>, // ignore: undefined_identifier
            ));
          ''',
        );
      });
    });
  });
}

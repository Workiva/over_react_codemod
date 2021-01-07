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

    group('does not update', () {
      test('if already updated', () {
        testSuggestor(
          expectedPatchCount: 0,
          input: r'''
            final Foo = uiFunction<FooProps>(
              (props) {}, 
              _$FooConfig as UiFactory<FooProps>, 
            );
          ''',
        );
      });

      test('if already updated connected component', () {
        testSuggestor(
          expectedPatchCount: 0,
          input: r'''
            UiFactory<FooProps> Foo = connect<SomeState, FooProps>(
              mapStateToProps: (state) => (Foo()
                ..foo = state.foo
                ..bar = state.bar
              ),
            )(_$Foo as UiFactory<FooProps>); 
          ''',
        );
      });
    });

    test('with left hand typing', () {
      testSuggestor(
        expectedPatchCount: 2,
        input: r'''
          UiFactory<BarProps> Bar = uiFunction(
            (props) {}, 
            $BarConfig,
          );
        ''',
        expectedOutput: r'''
          UiFactory<BarProps> Bar = uiFunction(
            (props) {}, 
            _$BarConfig as UiFactory<BarProps>,
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
            $FooConfig,
          );
        ''',
        expectedOutput: r'''
          final Foo = uiForwardRef<FooProps>(
            (props, ref) {},
            _$FooConfig as UiFactory<FooProps>,
          );
        ''',
      );
    });

    test('when the config is already private', () {
      testSuggestor(
        expectedPatchCount: 1,
        input: r'''
          UiFactory<BarProps> Bar = uiFunction(
            (props) {}, 
            _$BarConfig,
          );
        ''',
        expectedOutput: r'''
          UiFactory<BarProps> Bar = uiFunction(
            (props) {}, 
            _$BarConfig as UiFactory<BarProps>,
          );
        ''',
      );
    });

    test('when there are multiple factories', () {
      testSuggestor(
        expectedPatchCount: 4,
        input: r'''
          final Foo = uiForwardRef<FooProps>(
            (props, ref) {},
            $FooConfig,
          );
          
          UiFactory<BarProps> Bar = uiFunction(
            (props) {}, 
            $BarConfig,
          );
        ''',
        expectedOutput: r'''
          final Foo = uiForwardRef<FooProps>(
            (props, ref) {},
            _$FooConfig as UiFactory<FooProps>,
          );
          
          UiFactory<BarProps> Bar = uiFunction(
            (props) {}, 
            _$BarConfig as UiFactory<BarProps>,
          );
        ''',
      );
    });

    test('when wrapped in an hoc', () {
      testSuggestor(
        expectedPatchCount: 2,
        input: r'''
          UiFactory<FooProps> Foo = someHOC(uiFunction(
            (props) {}, 
            $FooConfig, 
          ));
        ''',
        expectedOutput: r'''
          UiFactory<FooProps> Foo = someHOC(uiFunction(
            (props) {}, 
            _$FooConfig as UiFactory<FooProps>, 
          ));
        ''',
      );
    });

    test('for connected components', () {
      testSuggestor(
        expectedPatchCount: 1,
        input: r'''
          UiFactory<FooProps> Foo = connect<SomeState, FooProps>(
            mapStateToProps: (state) => (Foo()
              ..foo = state.foo
              ..bar = state.bar
            ),
          )(_$Foo); 
        ''',
        expectedOutput: r'''
          UiFactory<FooProps> Foo = connect<SomeState, FooProps>(
            mapStateToProps: (state) => (Foo()
              ..foo = state.foo
              ..bar = state.bar
            ),
          )(_$Foo as UiFactory<FooProps>); 
        ''',
      );
    });
  });
}

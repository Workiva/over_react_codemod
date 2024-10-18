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

import 'package:over_react_codemod/src/dart3_suggestors/null_safety_prep/connect_required_props.dart';
import 'package:test/test.dart';

import '../../resolved_file_context.dart';
import '../../util.dart';
import '../../util/component_usage_migrator_test.dart';

void main() {
  final resolvedContext = SharedAnalysisContext.overReact;

  // Warm up analysis in a setUpAll so that if getting the resolved AST times out
  // (which is more common for the WSD context), it fails here instead of failing the first test.
  setUpAll(resolvedContext.warmUpAnalysis);

  group(
      'ConnectRequiredProps - adds all connect props to disable required prop validation list',
      () {
    late SuggestorTester testSuggestor;

    String commonConnectFile(String source) {
      return '''
      $overReactImport
      import 'package:over_react/over_react_redux.dart';
        
      // ignore: uri_has_not_been_generated
      part 'main.over_react.g.dart';
    
      class FooState {
        num count;
      }
      $source''';
    }

    setUp(() {
      testSuggestor = getSuggestorTester(
        ConnectRequiredProps(),
        resolvedContext: resolvedContext,
      );
    });

    test('', () async {
      await testSuggestor(
        input: commonConnectFile('''
          mixin FooProps on UiProps {
            num count;
            Function() increment;
            String abc;
          }
          
          UiFactory<FooProps> Foo = connect<FooState, FooProps>(
            mapStateToProps: (state) => (Foo()
              ..addTestId('abc')
              ..count = state.count
            ),
            mapDispatchToProps: (dispatch) => Foo()..increment = (() => null),
          )(uiFunction((props) => (Foo()..abc = '1')(), _\$Foo));
        '''),
        expectedOutput: commonConnectFile('''
          @Props(disableRequiredPropValidation: {'count', 'increment'})
          mixin FooProps on UiProps {
            num count;
            Function() increment;
            String abc;
          }
          
          UiFactory<FooProps> Foo = connect<FooState, FooProps>(
            mapStateToProps: (state) => (Foo()
              ..addTestId('abc')
              ..count = state.count
            ),
            mapDispatchToProps: (dispatch) => Foo()..increment = (() => null),
          )(uiFunction((props) => (Foo()..abc = '1')(), _\$Foo));
        '''),
      );
    });

    test('for multiple mixins', () async {
      await testSuggestor(
        input: commonConnectFile('''
          mixin FooPropsMixin on UiProps {
            /*late*/ num count;
            Function()/*?*/  increment;
            String abc;
          }
          
          mixin OtherPropsMixin on UiProps {
            String a;
            String b;
          }
          
          class FooProps = UiProps with FooPropsMixin, OtherPropsMixin;
          
          UiFactory<FooProps> Foo = connect<FooState, FooProps>(
            mapStateToProps: (state) => (Foo()
              ..addTestId('abc')
              ..count = state.count
              ..a = '1'
            ),
            mapDispatchToProps: (dispatch) => Foo()..increment = (() => null),
          )(uiFunction((props) => (Foo()..abc = '1'..b = '2')(), _\$Foo));
        '''),
        expectedOutput: commonConnectFile('''
          mixin FooPropsMixin on UiProps {
            /*late*/ num count;
            Function()/*?*/  increment;
            String abc;
          }
          
          mixin OtherPropsMixin on UiProps {
            String a;
            String b;
          }
          
          @Props(disableRequiredPropValidation: {'count', 'increment'})
          class FooProps = UiProps with FooPropsMixin, OtherPropsMixin;
          
          UiFactory<FooProps> Foo = connect<FooState, FooProps>(
            mapStateToProps: (state) => (Foo()
              ..addTestId('abc')
              ..count = state.count
              ..a = '1'
            ),
            mapDispatchToProps: (dispatch) => Foo()..increment = (() => null),
          )(uiFunction((props) => (Foo()..abc = '1'..b = '2')(), _\$Foo));
        '''),
      );
    });

    group('adds to existing annotations', () {
      Future<void> testAnnotations(
          {required String input, required String expectedOutput}) async {
        final connectBoilerplate = '''
          mixin FooProps on UiProps {
            num connectProp1;
            Function() connectProp2;
            String nonConnectProp;
          }
          
          UiFactory<FooProps> Foo = connect<FooState, FooProps>(
            mapStateToProps: (state) => (Foo()..connectProp1 = 1),
            mapDispatchToProps: (dispatch) => Foo()..connectProp2 = (() => null),
          )(uiFunction((props) => (Foo()..nonConnectProp = '1')(), _\$Foo));
        ''';
        await testSuggestor(
          input: commonConnectFile('''
          $input
          $connectBoilerplate
        '''),
          expectedOutput: commonConnectFile('''
          $expectedOutput
          $connectBoilerplate
        '''),
        );
      }

      test('', () async {
        await testAnnotations(
          input: '@Props()',
          expectedOutput:
              '@Props(disableRequiredPropValidation: {\'connectProp1\', \'connectProp2\'})',
        );
      });

      test('with other args', () async {
        await testAnnotations(
          input: '@Props(keyNamespace: \'\')',
          expectedOutput:
              '@Props(disableRequiredPropValidation: {\'connectProp1\', \'connectProp2\'}, keyNamespace: \'\')',
        );
      });

      test('with disableRequiredPropValidation', () async {
        await testAnnotations(
          input: '@Props(disableRequiredPropValidation: {\'connectProp1\'})',
          expectedOutput:
              '@Props(disableRequiredPropValidation: {\'connectProp2\', \'connectProp1\'})',
        );
      });
    });

    test('recognizes different arg formats', () async {
      await testSuggestor(
        input: commonConnectFile('''
          mixin FooProps on UiProps {
            /*late*/ num count;
            Function()/*?*/  increment;
            String abc;
          }
          
          UiFactory<FooProps> Foo = connect<FooState, FooProps>(
            mapStateToProps: (state) {
              return (Foo()
                ..count = state.count
              );
            },
            mapDispatchToProps: (dispatch) {
              final foo = (Foo()
                ..increment = (() => null)
              );
              return foo;
            },
          )(_\$Foo);
        '''),
        expectedOutput: commonConnectFile('''
          @Props(disableRequiredPropValidation: {'count', 'increment'})
          mixin FooProps on UiProps {
            /*late*/ num count;
            String/*?*/  increment;
            String abc;
          }
          
          UiFactory<FooProps> Foo = connect<FooState, FooProps>(
            mapStateToProps: (state) {
              return (Foo()
                ..count = state.count
              );
            },
            mapDispatchToProps: (dispatch) {
              final foo = (Foo()
                ..increment = (() => dispatch(IncrementAction()))
              );
              return foo;
            },
          )(_\$Foo);
        '''),
      );
    });

    test('does not cover certain unlikely edge cases', () async {
      await testSuggestor(
        expectedPatchCount: 0,
        input: commonConnectFile('''
          mixin FooProps on UiProps {
            /*late*/ num count;
            Function()/*?*/  increment;
            String abc;
          }
          
          final _mapStateToProps =  (state) {
            return (Foo()
              ..count = state.count
            );
          };
          
          UiFactory<FooProps> Foo = connect<FooState, FooProps>(
            mapStateToProps: _mapStateToProps,
            mapDispatchToProps: (dispatch) {
              final foo = (Foo()
                ..increment = (() => null)
              );
              return foo;
            },
          )(_\$Foo);
        '''),
      );
    });
  });
}

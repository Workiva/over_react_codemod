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

  group('ConnectRequiredProps', () {
    late SuggestorTester testSuggestor;

    setUp(() {
      testSuggestor = getSuggestorTester(
        ConnectRequiredProps(),
        resolvedContext: resolvedContext,
      );
    });

    test(
        'adds all connect props to disable required prop validation list',
        () async {
      await testSuggestor(
        expectedPatchCount: 0,
        input: withOverReactImport('''
          import 'package:over_react/over_react_redux.dart';
        
          // ignore: uri_has_not_been_generated
          part 'main.over_react.g.dart';
        
          class FooState {
            /*late*/ num count;
          }
          
          mixin FooProps on UiProps {
            /*late*/ num count;
            Function()/*?*/  increment;
            String abc;
          }
          
          UiFactory<FooProps> Foo = connect<FooState, FooProps>(
            mapStateToProps: (state) => (Foo()
              ..count = state.count
            ),
            mapDispatchToProps: (dispatch) => (Foo()
              ..increment = (() => null)
            ),
          )(_\$Foo);
        '''),
        expectedOutput: withOverReactImport('''
          import 'package:over_react/over_react_redux.dart';
        
          part 'main.over_react.g.dart';
        
          class FooState {
            /*late*/ num count;
          }
          
          @Props(disableRequiredPropValidation: {'count', 'increment'})
          mixin FooProps on UiProps {
            /*late*/ num count;
            String/*?*/  increment;
            String abc;
          }
          
          UiFactory<FooProps> Foo = connect<FooState, FooProps>(
            mapStateToProps: (state) => (Foo()
              ..count = state.count
            ),
            mapDispatchToProps: (dispatch) => (Foo()
              ..increment = (() => dispatch(IncrementAction()))
            ),
          )(_\$Foo);
        '''),
      );
    });
  });
}

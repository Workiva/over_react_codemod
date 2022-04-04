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

import 'package:over_react_codemod/src/intl_suggestors/intl_message.dart';
import 'package:test/test.dart';

import '../resolved_file_context.dart';
import '../util.dart';

void main() {
  final resolvedContext = SharedAnalysisContext.overReact;

  // Warm up analysis in a setUpAll so that if getting the resolved AST times out
  // (which is more common for the WSD context), it fails here instead of failing the first test.
  setUpAll(resolvedContext.warmUpAnalysis);

  group('IntlMessageMigrator', () {
    final testSuggestor = getSuggestorTester(
      IntlMessageMigrator(),
      resolvedContext: resolvedContext,
    );

    group('StringLiteral', () {
      test('uiFunction component', () async {
        await testSuggestor(
          input: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {}
              
              UiFactory<FooProps> Foo = uiFunction(
                (props) {
                  return (Dom.div()
                    ..label = 'testString')();
                },
                _\$FooConfig, //ignore: undefined_identifier
              ); 
              ''',
          expectedOutput: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {}
              
              UiFactory<FooProps> Foo = uiFunction(
                (props) {
                  return (Dom.div()
                    ..label = Intl.message('testString'))();
                },
                _\$FooConfig, //ignore: undefined_identifier
              ); 
              ''',
        );
      });

      test('class based component', () async {
        await testSuggestor(
          input: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {}
              
              class Foo extends UiComponent<UiProps> {
                  
                @override
                render() {
                  return (Dom.div()
                    ..label = 'testString')();
                }
              }
              ''',
          expectedOutput: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {}
              
              class Foo extends UiComponent<UiProps> {
                  
                @override
                render() {
                  return (Dom.div()
                    ..label = Intl.message('testString'))();
                }
              }
              ''',
        );
      });
    });

    group('StringInterpolation', () {
      test('one argument with top level accessor', () async {
        await testSuggestor(
          input: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {}
              
              UiFactory<FooProps> Foo = uiFunction(
                (props) {
                  final name = 'bob';
                  
                  return (Dom.div()
                    ..label = 'Interpolated \${name}')();
                },
                _\$FooConfig, //ignore: undefined_identifier
              ); 
              ''',
          expectedOutput: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {}
              
              UiFactory<FooProps> Foo = uiFunction(
                (props) {
                  final name = 'bob';

                  String tempFunctionName(String name) =>
                    Intl.message('Interpolated \$name',
                      args: [name],
                    );
                  
                  return (Dom.div()
                    ..label = tempFunctionName(name))();
                },
                _\$FooConfig, //ignore: undefined_identifier
              ); 
              ''',
        );
      });
      test('one argument with top level accessor', () async {
        await testSuggestor(
          input: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {}
              
              UiFactory<FooProps> Foo = uiFunction(
                (props) {
                  final name = 'bob';
                  
                  return (Dom.div()
                    ..label = 'Interpolated \${name}')();
                },
                _\$FooConfig, //ignore: undefined_identifier
              ); 
              ''',
          expectedOutput: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {}
              
              UiFactory<FooProps> Foo = uiFunction(
                (props) {
                  final name = 'bob';

                  String tempFunctionName(String name) =>
                    Intl.message('Interpolated \$name',
                      args: [name],
                    );
                  
                  return (Dom.div()
                    ..label = tempFunctionName(name))();
                },
                _\$FooConfig, //ignore: undefined_identifier
              ); 
              ''',
        );
      });
      test('one argument with top level accessor', () async {
        await testSuggestor(
          input: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {}
              
              UiFactory<FooProps> Foo = uiFunction(
                (props) {
                  final name = 'bob';
                  
                  return (Dom.div()
                    ..label = 'Interpolated \${name}')();
                },
                _\$FooConfig, //ignore: undefined_identifier
              ); 
              ''',
          expectedOutput: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {}
              
              UiFactory<FooProps> Foo = uiFunction(
                (props) {
                  final name = 'bob';

                  String tempFunctionName(String name) =>
                    Intl.message('Interpolated \$name',
                      args: [name],
                    );
                  
                  return (Dom.div()
                    ..label = tempFunctionName(name))();
                },
                _\$FooConfig, //ignore: undefined_identifier
              ); 
              ''',
        );
      });
      test('two argument with top level accessors', () async {
        await testSuggestor(
          input: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {}
              
              UiFactory<FooProps> Foo = uiFunction(
                (props) {
                  final name = 'bob';
                  final title = 'testTitle';
                  
                  return (Dom.div()
                    ..label = 'Interpolated \${name} \${title}')();
                },
                _\$FooConfig, //ignore: undefined_identifier
              ); 
              ''',
          expectedOutput: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {}
              
              UiFactory<FooProps> Foo = uiFunction(
                (props) {
                  final name = 'bob';
                  final title = 'testTitle';
                  
                  String tempFunctionName(String name, String title) =>
                    Intl.message('Interpolated \$name \$title',
                      args: [name, title],
                    );
                  
                  return (Dom.div()
                    ..label = tempFunctionName(name, title))();
                },
                _\$FooConfig, //ignore: undefined_identifier
              ); 
              ''',
        );
      });
      test('one argument with nested accessor', () async {
        await testSuggestor(
          input: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {
                String name;
              }
              
              UiFactory<FooProps> Foo = uiFunction(
                (props) {
                
                  return (Dom.div()
                    ..label = 'Interpolated \${props.name}')();
                },
                _\$FooConfig, //ignore: undefined_identifier
              ); 
              ''',
          expectedOutput: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {
                String name;
              }
              
              UiFactory<FooProps> Foo = uiFunction(
                (props) {

                  String tempFunctionName(String name) =>
                    Intl.message('Interpolated \$name',
                      args: [name],
                    );
                  
                  return (Dom.div()
                    ..label = tempFunctionName(props.name))();
                },
                _\$FooConfig, //ignore: undefined_identifier
              ); 
              ''',
        );
      });
      test('two arguments with nested accessor', () async {
        await testSuggestor(
          input: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {
                String name;
                String title;
              }
              
              UiFactory<FooProps> Foo = uiFunction(
                (props) {
                  
                  return (Dom.div()
                    ..label = 'Interpolated \${props.name} \${props.title}')();
                },
                _\$FooConfig, //ignore: undefined_identifier
              ); 
              ''',
          expectedOutput: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {
                String name;
                String title;
              }
              
              UiFactory<FooProps> Foo = uiFunction(
                (props) {
                  
                  String tempFunctionName(String name, String title) =>
                    Intl.message('Interpolated \$name \$title',
                      args: [name, title],
                    );
                  
                  return (Dom.div()
                    ..label = tempFunctionName(props.name, props.title))();
                },
                _\$FooConfig, //ignore: undefined_identifier
              ); 
              ''',
        );
      });
      test('class based component', () async {
        await testSuggestor(
          input: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {}
              
              class Foo extends UiComponent<UiProps> {
                final name = 'bob';

                @override
                render() {
                  
                  return (Dom.div()
                    ..label = 'Interpolated \${name}')();
                }
              }
              ''',
          expectedOutput: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {}
              
              class Foo extends UiComponent<UiProps> {
                final name = 'bob';
 
              String tempFunctionName(String name) =>
                Intl.message('Interpolated \$name',
                  args: [name],
                );
                    
                @override
                render() {
                  return (Dom.div()
                    ..label = tempFunctionName(name))();
                }
              }
              ''',
        );
      }, skip: true);
      test('Nested uiFunction based component', () async {
        await testSuggestor(
          input: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {}
              
              UiFactory<FooProps> Foo = uiFunction(
                (props) {
                  final name = 'bob';
                  
                  return Dom.div()(
                    (Dom.div()..label = 'Interpolated \${name}')(),
                  );
                },
                _\$FooConfig, //ignore: undefined_identifier
              ); 
              ''',
          expectedOutput: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {}
              
              UiFactory<FooProps> Foo = uiFunction(
                (props) {
                  final name = 'bob';
 
                  String tempFunctionName(String name) =>
                    Intl.message('Interpolated \$name',
                    args: [name],
                  );
                    
                  return Dom.div()(
                    (Dom.div()..label = tmpFunctionName(name))(),
                  );
                },
                _\$FooConfig, //ignore: undefined_identifier
              ); 
              ''',
        );
      }, skip: true);
    });

    group('Child', () {
      test('StringLiteral single child', () async {
        await testSuggestor(
          input: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {}
              
              UiFactory<FooProps> Foo = uiFunction(
                (props) {
                  
                  return (Dom.div())('testString');
                },
                _\$FooConfig, //ignore: undefined_identifier
              ); 
              ''',
          expectedOutput: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {}
              
              UiFactory<FooProps> Foo = uiFunction(
                (props) {
                  
                  return (Dom.div())(
                    Intl.message('testString'),
                  );
                },
                _\$FooConfig, //ignore: undefined_identifier
              ); 
              ''',
        );
      });

      test('StringLiteral two children', () async {
        await testSuggestor(
          input: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {}
              
              UiFactory<FooProps> Foo = uiFunction(
                (props) {
                  
                  return (Dom.div())(
                    'testString1',
                    'testString2',
                  );
                },
                _\$FooConfig, //ignore: undefined_identifier
              ); 
              ''',
          expectedOutput: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {}
              
              UiFactory<FooProps> Foo = uiFunction(
                (props) {
                  
                  return (Dom.div())(
                    Intl.message('testString1'),
                    Intl.message('testString2'),
                  );
                },
                _\$FooConfig, //ignore: undefined_identifier
              ); 
              ''',
        );
      });

      test('NonStringLiteral single child', () async {
        await testSuggestor(
          input: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {}
              
              UiFactory<FooProps> Foo = uiFunction(
                (props) {
                  final testString = 'testString';
                  
                  return (Dom.div())(testString);
                },
                _\$FooConfig, //ignore: undefined_identifier
              ); 
              ''',
          expectedOutput: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {}
              
              UiFactory<FooProps> Foo = uiFunction(
                (props) {
                  final testString = 'testString';

                  return (Dom.div())(testString);
                },
                _\$FooConfig, //ignore: undefined_identifier
              ); 
              ''',
        );
      });
    });
  });
}

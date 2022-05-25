// // Copyright 2021 Workiva Inc.
// //
// // Licensed under the Apache License, Version 2.0 (the "License");
// // you may not use this file except in compliance with the License.
// // You may obtain a copy of the License at
// //
// //     http://www.apache.org/licenses/LICENSE-2.0
// //
// // Unless required by applicable law or agreed to in writing, software
// // distributed under the License is distributed on an "AS IS" BASIS,
// // WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// // See the License for the specific language governing permissions and
// // limitations under the License.

import 'package:over_react_codemod/src/intl_suggestors/intl_prop_string_interpolation_migrator.dart';
import 'package:test/test.dart';

import '../resolved_file_context.dart';
import '../util.dart';

void main() {
  final resolvedContext = SharedAnalysisContext.overReact;

  // Warm up analysis in a setUpAll so that if getting the resolved AST times out
  // (which is more common for the WSD context), it fails here instead of failing the first test.
  setUpAll(resolvedContext.warmUpAnalysis);

  group('IntlPropStringInterpolationMigrator', () {
    SuggestorTester testSuggestor = getSuggestorTester(
      IntlPropStringInterpolationMigrator(),
      resolvedContext: resolvedContext,
    );

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

                    return (Dom.div()
                      ..label = tempFunction0(name))();
                  },
                  _\$FooConfig, //ignore: undefined_identifier
                );
                
                String tempFunction0(String name) => Intl.message(
                    'Interpolated \$name',
                    args: [name],
                    name: 'tempFunction0',
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
                  final title = 'Test Title';

                  return (Dom.div()
                    ..label = 'Interpolated \${name} \$title')();
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
                  final title = 'Test Title';

                  return (Dom.div()
                    ..label = tempFunction0(name, title))();
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              
              String tempFunction0(String name, String title) => Intl.message(
                    'Interpolated \$name \$title',
                    args: [name, title],
                    name: 'tempFunction0',
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

                  return (Dom.div()
                    ..label = tempFunction0(props.name))();
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
                              
              String tempFunction0(String name) => Intl.message(
                    'Interpolated \$name',
                    args: [name],
                    name: 'tempFunction0',
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

                  return (Dom.div()
                    ..label = tempFunction0(props.name, props.title))();
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              
              String tempFunction0(String name, String title) => Intl.message(
                    'Interpolated \$name \$title',
                    args: [name, title],
                    name: 'tempFunction0',
                  );
              ''',
        );
      });

      test('Single interpolated element', () async {
        await testSuggestor(
          input: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {
                String name;
              }

              UiFactory<FooProps> Foo = uiFunction(
                (props) {

                  return (Dom.div()
                    ..label = '\${props.name}')();
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

                  return (Dom.div()
                    ..label = '\${props.name}')();
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );
      });

      test('Interpolated function call', () async {
        await testSuggestor(
          input: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {}

              UiFactory<FooProps> Foo = uiFunction(
                (props) {

                  String getName() {
                    return 'test name';
                  }
                  
                  return (Dom.div()
                    ..label = 'His name was \${getName()}')();
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
          expectedOutput: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {}

              UiFactory<FooProps> Foo = uiFunction(
                (props) {
                
                  String getName() {
                    return 'test name';
                  }
                  
                  return (Dom.div()
                    ..label = tempFunction0(getName()))();
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              
              String tempFunction0(String getName) => Intl.message(
                    'His name was \$getName',
                    args: [getName],
                    name: 'tempFunction0',
                  );
              ''',
        );
      });

      test('Interpolated with apostrophe', () async {
        await testSuggestor(
          input: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {}

              UiFactory<FooProps> Foo = uiFunction(
                (props) {

                  final lastName = 'Paulsen';
                  
                  return (Dom.div()
                    ..label = "Bob's last name was \${lastName}")();
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
          expectedOutput: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {}

              UiFactory<FooProps> Foo = uiFunction(
                (props) {
                
                  final lastName = 'Paulsen';
                  
                  return (Dom.div()
                    ..label = tempFunction0(lastName))();
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              
              String tempFunction0(String lastName) => Intl.message(
                    'Bob\\\'s last name was \$lastName',
                    args: [lastName],
                    name: 'tempFunction0',
                  );
              ''',
        );
      });

      test('Interpolated with testId string', () async {
        await testSuggestor(
          input: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {
                String version;
              }

              UiFactory<FooProps> Foo = uiFunction(
                (props) {

                  return (Dom.p()
                    ..addTestId('truss.aboutWdeskModal.versionInfo')
                    ..label = 'Version \${props.version}')();
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
          expectedOutput: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {
                String version;
              }

              UiFactory<FooProps> Foo = uiFunction(
                (props) {
                                 
                  return (Dom.p() 
                    ..addTestId('truss.aboutWdeskModal.versionInfo')
                    ..label = versionInfo(props.version))();
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              
              String versionInfo(String version) => Intl.message(
                  'Version \$version',
                  args: [version],
                  name: 'versionInfo',
                );
              ''',
        );
      });

      test('Interpolated with testId', () async {
        await testSuggestor(
          input: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {
                String version;
              }

              abstract class TestClassTestIds {
                static String get versionInfo => 'truss.aboutWdeskModal.versionInfo';
              }
              
              UiFactory<FooProps> Foo = uiFunction(
                (props) {

                  return (Dom.p()
                    ..addTestId(TestClassTestIds.versionInfo)
                    ..label = 'Version \${props.version}')();
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
          expectedOutput: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {
                String version;
              }

              abstract class TestClassTestIds {
                static String get versionInfo => 'truss.aboutWdeskModal.versionInfo';
              }
              
              UiFactory<FooProps> Foo = uiFunction(
                (props) {
                                 
                  return (Dom.p() 
                    ..addTestId(TestClassTestIds.versionInfo)
                    ..label = versionInfo(props.version))();
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              
              String versionInfo(String version) => Intl.message(
                  'Version \$version',
                  args: [version],
                  name: 'versionInfo',
                );
              ''',
        );
      });
    });

    group('Values that we will not need i18n for', () {
      test('ReactElement', () async {
        await testSuggestor(
          input: '''
              import 'package:over_react/over_react.dart';
              
              mixin FooProps on UiProps {}
              
              UiFactory<FooProps> Foo = uiFunction(
                (props) {

                  return (Dom.div()
                    ..label = Dom.div()('Test Title'))();
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
                    ..label = Dom.div()('Test Title'))();
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );
      });

      test('DartCoreBool', () async {
        await testSuggestor(
          input: '''
              import 'package:over_react/over_react.dart';
              
              mixin FooProps on UiProps {}
              
              UiFactory<FooProps> Foo = uiFunction(
                (props) {

                  return (Dom.div()
                    ..label = false)();
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
                    ..label = false)();
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );
      });
      test('DartCoreNull', () async {
        await testSuggestor(
          input: '''
              import 'package:over_react/over_react.dart';
              
              mixin FooProps on UiProps {}
              
              UiFactory<FooProps> Foo = uiFunction(
                (props) {

                  return (Dom.div()
                    ..label = null)();
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
                    ..label = null)();
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );
      });
      test('\' \'', () async {
        await testSuggestor(
          input: '''
              import 'package:over_react/over_react.dart';
              
              mixin FooProps on UiProps {}
              
              UiFactory<FooProps> Foo = uiFunction(
                (props) {

                  return (Dom.div()
                    ..label = '')();
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
                    ..label = '')();
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );
      });
      test('.', () async {
        await testSuggestor(
          input: '''
              import 'package:over_react/over_react.dart';
              
              mixin FooProps on UiProps {}
              
              UiFactory<FooProps> Foo = uiFunction(
                (props) {

                  return (Dom.div()
                    ..label = '.')();
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
                    ..label = '.')();
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );
      });
      test('props.key', () async {
        await testSuggestor(
          input: '''
              import 'package:over_react/over_react.dart';
              
              mixin FooProps on UiProps {
                String label;
              }
              
              UiFactory<FooProps> Foo = uiFunction(
                (props) {

                  return (Dom.div()
                    ..label = props.label)();
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
          expectedOutput: '''
              import 'package:over_react/over_react.dart';
              
              mixin FooProps on UiProps {
                String label;
              }
              
              UiFactory<FooProps> Foo = uiFunction(
                (props) {

                  return (Dom.div()
                    ..label = props.label)();
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );
      });
      test('single camelCased string', () async {
        await testSuggestor(
          input: '''
              import 'package:over_react/over_react.dart';
              
              mixin FooProps on UiProps {}
              
              UiFactory<FooProps> Foo = uiFunction(
                (props) {

                  return (Dom.div()
                    ..label = 'testStringThatIsCamelCased')();
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
                    ..label = 'testStringThatIsCamelCased')();
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );
      });

      test('single number string', () async {
        await testSuggestor(
          input: '''
              import 'package:over_react/over_react.dart';
              
              mixin FooProps on UiProps {}
              
              UiFactory<FooProps> Foo = uiFunction(
                (props) {

                  return (Dom.div()
                    ..label = '12')();
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
                    ..label = '12')();
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );
      });
    });
  });
}

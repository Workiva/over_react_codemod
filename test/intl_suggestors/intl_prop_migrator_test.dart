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

import 'dart:io';

import 'package:over_react_codemod/src/intl_suggestors/intl_prop_migrator.dart';
import 'package:over_react_codemod/src/intl_suggestors/utils.dart';
import 'package:test/test.dart';

import '../resolved_file_context.dart';
import '../util.dart';

void main() {
  final resolvedContext = SharedAnalysisContext.overReact;

  // Warm up analysis in a setUpAll so that if getting the resolved AST times out
  // (which is more common for the WSD context), it fails here instead of failing the first test.
  setUpAll(resolvedContext.warmUpAnalysis);

  group('IntlPropMigrator', () {
    File? file;
    SuggestorTester? testSuggestor;

    setUp(() {
      file = File('TestClassIntl')..createSync();
      testSuggestor = getSuggestorTester(
        IntlPropMigrator('TestClassIntl', file!),
        resolvedContext: resolvedContext,
      );
    });

    tearDown(() {
      file?..exists()..deleteSync();
      file = null;
    });

    group('StringLiteral', () {
      test('uiFunction string literal', () async {
        await testSuggestor!(
          input: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {}

              UiFactory<FooProps> Foo = uiFunction(
                (props) {
                  return (Dom.div()
                    ..label = 'Test String')();
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
                    ..label = TestClassIntl.TestString)();
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );

        expect(file!.readAsStringSync(),
            'static String get TestString => Intl.message(\'Test String\');\n');
      });

      test('class string literal', () async {
        await testSuggestor!(
          input: '''
               import 'package:over_react/over_react.dart';

               mixin FooProps on UiProps {}

               class Foo extends UiComponent<UiProps> {

                 @override
                 render() {
                   return (Dom.div()
                     ..label = 'Test String')();
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
                     ..label = TestClassIntl.TestString)();
                 }
               }
              ''',
        );
        expect(file!.readAsStringSync(),
            'static String get TestString => Intl.message(\'Test String\');\n');
      });

      test('uiFunction props => component', () async {
        await testSuggestor!(
          input: '''
                import 'package:over_react/over_react.dart';

                mixin FooProps on UiProps {}

                UiFactory<FooProps> Foo = uiFunction(
                  (props) => (Dom.div()
                      ..label = 'Test String')(),
                  _\$FooConfig, //ignore: undefined_identifier
                );
                ''',
          expectedOutput: '''
                import 'package:over_react/over_react.dart';

                mixin FooProps on UiProps {}

                UiFactory<FooProps> Foo = uiFunction(
                  (props) => (Dom.div()
                      ..label = TestClassIntl.TestString)(),
                  _\$FooConfig, //ignore: undefined_identifier
                );
                ''',
        );
        expect(file!.readAsStringSync(),
            'static String get TestString => Intl.message(\'Test String\');\n');
      });
    });

    group('StringInterpolation', () {
      test('one argument with top level accessor', () async {
        await testSuggestor!(
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
                      ..label = TestClassIntl.domDivLabel('\${name}'))();
                  },
                  _\$FooConfig, //ignore: undefined_identifier
                );
              ''',
        );

        final expectedFileContent = interpolationTemplate('TestClassIntl',
            'domDivLabel', '\'Interpolated \$name\'', ['name']);
        expect(file!.readAsStringSync(), expectedFileContent);
      });

      test('two argument with top level accessors', () async {
        await testSuggestor!(
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
                    ..label = TestClassIntl.domDivLabel('\${name}', '\$title'))();
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );
        final expectedFileContent = interpolationTemplate(
            'TestClassIntl',
            'domDivLabel',
            '\'Interpolated \$name \$title\'',
            ['name', 'title']);
        expect(file!.readAsStringSync(), expectedFileContent);
      });

      test('one argument with nested accessor', () async {
        await testSuggestor!(
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
                    ..label = TestClassIntl.domDivLabel('\${props.name}'))();
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );
        final expectedFileContent = interpolationTemplate('TestClassIntl',
            'domDivLabel', '\'Interpolated \$name\'', ['name']);
        expect(file!.readAsStringSync(), expectedFileContent);
      });

      test('two arguments with nested accessor', () async {
        await testSuggestor!(
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
                    ..label = TestClassIntl.domDivLabel('\${props.name}', '\${props.title}'))();
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );
        final expectedFileContent = interpolationTemplate(
            'TestClassIntl',
            'domDivLabel',
            '\'Interpolated \$name \$title\'',
            ['name', 'title']);
        expect(file!.readAsStringSync(), expectedFileContent);
      });

      test('Single interpolated element', () async {
        await testSuggestor!(
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

      test('Interpolated functiona call', () async {
        await testSuggestor!(
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
                    ..label = TestClassIntl.domDivLabel('\${getName()}'))();
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );

        final expectedFileContent = interpolationTemplate(
            'TestClassIntl',
            'domDivLabel',
            '\'His name was \$getName\'',
            ['getName']);
        expect(file!.readAsStringSync(), expectedFileContent);
      });
      test('Interpolated with apostrophe', () async {
        await testSuggestor!(
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
                    ..label = TestClassIntl.domDivLabel('\${lastName}'))();
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );

        final expectedFileContent = interpolationTemplate(
            'TestClassIntl',
            'domDivLabel',
            "\"Bob\'s last name was \$lastName\"",
            ['lastName']);
        expect(file!.readAsStringSync(), expectedFileContent);
      });
    });

    group('Values that we will not need i18n for', () {
      test('ReactElement', () async {
        await testSuggestor!(
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
        await testSuggestor!(
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
        await testSuggestor!(
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
        await testSuggestor!(
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
        await testSuggestor!(
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
        await testSuggestor!(
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
        await testSuggestor!(
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
    });


  });
}

import 'dart:io';

import 'package:over_react_codemod/src/intl_suggestors/intl_child_migrator.dart';
import 'package:over_react_codemod/src/intl_suggestors/utils.dart';
import 'package:test/test.dart';

import '../resolved_file_context.dart';
import '../util.dart';

void main() {
  final resolvedContext = SharedAnalysisContext.overReact;

  // Warm up analysis in a setUpAll so that if getting the resolved AST times out
  // (which is more common for the WSD context), it fails here instead of failing the first test.
  setUpAll(resolvedContext.warmUpAnalysis);

  group('IntlChildMigrator', () {
    File? file;
    SuggestorTester? testSuggestor;

    setUp(() {
      file = File('TestClassIntl')
        ..createSync();
      testSuggestor = getSuggestorTester(
        IntlChildMigrator('TestClassIntl', file!),
        resolvedContext: resolvedContext,
      );
    });

    tearDown(() {
      file?.deleteSync();
      file = null;
    });
    
    tearDownAll(() {
      file?.deleteSync();
      file = null;
    });

    group('StringLiteral', () {
      test('StringLiteral single child', () async {
        await testSuggestor!(
          input: '''
            import 'package:over_react/over_react.dart';

            mixin FooProps on UiProps {}

            UiFactory<FooProps> Foo = uiFunction(
              (props) {

                return (Dom.div())('viewer');
              },
              _\$FooConfig, //ignore: undefined_identifier
            );
            ''',
          expectedOutput: '''
            import 'package:over_react/over_react.dart';

            mixin FooProps on UiProps {}

            UiFactory<FooProps> Foo = uiFunction(
              (props) {

                return (Dom.div())(TestClassIntl.viewer);
              },
              _\$FooConfig, //ignore: undefined_identifier
            );
            ''',
        );
        final expectedFileContent = literalTemplate('viewer', '"viewer"');
        expect(file!.readAsStringSync(), expectedFileContent);
      });

      test('StringLiteral two children', () async {
        await testSuggestor!(
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

                return (Dom.div())(TestClassIntl.testString1, TestClassIntl.testString2,);
              },
              _\$FooConfig, //ignore: undefined_identifier
            );
            ''',
        );

        final expectedFileContent = literalTemplate('testString1', '"testString1"');
        final expectedFileContent2 = literalTemplate('testString2', '"testString2"');
        expect( '${expectedFileContent}${expectedFileContent2}', file!.readAsStringSync(),);
      });

      test('NonStringLiteral single child', () async {
        await testSuggestor!(
          input: '''
            import 'package:over_react/over_react.dart';

            mixin FooProps on UiProps {}

            UiFactory<FooProps> Foo = uiFunction(
              (props) {
                final testString = 'testString';

                return (Dom.div())('Interpolated \${testString}');
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

                return (Dom.div())(TestClassIntl.domDivChild0('\${testString}'));
              },
              _\$FooConfig, //ignore: undefined_identifier
            );
            ''',
        );
        final expectedFileContent = interpolationTemplate('TestClassIntl', 'domDivChild0', "'Interpolated \$testString'", ['testString']);
        expect(expectedFileContent,file!.readAsStringSync());
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

                    return (Dom.div())('Interpolated \${name}');
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

                    return (Dom.div())(TestClassIntl.domDivChild0('\${name}'));
                  },
                  _\$FooConfig, //ignore: undefined_identifier
                );
              ''',
        );

        final expectedFileContent = interpolationTemplate('TestClassIntl',
            'domDivChild0', '\'Interpolated \$name\'', ['name']);
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

                  return (Dom.div())('Interpolated \${name} \$title');
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

                  return (Dom.div())(TestClassIntl.domDivChild0('\${name}', '\$title'));
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );
        final expectedFileContent = interpolationTemplate(
            'TestClassIntl',
            'domDivChild0',
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

                  return (Dom.div())('Interpolated \${props.name}');
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

                  return (Dom.div())(TestClassIntl.domDivChild0('\${props.name}'));
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );
        final expectedFileContent = interpolationTemplate('TestClassIntl',
            'domDivChild0', '\'Interpolated \$name\'', ['name']);
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

                  return (Dom.div())('Interpolated \${props.name} \${props.title}');
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

                  return (Dom.div())(TestClassIntl.domDivChild0('\${props.name}', '\${props.title}'));
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );
        final expectedFileContent = interpolationTemplate(
            'TestClassIntl',
            'domDivChild0',
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

                  return (Dom.div())('\${props.name}');
                  
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

                  return (Dom.div())('\${props.name}');
                  
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
                  
                  return (Dom.div())('His name was \${getName()}');
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
                  
                  return (Dom.div())( TestClassIntl.domDivChild0('\${getName()}'));
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );

        final expectedFileContent = interpolationTemplate(
            'TestClassIntl',
            'domDivChild0',
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
                  
                  return (Dom.div())("Bob's last name was \${lastName}");
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
                  
                  return (Dom.div())(TestClassIntl.domDivChild0('\${lastName}'));
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );

        final expectedFileContent = interpolationTemplate(
            'TestClassIntl',
            'domDivChild0',
            "\"Bob\'s last name was \$lastName\"",
            ['lastName']);
        expect(file!.readAsStringSync(), expectedFileContent);
      });
    });

  });
}
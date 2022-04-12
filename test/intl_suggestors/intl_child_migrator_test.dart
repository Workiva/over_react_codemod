import 'package:file/file.dart';
import 'package:file/memory.dart';
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
    late File file;
    SuggestorTester? testSuggestor;

    setUp(() async {
      final FileSystem fs = MemoryFileSystem();
      final Directory tmp = await fs.systemTempDirectory.createTemp();
      file = tmp.childFile('TestClassIntl')..createSync(recursive: true);
      testSuggestor = getSuggestorTester(
        IntlChildMigrator('TestClassIntl', file!),
        resolvedContext: resolvedContext,
      );
    });

    tearDown(() {
      file.deleteSync();
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

      test('single number string', () async {
        await testSuggestor!(
          input: '''
            import 'package:over_react/over_react.dart';

            mixin FooProps on UiProps {}

            UiFactory<FooProps> Foo = uiFunction(
              (props) {

                return (Dom.div())('12');
              },
              _\$FooConfig, //ignore: undefined_identifier
            );
            ''',
          expectedOutput: '''
            import 'package:over_react/over_react.dart';

            mixin FooProps on UiProps {}

            UiFactory<FooProps> Foo = uiFunction(
              (props) {

                return (Dom.div())('12');
              },
              _\$FooConfig, //ignore: undefined_identifier
            );
            ''',
        );
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
      test('Interpolated with testId string', () async {
        await testSuggestor!(
          input: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {
                String version;
              }

              UiFactory<FooProps> Foo = uiFunction(
                (props) {

                  return (Dom.p()
                    ..addTestId('truss.aboutWdeskModal.versionInfo')
                  )(
                    'Version \${props.version}',
                  );
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
                    )(
                      TestClassIntl.versionInfo('\${props.version}'),
                    );
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );

        String expectedFileContent = "static String versionInfo(String version) => Intl.message('Version \$version', args: [version], name: 'TestClassIntl_versionInfo',);\n";
        expect(file!.readAsStringSync(), expectedFileContent);
      });

      test('Interpolated with testId', () async {
        await testSuggestor!(
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
                  )(  
                    'Version \${props.version}',
                  );
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
                  )(
                    TestClassIntl.versionInfo('\${props.version}'),
                  );
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );

        String expectedFileContent = "static String versionInfo(String version) => Intl.message('Version \$version', args: [version], name: 'TestClassIntl_versionInfo',);\n";
        expect(file!.readAsStringSync(), expectedFileContent);
      });

      test('Interpolated with testId in a parent node', () async {
        await testSuggestor!(
          input: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {
                String displayName;
              }

              abstract class TestClassTestIds {
                static String get emptyView => 'truss.aboutWdeskModal.emptyView';
              }
              
              UiFactory<FooProps> Foo = uiFunction(
                (props) {

                return (Dom.div()
                  ..addTestId(TestClassTestIds.emptyView)
                  )(
                    (Dom.p()..addTestId('foo'))(
                      'Create one from any \${props.displayName} by selecting Save As Template',
                    ),
                    (Dom.p()..addTestId('bar'))(
                      (Dom.p())(
                        'Create one from any \${props.displayName} by selecting Save As Template',
                      ),
                    ),
                  );
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
          expectedOutput: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {
                String displayName;
              }

              abstract class TestClassTestIds {
                static String get emptyView => 'truss.aboutWdeskModal.emptyView';
              }
              
              UiFactory<FooProps> Foo = uiFunction(
                (props) {
                                 
                return (Dom.div()
                  ..addTestId(TestClassTestIds.emptyView)
                  )(
                   (Dom.p()..addTestId('foo'))(
                      TestClassIntl.foo('\${props.displayName}'),
                    ),
                    (Dom.p()..addTestId('bar'))(
                      (Dom.p())(
                        TestClassIntl.bar('\${props.displayName}'),
                      ),
                    ),
                  );
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );

        String expectedFileContent1 = "static String foo(String displayName) => Intl.message('Create one from any \$displayName by selecting Save As Template', args: [displayName], name: 'TestClassIntl_foo',);\n";
        String expectedFileContent2 = "static String bar(String displayName) => Intl.message('Create one from any \$displayName by selecting Save As Template', args: [displayName], name: 'TestClassIntl_bar',);\n";
        expect(file!.readAsStringSync(), [expectedFileContent1, expectedFileContent2].join(''));
      });
    });

  });
}
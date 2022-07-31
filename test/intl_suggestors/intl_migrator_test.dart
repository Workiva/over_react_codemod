import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:over_react_codemod/src/intl_suggestors/intl_migrator.dart';
import 'package:test/test.dart';

import '../resolved_file_context.dart';
import '../util.dart';

void main() {
  final resolvedContext = SharedAnalysisContext.overReact;

  // Warm up analysis in a setUpAll so that if getting the resolved AST times out
  // (which is more common for the WSD context), it fails here instead of failing the first test.
  setUpAll(resolvedContext.warmUpAnalysis);

  group('IntlMigrator', () {
    final FileSystem fs = MemoryFileSystem();
    late File file;
    late SuggestorTester testSuggestor;

    setUp(() async {
      final Directory tmp = await fs.systemTempDirectory.createTemp();
      file = tmp.childFile('TestClassIntl')..createSync(recursive: true);
      testSuggestor = getSuggestorTester(
        IntlMigrator('TestClassIntl', file),
        resolvedContext: resolvedContext,
      );
    });

    tearDown(() {
      file.deleteSync();
    });

    group('Child - StringLiteral', () {
      test('StringLiteral single child', () async {
        await testSuggestor(
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
        final expectedFileContent =
            '\n  static String get viewer => Intl.message(\'viewer\', name: \'TestClassIntl_viewer\',);';
        expect(file.readAsStringSync(), expectedFileContent);
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

                return (Dom.div())(TestClassIntl.testString1, TestClassIntl.testString2,);
              },
              _\$FooConfig, //ignore: undefined_identifier
            );
            ''',
        );

        final expected =
            "\n  static String get testString1 => Intl.message('testString1', name: 'TestClassIntl_testString1',);\n  static String get testString2 => Intl.message('testString2', name: 'TestClassIntl_testString2',);";
        expect(file.readAsStringSync(), expected);
      });

      test('single number string', () async {
        await testSuggestor(
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

    group('Child - StringInterpolation', () {
      test('one argument with top level accessor', () async {
        await testSuggestor(
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

                    return (Dom.div())(TestClassIntl.Foo_intlFunction0(name));
                  },
                  _\$FooConfig, //ignore: undefined_identifier
                );
              ''',
        );
      });

      test('one argument interpolation followed by text', () async {
        await testSuggestor(
          input: '''
                import 'package:over_react/over_react.dart';

                mixin FooProps on UiProps {}

                UiFactory<FooProps> Foo = uiFunction(
                  (props) {
                    final number = '42';

                    return (Dom.div())('Distance \${number}km');
                  },
                  _\$FooConfig, //ignore: undefined_identifier
                );
                ''',
          expectedOutput: '''
                import 'package:over_react/over_react.dart';

                mixin FooProps on UiProps {}

                UiFactory<FooProps> Foo = uiFunction(
                  (props) {
                    final number = '42';

                    return (Dom.div())(TestClassIntl.Foo_intlFunction0(number));
                  },
                  _\$FooConfig, //ignore: undefined_identifier
                );
              ''',
        );

        final expectedFileContent =
            "\n  static String Foo_intlFunction0(String number) => Intl.message('Distance \${number}km', args: [number], name: 'TestClassIntl_Foo_intlFunction0',);";
        expect(file.readAsStringSync(), expectedFileContent);
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

                  return (Dom.div())(TestClassIntl.Foo_intlFunction0(name, title));
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );
        final expectedFileContent =
            "\n  static String Foo_intlFunction0(String name, String title) => Intl.message('Interpolated \${name} \${title}', args: [name, title], name: 'TestClassIntl_Foo_intlFunction0',);";
        expect(file.readAsStringSync(), expectedFileContent);
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

                  return (Dom.div())(TestClassIntl.Foo_intlFunction0(props.name));
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );
        final expectedFileContent =
            "\n  static String Foo_intlFunction0(String name) => Intl.message('Interpolated \${name}', args: [name], name: 'TestClassIntl_Foo_intlFunction0',);";
        expect(file.readAsStringSync(), expectedFileContent);
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

                  return (Dom.div())(
                    TestClassIntl.Foo_intlFunction0(props.name, props.title)
                  );
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );
        final expectedFileContent =
            "\n  static String Foo_intlFunction0(String name, String title) => Intl.message('Interpolated \${name} \${title}', args: [name, title], name: 'TestClassIntl_Foo_intlFunction0',);";
        expect(file.readAsStringSync(), expectedFileContent);
      });

      test('one argument with nested accessor and null operator', () async {
        await testSuggestor(
          input: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {
                String name;
              }

              UiFactory<FooProps> Foo = uiFunction(
                (props) {

                  return (Dom.div())('Interpolated \${props.name ?? \'test\'}');
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

                  return (Dom.div())(TestClassIntl.Foo_intlFunction0(props.name ?? \'test\'));
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );
        final expectedFileContent =
            "\n  static String Foo_intlFunction0(String name) => Intl.message('Interpolated \${name}', args: [name], name: 'TestClassIntl_Foo_intlFunction0',);";
        expect(file.readAsStringSync(), expectedFileContent);
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
                  
                  return (Dom.div())(TestClassIntl.Foo_intlFunction0(getName()));
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );

        final expectedFileContent =
            "\n  static String Foo_intlFunction0(String getName) => Intl.message('His name was \${getName}', args: [getName], name: 'TestClassIntl_Foo_intlFunction0',);";
        expect(file.readAsStringSync(), expectedFileContent);
      });

      test('Interpolated with apostrophe', () async {
        await testSuggestor(
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
                  
                  return (Dom.div())(TestClassIntl.Foo_intlFunction0(lastName));
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );

        final expectedFileContent =
            "\n  static String Foo_intlFunction0(String lastName) => Intl.message('Bob\\\'s last name was \${lastName}', args: [lastName], name: 'TestClassIntl_Foo_intlFunction0',);";
        expect(file.readAsStringSync(), expectedFileContent);
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
                      TestClassIntl.versionInfo(props.version),
                    );
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );

        String expectedFileContent =
            "\n  static String versionInfo(String version) => Intl.message('Version \${version}', args: [version], name: 'TestClassIntl_versionInfo',);";
        expect(file.readAsStringSync(), expectedFileContent);
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
                    TestClassIntl.versionInfo(props.version),
                  );
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );

        String expectedFileContent =
            "\n  static String versionInfo(String version) => Intl.message('Version \${version}', args: [version], name: 'TestClassIntl_versionInfo',);";
        expect(file.readAsStringSync(), expectedFileContent);
      });

      test('Interpolated with testId in a parent node', () async {
        await testSuggestor(
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
                      TestClassIntl.foo(props.displayName),
                    ),
                    (Dom.p()..addTestId('bar'))(
                      (Dom.p())(
                        TestClassIntl.bar(props.displayName),
                      ),
                    ),
                  );
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );

        String expectedFileContent1 =
            "\n  static String foo(String displayName) => Intl.message('Create one from any \${displayName} by selecting Save As Template', args: [displayName], name: 'TestClassIntl_foo',);";
        String expectedFileContent2 =
            "\n  static String bar(String displayName) => Intl.message('Create one from any \${displayName} by selecting Save As Template', args: [displayName], name: 'TestClassIntl_bar',);";
        expect(file.readAsStringSync(),
            [expectedFileContent1, expectedFileContent2].join(''));
      });

      test('Home Example', () async {
        await testSuggestor(
          testIdempotency: false,
          input: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {}

              UiFactory<FooProps> Foo = uiFunction(
                (props) {
                  final fileStr = 'bob';
                  final refStr = 'Test Title';

                  return (Dom.div())(
                    'Now that you\\'ve transitioned your \$fileStr, you\\'ll want to freeze \$refStr or update permissions to prevent others from using \$refStr.',
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
                  final fileStr = 'bob';
                  final refStr = 'Test Title';

                  return (Dom.div())(
                    TestClassIntl.Foo_intlFunction0(fileStr, refStr),
                  );
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );
        final expectedFileContent =
            "\n  static String Foo_intlFunction0(String fileStr, String refStr) => Intl.message('Now that you\\\'ve transitioned your \${fileStr}, you\\\'ll want to freeze \${refStr} or update permissions to prevent others from using \${refStr}.', args: [fileStr, refStr], name: 'TestClassIntl_Foo_intlFunction0',);";
        expect(file.readAsStringSync(), expectedFileContent);
      });
    });

    group('Prop - StringLiteral', () {
      test('uiFunction string literal', () async {
        await testSuggestor(
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
                    ..label = TestClassIntl.testString)();
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );

        final expectedFileOutput =
            '\n  static String get testString => Intl.message(\'Test String\', name: \'TestClassIntl_testString\',);';
        expect(file.readAsStringSync(), expectedFileOutput);
      });

      test('class string literal', () async {
        await testSuggestor(
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
                     ..label = TestClassIntl.testString)();
                 }
               }
              ''',
        );
        final expectedFileOutput =
            '\n  static String get testString => Intl.message(\'Test String\', name: \'TestClassIntl_testString\',);';
        expect(file.readAsStringSync(), expectedFileOutput);
      });

      test('uiFunction props => component', () async {
        await testSuggestor(
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
                      ..label = TestClassIntl.testString)(),
                  _\$FooConfig, //ignore: undefined_identifier
                );
                ''',
        );
        final expectedFileOutput =
            '\n  static String get testString => Intl.message(\'Test String\', name: \'TestClassIntl_testString\',);';
        expect(file.readAsStringSync(), expectedFileOutput);
      });
    });

    group('Prop - StringInterpolation', () {
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
                      ..label = TestClassIntl.Foo_intlFunction0(name))();
                  },
                  _\$FooConfig, //ignore: undefined_identifier
                );
              ''',
        );

        final expectedFileContent =
            "\n  static String Foo_intlFunction0(String name) => Intl.message('Interpolated \${name}', args: [name], name: 'TestClassIntl_Foo_intlFunction0',);";
        expect(file.readAsStringSync(), expectedFileContent);
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
                    ..label = TestClassIntl.Foo_intlFunction0(name, title))();
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );
        final expectedFileContent =
            "\n  static String Foo_intlFunction0(String name, String title) => Intl.message('Interpolated \${name} \${title}', args: [name, title], name: 'TestClassIntl_Foo_intlFunction0',);";
        expect(file.readAsStringSync(), expectedFileContent);
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
                    ..label = TestClassIntl.Foo_intlFunction0(props.name))();
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );
        final expectedFileContent =
            "\n  static String Foo_intlFunction0(String name) => Intl.message('Interpolated \${name}', args: [name], name: 'TestClassIntl_Foo_intlFunction0',);";
        expect(file.readAsStringSync(), expectedFileContent);
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
                    ..label = TestClassIntl.Foo_intlFunction0(props.name, props.title))();
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );
        final expectedFileContent =
            "\n  static String Foo_intlFunction0(String name, String title) => Intl.message('Interpolated \${name} \${title}', args: [name, title], name: 'TestClassIntl_Foo_intlFunction0',);";
        expect(file.readAsStringSync(), expectedFileContent);
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
                    ..label = TestClassIntl.Foo_intlFunction0(getName()))();
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );

        final expectedFileContent =
            "\n  static String Foo_intlFunction0(String getName) => Intl.message('His name was \${getName}', args: [getName], name: 'TestClassIntl_Foo_intlFunction0',);";
        expect(file.readAsStringSync(), expectedFileContent);
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
                    ..label = TestClassIntl.Foo_intlFunction0(lastName))();
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );

        final expectedFileContent =
            "\n  static String Foo_intlFunction0(String lastName) => Intl.message('Bob\\\'s last name was \${lastName}', args: [lastName], name: 'TestClassIntl_Foo_intlFunction0',);";
        expect(file.readAsStringSync(), expectedFileContent);
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
                    ..label = TestClassIntl.versionInfo(props.version))();
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );

        String expectedFileContent =
            "\n  static String versionInfo(String version) => Intl.message('Version \${version}', args: [version], name: 'TestClassIntl_versionInfo',);";
        expect(file.readAsStringSync(), expectedFileContent);
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
                    ..label = TestClassIntl.versionInfo(props.version))();
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );

        String expectedFileContent =
            "\n  static String versionInfo(String version) => Intl.message('Version \${version}', args: [version], name: 'TestClassIntl_versionInfo',);";
        expect(file.readAsStringSync(), expectedFileContent);
      });
    });
  });
}

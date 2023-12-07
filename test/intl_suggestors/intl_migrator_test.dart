import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:over_react_codemod/src/intl_suggestors/intl_messages.dart';
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
    late IntlMessages messages;
    late SuggestorTester basicSuggestor;

    // Idempotency isn't a worry for this suggestor, and testing it throws off
    // using a global counter for numbering messages whose name isn't otherwise
    // unique, so skip that check.
    Future<void> testSuggestor(
            {required String input, required String expectedOutput}) =>
        basicSuggestor(
            input: input,
            expectedOutput: expectedOutput,
            testIdempotency: false);

    setUp(() async {
      final Directory tmp = await fs.systemTempDirectory.createTemp();
      messages = IntlMessages('TestClass', directory: tmp);
      // TODO: It's awkward that this test assumes the file exists, but that it doesn't have the prologue written.
      messages.outputFile.createSync(recursive: true);
      basicSuggestor = getSuggestorTester(
        IntlMigrator('TestClassIntl', messages),
        resolvedContext: resolvedContext,
      );
    });

    tearDown(() {
      messages.delete();
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
            '\n  static String get viewer => Intl.message(\'viewer\', name: \'TestClassIntl_viewer\');\n';
        expect(messages.messageContents(), expectedFileContent);
      });

      test('StringLiteral two children', () async {
        await testSuggestor(
          input: '''
            import 'package:over_react/over_react.dart';

            mixin FooProps on UiProps {}

            UiFactory<FooProps> Foo = uiFunction(
              (props) {

                return (Dom.div())(
                  'test String1',
                  'test String2',
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
            "\n  static String get testString1 => Intl.message('test String1', name: 'TestClassIntl_testString1');\n\n  static String get testString2 => Intl.message('test String2', name: 'TestClassIntl_testString2');\n";
        expect(messages.messageContents(), expected);
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

      test('single punctuation string', () async {
        await testSuggestor(
          input: '''
            import 'package:over_react/over_react.dart';

            mixin FooProps on UiProps {}

            UiFactory<FooProps> Foo = uiFunction(
              (props) {

                return (Dom.div())('[]');
              },
              _\$FooConfig, //ignore: undefined_identifier
            );
            ''',
          expectedOutput: '''
            import 'package:over_react/over_react.dart';

            mixin FooProps on UiProps {}

            UiFactory<FooProps> Foo = uiFunction(
              (props) {

                return (Dom.div())('[]');
              },
              _\$FooConfig, //ignore: undefined_identifier
            );
            ''',
        );
      });

      // here we can call the ignore interpolated variable string
      test('single interpolated variable', () async {
        await testSuggestor(
          input: '''
                import 'package:over_react/over_react.dart';

                mixin FooProps on UiProps {}

                UiFactory<FooProps> Foo = uiFunction(
                  (props) {
                     final name = 'bob';
                    return (Dom.div())('\${name}');
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
                return (Dom.div())('\${name}');
              },
              _\$FooConfig, //ignore: undefined_identifier
            );
            ''',
        );
      });

      test('special character in between two interpolated variables', () async {
        await testSuggestor(
          input: '''
                import 'package:over_react/over_react.dart';

                mixin FooProps on UiProps {}

                UiFactory<FooProps> Foo = uiFunction(
                  (props) {
                     final name = 'bob';
                     final age='42';
                    return (Dom.div())('\${name} : \${age}');
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
                 final age='42';
                return (Dom.div())('\${name} : \${age}');
              },
              _\$FooConfig, //ignore: undefined_identifier
            );
            ''',
        );
      });

      test('adjacent strings', () async {
        await testSuggestor(
          input: '''
            import 'package:over_react/over_react.dart';

            mixin FooProps on UiProps {}

            UiFactory<FooProps> Foo = uiFunction(
              (props) {

                return (Dom.div())('this is a lengthy string, '
                'it\\\'s been broken up into several lines '
                'which Dart automatically concatenates.' );
              },
              _\$FooConfig, //ignore: undefined_identifier
            );
            ''',
          expectedOutput: '''
            import 'package:over_react/over_react.dart';

            mixin FooProps on UiProps {}

            UiFactory<FooProps> Foo = uiFunction(
              (props) {

                return (Dom.div())(TestClassIntl.thisIsALengthyString);
              },
              _\$FooConfig, //ignore: undefined_identifier
            );
            ''',
        );
        final expected =
            "\n  static String get thisIsALengthyString => Intl.message('this is a lengthy string, it\\\'s been broken up into several lines which Dart automatically concatenates.', name: 'TestClassIntl_thisIsALengthyString');\n";
        expect(messages.messageContents(), expected);
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

                    return (Dom.div())(TestClassIntl.interpolated(name));
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

                    return (Dom.div())(TestClassIntl.distanceKm(number));
                  },
                  _\$FooConfig, //ignore: undefined_identifier
                );
              ''',
        );

        final expectedFileContent =
            "\n  static String distanceKm(String number) => Intl.message('Distance \${number}km', args: [number], name: 'TestClassIntl_distanceKm');\n";
        expect(messages.messageContents(), expectedFileContent);
      });

      test('string in between interpolated variable', () async {
        await testSuggestor(
          input: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {
                String name;
                String title;
              }

              UiFactory<FooProps> Foo = uiFunction(
                (props) {

                  return (Dom.div())('\${props.name} Interpolated \${props.title}');
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
                    TestClassIntl.interpolated(props.name, props.title)
                  );
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );
        final expectedFileContent =
            "\n  static String interpolated(String name, String title) => Intl.message('\${name} Interpolated \${title}', args: [name, title], name: 'TestClassIntl_interpolated');\n";
        expect(messages.messageContents(), expectedFileContent);
      });

      test('two different interpolations get different names', () async {
        await testSuggestor(
          input: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {}

              UiFactory<FooProps> Foo = uiFunction(
                (props) {
                  final name = 'bob';
                  final title = 'Test Title';

                  return (Dom.div()..label='Also interpolated \$title')('Interpolated \${name}');
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

                  return (Dom.div()..label=TestClassIntl.alsoInterpolated(title))(TestClassIntl.interpolated(name));
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );
        final expectedFileContent =
            "\n  static String alsoInterpolated(String title) => Intl.message('Also interpolated \${title}', args: [title], name: 'TestClassIntl_alsoInterpolated');\n"
            "\n  static String interpolated(String name) => Intl.message('Interpolated \${name}', args: [name], name: 'TestClassIntl_interpolated');\n";
        expect(messages.messageContents(), expectedFileContent);
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

                  return (Dom.div())(TestClassIntl.interpolated(name, title));
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );
        final expectedFileContent =
            "\n  static String interpolated(String name, String title) => Intl.message('Interpolated \${name} \${title}', args: [name, title], name: 'TestClassIntl_interpolated');\n";
        expect(messages.messageContents(), expectedFileContent);
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

                  return (Dom.div())(TestClassIntl.interpolated(props.name));
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );
        final expectedFileContent =
            "\n  static String interpolated(String name) => Intl.message('Interpolated \${name}', args: [name], name: 'TestClassIntl_interpolated');\n";
        expect(messages.messageContents(), expectedFileContent);
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
                    TestClassIntl.interpolated(props.name, props.title)
                  );
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );
        final expectedFileContent =
            "\n  static String interpolated(String name, String title) => Intl.message('Interpolated \${name} \${title}', args: [name, title], name: 'TestClassIntl_interpolated');\n";
        expect(messages.messageContents(), expectedFileContent);
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

                  return (Dom.div())(TestClassIntl.interpolated(props.name ?? \'test\'));
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );
        final expectedFileContent =
            "\n  static String interpolated(String name) => Intl.message('Interpolated \${name}', args: [name], name: 'TestClassIntl_interpolated');\n";
        expect(messages.messageContents(), expectedFileContent);
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
                  
                  return (Dom.div())(TestClassIntl.hisNameWas(getName()));
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );

        final expectedFileContent =
            "\n  static String hisNameWas(String getName) => Intl.message('His name was \${getName}', args: [getName], name: 'TestClassIntl_hisNameWas');\n";
        expect(messages.messageContents(), expectedFileContent);
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
                  
                  return (Dom.div())(TestClassIntl.bobsLastNameWas(lastName));
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );

        final expectedFileContent =
            "\n  static String bobsLastNameWas(String lastName) => Intl.message('Bob\\\'s last name was \${lastName}', args: [lastName], name: 'TestClassIntl_bobsLastNameWas');\n";
        expect(messages.messageContents(), expectedFileContent);
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
                      TestClassIntl.version(props.version),
                    );
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );

        String expectedFileContent =
            "\n  static String version(String version) => Intl.message('Version \${version}', args: [version], name: 'TestClassIntl_version');\n";
        expect(messages.messageContents(), expectedFileContent);
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
                    TestClassIntl.version(props.version),
                  );
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );

        String expectedFileContent =
            "\n  static String version(String version) => Intl.message('Version \${version}', args: [version], name: 'TestClassIntl_version');\n";
        expect(messages.messageContents(), expectedFileContent);
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
                      TestClassIntl.createOneFromAnyBy(props.displayName),
                    ),
                    (Dom.p()..addTestId('bar'))(
                      (Dom.p())(
                        TestClassIntl.createOneFromAnyBy(props.displayName),
                      ),
                    ),
                  );
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );

        String expectedFileContent1 =
            "\n  static String createOneFromAnyBy(String displayName) => Intl.message('Create one from any \${displayName} by selecting Save As Template', args: [displayName], name: 'TestClassIntl_createOneFromAnyBy');\n";
        expect(messages.messageContents(), expectedFileContent1);
      });

      test('Home Example', () async {
        await testSuggestor(
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
                    TestClassIntl.nowThatYouveTransitionedYour(fileStr, refStr),
                  );
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );
        final expectedFileContent =
            "\n  static String nowThatYouveTransitionedYour(String fileStr, String refStr) => Intl.message('Now that you\\\'ve transitioned your \${fileStr}, you\\\'ll want to freeze \${refStr} or update permissions to prevent others from using \${refStr}.', args: [fileStr, refStr], name: 'TestClassIntl_nowThatYouveTransitionedYour');\n";
        expect(messages.messageContents(), expectedFileContent);
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
            '\n  static String get testString => Intl.message(\'Test String\', name: \'TestClassIntl_testString\');\n';
        expect(messages.messageContents(), expectedFileOutput);
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
            '\n  static String get testString => Intl.message(\'Test String\', name: \'TestClassIntl_testString\');\n';
        expect(messages.messageContents(), expectedFileOutput);
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
            '\n  static String get testString => Intl.message(\'Test String\', name: \'TestClassIntl_testString\');\n';
        expect(messages.messageContents(), expectedFileOutput);
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
                      ..label = TestClassIntl.interpolated(name))();
                  },
                  _\$FooConfig, //ignore: undefined_identifier
                );
              ''',
        );

        final expectedFileContent =
            "\n  static String interpolated(String name) => Intl.message('Interpolated \${name}', args: [name], name: 'TestClassIntl_interpolated');\n";
        expect(messages.messageContents(), expectedFileContent);
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
                    ..label = TestClassIntl.interpolated(name, title))();
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );
        final expectedFileContent =
            "\n  static String interpolated(String name, String title) => Intl.message('Interpolated \${name} \${title}', args: [name, title], name: 'TestClassIntl_interpolated');\n";
        expect(messages.messageContents(), expectedFileContent);
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
                    ..label = TestClassIntl.interpolated(props.name))();
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );
        final expectedFileContent =
            "\n  static String interpolated(String name) => Intl.message('Interpolated \${name}', args: [name], name: 'TestClassIntl_interpolated');\n";
        expect(messages.messageContents(), expectedFileContent);
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
                    ..label = TestClassIntl.interpolated(props.name, props.title))();
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );
        final expectedFileContent =
            "\n  static String interpolated(String name, String title) => Intl.message('Interpolated \${name} \${title}', args: [name, title], name: 'TestClassIntl_interpolated');\n";
        expect(messages.messageContents(), expectedFileContent);
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
                    ..label = TestClassIntl.hisNameWas(getName()))();
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );

        final expectedFileContent =
            "\n  static String hisNameWas(String getName) => Intl.message('His name was \${getName}', args: [getName], name: 'TestClassIntl_hisNameWas');\n";
        expect(messages.messageContents(), expectedFileContent);
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
                    ..label = TestClassIntl.bobsLastNameWas(lastName))();
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );

        final expectedFileContent =
            "\n  static String bobsLastNameWas(String lastName) => Intl.message('Bob\\\'s last name was \${lastName}', args: [lastName], name: 'TestClassIntl_bobsLastNameWas');\n";
        expect(messages.messageContents(), expectedFileContent);
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
                    ..label = TestClassIntl.version(props.version))();
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );

        String expectedFileContent =
            "\n  static String version(String version) => Intl.message('Version \${version}', args: [version], name: 'TestClassIntl_version');\n";
        expect(messages.messageContents(), expectedFileContent);
      });
    });

    group('Ignore', () {
      test('Ignore statement with ignore comment', () async {
        final source = 'import \'package:over_react/over_react.dart\';\n'
            '\n'
            'mixin FooProps on UiProps {}\n'
            '\n'
            'UiFactory<FooProps> Foo = uiFunction(\n'
            '  (props) {\n'
            '    return (Dom.div())(\n'
            '      \'test String1\',\n'
            '      \'test String2\',\n'
            '    );\n'
            '  },\n'
            '  _\$FooConfig, //ignore: undefined_identifier\n'
            ');\n'
            '\n'
            'UiFactory<FooProps> Bar = uiFunction(\n'
            '  (props) {\n'
            '    //ignore_statement: intl_message_migration\n'
            '    return (Dom.div())(\n'
            '      \'test String1\',\n'
            '      \'test String2\',\n'
            '    );\n'
            '  },\n'
            '  _\$FooConfig, //ignore: undefined_identifier\n'
            ');\n'
            '';
        final output = 'import \'package:over_react/over_react.dart\';\n'
            '\n'
            'mixin FooProps on UiProps {}\n'
            '\n'
            'UiFactory<FooProps> Foo = uiFunction(\n'
            '  (props) {\n'
            '    return (Dom.div())(\n'
            '      TestClassIntl.testString1,\n'
            '      TestClassIntl.testString2,\n'
            '    );\n'
            '  },\n'
            '  _\$FooConfig, //ignore: undefined_identifier\n'
            ');\n'
            '\n'
            'UiFactory<FooProps> Bar = uiFunction(\n'
            '  (props) {\n'
            '    //ignore_statement: intl_message_migration\n'
            '    return (Dom.div())(\n'
            '      \'test String1\',\n'
            '      \'test String2\',\n'
            '    );\n'
            '  },\n'
            '  _\$FooConfig, //ignore: undefined_identifier\n'
            ');\n'
            '';

        await testSuggestor(
          input: source,
          expectedOutput: output,
        );
      });

      test('Ignore line within a component', () async {
        final source = '''
import 'package:over_react/over_react.dart';
            
mixin FooProps on UiProps {}
          
  UiFactory<FooProps> Bar = uiFunction(
    (props) {
      return (Dom.div()
        ..value='foo'
        //ignore_statement: intl_message_migration
        ..value='bar'
        ..title='qux')(
         'test String1',
        );
    },
    _\$FooConfig, //ignore: undefined_identifier
  );
''';

        final output = '''
import 'package:over_react/over_react.dart';
            
mixin FooProps on UiProps {}
          
  UiFactory<FooProps> Bar = uiFunction(
    (props) {
      return (Dom.div()
        ..value=TestClassIntl.foo
        //ignore_statement: intl_message_migration
        ..value='bar'
        ..title=TestClassIntl.qux)(
         TestClassIntl.testString1,
        );
    },
    _\$FooConfig, //ignore: undefined_identifier
  );
''';

        await testSuggestor(
          input: source,
          expectedOutput: output,
        );
      });

      test('Ignore statement with ignore comment with leading spaces',
          () async {
        final source = 'import \'package:over_react/over_react.dart\';\n'
            '\n'
            'mixin FooProps on UiProps {}\n'
            '\n'
            'UiFactory<FooProps> Foo = uiFunction(\n'
            '  (props) {\n'
            '    // ignore_statement: intl_message_migration \n'
            '    const String uploaderAutomationId = \'Shell.Rich.Body.Uploader\';'
            '    // ignore_statement: intl_message_migration \n'
            '    return (Dom.div())(\n'
            '      \'test String1\',\n'
            '      uploaderAutomationId,\n'
            '    );\n'
            '  },\n'
            '  _\$FooConfig, //ignore: undefined_identifier\n'
            ');\n'
            '\n'
            'UiFactory<FooProps> Bar = uiFunction(\n'
            '  (props) {\n'
            '    return (Dom.div())(\n'
            '      \'test String1\',\n'
            '      \'test String2\',\n'
            '    );\n'
            '  },\n'
            '  _\$FooConfig, //ignore: undefined_identifier\n'
            ');\n'
            '';
        final output = 'import \'package:over_react/over_react.dart\';\n'
            '\n'
            'mixin FooProps on UiProps {}\n'
            '\n'
            'UiFactory<FooProps> Foo = uiFunction(\n'
            '  (props) {\n'
            '    // ignore_statement: intl_message_migration \n'
            '    const String uploaderAutomationId = \'Shell.Rich.Body.Uploader\';'
            '    // ignore_statement: intl_message_migration \n'
            '    return (Dom.div())(\n'
            '      \'test String1\',\n'
            '      uploaderAutomationId,\n'
            '    );\n'
            '  },\n'
            '  _\$FooConfig, //ignore: undefined_identifier\n'
            ');\n'
            '\n'
            'UiFactory<FooProps> Bar = uiFunction(\n'
            '  (props) {\n'
            '    return (Dom.div())(\n'
            '      TestClassIntl.testString1,\n'
            '      TestClassIntl.testString2,\n'
            '    );\n'
            '  },\n'
            '  _\$FooConfig, //ignore: undefined_identifier\n'
            ');\n'
            '';

        await testSuggestor(
          input: source,
          expectedOutput: output,
        );
      });

      test('Ignore file with ignore comment', () async {
        final source = '''
            //ignore_file: intl_message_migration
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
            ''';

        await testSuggestor(
          input: source,
          expectedOutput: source,
        );

        expect(messages.messageContents(), '');
      });
    });
    group('ContextMenuMigrator', () {
      setUp(() {
        basicSuggestor = getSuggestorTester(
          ContextMenuMigrator('TestClassIntl', messages),
          resolvedContext: resolvedContext,
        );
      });
      test('Simple literal', () async {
        await testSuggestor(
          // To avoid defining a method by that name, use a dynamic variable so
          // the analysis will pass.
          input: '''
            dynamic placeholder;
            someFunction() {
              placeholder.addContextMenuItem('abc', () => 'hello', iconGlyph: null);
            }
            ''',
          expectedOutput: '''
            dynamic placeholder;
            someFunction() {
              placeholder.addContextMenuItem(TestClassIntl.abc, () => 'hello', iconGlyph: null);
            }
            ''',
        );
        final expectedFileContent =
            '\n  static String get abc => Intl.message(\'abc\', name: \'TestClassIntl_abc\');\n';
        expect(messages.messageContents(), expectedFileContent);
      });

      test('Interpolation', () async {
        await testSuggestor(
          input: '''
            dynamic placeholder;
            someFunction(String thing) {
              placeholder.addContextMenuItem('abc \$thing', () => 'hello', iconGlyph: null);
            }
            ''',
          expectedOutput: '''
            dynamic placeholder;
            someFunction(String thing) {
              placeholder.addContextMenuItem(
                // FIXME - INTL Untranslated interpolated value. Is this one of a known set of possibilities?
                TestClassIntl.abc(thing),
                () => 'hello',
                iconGlyph: null);
            }
            ''',
        );

        final expected =
            "\n  static String abc(String thing) => Intl.message('abc \${thing}', args: [thing], name: 'TestClassIntl_abc');\n";
        expect(messages.messageContents(), expected);
      });
    });
  });
}

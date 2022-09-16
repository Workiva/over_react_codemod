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

  group('Constant Migrator', () {
    final FileSystem fs = MemoryFileSystem();
    late IntlMessages messages;
    late SuggestorTester basicSuggestor;

    // Idempotency isn't a worry for this suggestor, and testing it throws off
    // checking for duplicates, so disable it for these tests.
    // TODO: Avoid duplicating this between test files.
    Future<void> testSuggestor(
            {required String input, required String expectedOutput}) =>
        basicSuggestor(
            input: input,
            expectedOutput: expectedOutput,
            testIdempotency: false);

    setUp(() async {
      final Directory tmp = await fs.systemTempDirectory.createTemp();
      messages = IntlMessages('TestClass', directory: tmp);
      messages.outputFile.createSync(recursive: true);
      basicSuggestor = getSuggestorTester(
        ConstantStringMigrator('TestClassIntl', messages),
        resolvedContext: resolvedContext,
      );
    });

    tearDown(() {
      messages.delete();
    });

    group('Constants', () {
      test('standlalone constant', () async {
        await testSuggestor(
          input: '''
            const foo = 'I am a user-visible constant';
            ''',
          expectedOutput: '''
            final String foo = TestClassIntl.foo;
            ''',
        );
        final expectedFileContent =
            '\n  static String get foo => Intl.message(\'I am a user-visible constant\', name: \'TestClassIntl_foo\');';
        expect(messages.messageContents(), expectedFileContent);
      });

      test('non-matching standalone constant', () async {
        await testSuggestor(
          input: '''
            const foo = 'probably-not';
            ''',
          expectedOutput: '''
            const foo = 'probably-not';
            ''',
        );
        final expectedFileContent = '';
        expect(messages.messageContents(), expectedFileContent);
      });

      test('static constant', () async {
        await testSuggestor(
          input: '''
          class Bar {
            static const foo = 'I am a user-visible constant';
          }
            ''',
          expectedOutput: '''
          class Bar { 
            static final String foo = TestClassIntl.foo;
          }
            ''',
        );
        final expectedFileContent =
            '\n  static String get foo => Intl.message(\'I am a user-visible constant\', name: \'TestClassIntl_foo\');';
        expect(messages.messageContents(), expectedFileContent);
      });

      test('private constant', () async {
        await testSuggestor(
          input: '''
          class Bar {
            static const _foo = 'I am a user-visible constant';
          }
            ''',
          expectedOutput: '''
          class Bar { 
            static final String _foo = TestClassIntl.foo;
          }
            ''',
        );
        final expectedFileContent =
            '\n  static String get foo => Intl.message(\'I am a user-visible constant\', name: \'TestClassIntl_foo\');';
        expect(messages.messageContents(), expectedFileContent);
      });

      test('duplicate static names', () async {
        await testSuggestor(
          input: '''
          class Bar {
            static const foo = 'I am a user-visible constant';
          }
          class Qux {
            static const foo = 'Another static';
          }
          const foo = 'A different constant';
            ''',
          expectedOutput: '''
          class Bar { 
            static final String foo = TestClassIntl.foo;
          }
          class Qux {
            static final String foo = TestClassIntl.anotherStatic;
          }

          final String foo = TestClassIntl.aDifferentConstant;
          
            ''',
        );
        final expectedFileContent = '''
  static String get aDifferentConstant => Intl.message(\'A different constant\', name: \'TestClassIntl_aDifferentConstant\');
  static String get anotherStatic => Intl.message(\'Another static\', name: \'TestClassIntl_anotherStatic\');
  static String get foo => Intl.message(\'I am a user-visible constant\', name: \'TestClassIntl_foo\');
''';
        expect(messages.messageContents().trim(),
            expectedFileContent.trim()); // Avoid the leading return.
      });

      test('duplicate static names with duplicated text', () async {
        await testSuggestor(
          input: '''
          class Bar {
            static const foo = 'I am a user-visible constant';
          }
          class Qux {
            static const foo = 'Another static';
          }
          const foo = 'Another static';
            ''',
          expectedOutput: '''
          class Bar { 
            static final String foo = TestClassIntl.foo;
          }
          class Qux {
            static final String foo = TestClassIntl.anotherStatic;
          }

          final String foo = TestClassIntl.anotherStatic;
          
            ''',
        );
        final expectedFileContent = '''
  static String get anotherStatic => Intl.message(\'Another static\', name: \'TestClassIntl_anotherStatic\');
  static String get foo => Intl.message(\'I am a user-visible constant\', name: \'TestClassIntl_foo\');
''';
        expect(messages.messageContents().trim(),
            expectedFileContent.trim()); // Avoid the leading return.
      });
    });
  });
}

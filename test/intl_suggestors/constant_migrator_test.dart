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
            '\n  static String get foo => Intl.message(\'I am a user-visible constant\', name: \'TestClassIntl_foo\');\n';
        expect(messages.messageContents(), expectedFileContent);
      });

      test('non-matching standalone constant', () async {
        await testSuggestor(
          input: '''
            const foo = 'probably_not';
            ''',
          expectedOutput: '''
            const foo = 'probably_not';
            ''',
        );
        final expectedFileContent = '';
        expect(messages.messageContents(), expectedFileContent);
      });

      test('CamelCase constant', () async {
        await testSuggestor(
          input: '''
            const foo = 'ProbablyAnIdentifier';
            ''',
          expectedOutput: '''
            const foo = 'ProbablyAnIdentifier';
            ''',
        );
        final expectedFileContent = '';
        expect(messages.messageContents(), expectedFileContent);
      });

      test('Pendo ID', () async {
        await testSuggestor(
          input: '''
            const foo = 'Probably.An.Identifier';
            ''',
          expectedOutput: '''
            const foo = 'Probably.An.Identifier';
            ''',
        );
        final expectedFileContent = '';
        expect(messages.messageContents(), expectedFileContent);
      });

      test('ignored standalone constant', () async {
        var input = '''
            // ignore_statement: intl_message_migration
            const foo = 'I am a user-visible constant';
            ''';
        await testSuggestor(
          input: input,
          expectedOutput: input,
        );
        final expectedFileContent = '';
        expect(messages.messageContents(), expectedFileContent);
      });

      test('ignored with preceding comment', () async {
        var input = '''
            // This says it's user-visible, but don't believe its lies!
            // ignore_statement: intl_message_migration
            const foo = 'I am a user-visible constant';
            ''';
        await testSuggestor(
          input: input,
          expectedOutput: input,
        );
        final expectedFileContent = '';
        expect(messages.messageContents(), expectedFileContent);
      });

      test('ignore one but not the second', () async {
        var input = '''
            // ignore_statement: intl_message_migration
            const foo = 'I am a user-visible constant';
            const bar = 'Me too!';
            ''';
        await testSuggestor(
          input: input,
          expectedOutput: '''
            // ignore_statement: intl_message_migration
            const foo = 'I am a user-visible constant';
            final String bar = TestClassIntl.bar;
            ''',
        );
        final expectedFileContent =
            '\n  static String get bar => Intl.message(\'Me too!\', name: \'TestClassIntl_bar\');\n';
        expect(messages.messageContents(), expectedFileContent);
      });

      test('ignored standalone constant in file', () async {
        var input = '''
            // ignore_file: intl_message_migration
            var x = 4;
            var y = x == 5 ? x : 42;
            const foo = 'I am a user-visible constant';
            ''';
        await testSuggestor(
          input: input,
          expectedOutput: input,
        );
        final expectedFileContent = '';
        expect(messages.messageContents(), expectedFileContent);
      });

      test('SCREAMING_CAPS_ARE_IGNORED', () async {
        await testSuggestor(
          input: '''
            const foo = 'DO_NOT_CONVERT_ME';
            ''',
          expectedOutput: '''
            const foo = 'DO_NOT_CONVERT_ME';
            ''',
        );
        final expectedFileContent = '';
        expect(messages.messageContents(), expectedFileContent);
      });

      test('date formats are ignored', () async {
        await testSuggestor(
          input: '''
            const foo = 'MM/dd/yy';
            ''',
          expectedOutput: '''
            const foo = 'MM/dd/yy';
            ''',
        );
        final expectedFileContent = '';
        expect(messages.messageContents(), expectedFileContent);
      });

      test('date format logic does not have false positives', () async {
        await testSuggestor(
          input: '''
            const migrateMe = 'migrate me';
            ''',
          expectedOutput: '''
            final String migrateMe = TestClassIntl.migrateMe;
            ''',
        );
        final expectedFileContent =
            '\n  static String get migrateMe => Intl.message(\'migrate me\', name: \'TestClassIntl_migrateMe\');\n';
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
            '\n  static String get foo => Intl.message(\'I am a user-visible constant\', name: \'TestClassIntl_foo\');\n';
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
            '\n  static String get foo => Intl.message(\'I am a user-visible constant\', name: \'TestClassIntl_foo\');\n';
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

      test('duplicate static names with duplicated text, with double quotes',
          () async {
        await testSuggestor(
          input: '''
          class Bar {
            static const foo = "I am a user-visible constant";
          }
          class Qux {
            static const foo = "Another static";
          }
          const foo = "Another static";
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

      test('duplicate getter names increment', () async {
        await testSuggestor(
          input: '''
          const String dueDate = 'Due Date';
          class Dupe {
            static const dueDate = 'Due date';
          }
            ''',
          expectedOutput: '''
          final String dueDate = TestClassIntl.dueDate;
          class Dupe {
            static final String dueDate = TestClassIntl.dueDate1;
          }          
            ''',
        );
        final expectedFileContent = '''
  static String get dueDate => Intl.message(\'Due Date\', name: \'TestClassIntl_dueDate\');

  static String get dueDate1 => Intl.message(\'Due date\', name: \'TestClassIntl_dueDate1\');

''';
        expect(messages.messageContents().trim(),
            expectedFileContent.trim()); // Avoid the leading return.
      });
    });
  });
}

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:over_react_codemod/src/executables/intl_quick_migration.dart';
import 'package:over_react_codemod/src/intl_suggestors/intl_messages.dart';
import 'package:test/test.dart';

import '../resolved_file_context.dart';
import '../util.dart';

void main() {
  final resolvedContext = SharedAnalysisContext.overReact;

  // Warm up analysis in a setUpAll so that if getting the resolved AST times out
  // (which is more common for the WSD context), it fails here instead of failing the first test.
  setUpAll(resolvedContext.warmUpAnalysis);

  group('Single string Migrator', () {
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
    });

    suggest(int characterPosition) {
      basicSuggestor = getSuggestorTester(
        SingleStringMigrator(messages, characterPosition, characterPosition),
        resolvedContext: resolvedContext,
      );
    }

    tearDown(() {
      messages.delete();
    });

    group('Constants', () {
      test('standlalone variable', () async {
        suggest(26);
        await testSuggestor(
          input: '''
            var foo = 'I am a user-visible constant';
            ''',
          expectedOutput: '''
            var foo = TestClassIntl.iAmAUservisibleConstant;
            ''',
        );
        final expectedFileContent =
            '\n  static String get iAmAUservisibleConstant => Intl.message(\'I am a user-visible constant\', name: \'TestClassIntl_iAmAUservisibleConstant\');\n';
        expect(messages.messageContents(), expectedFileContent);
      });

      test('out of range', () async {
        suggest(15);
        await testSuggestor(
          input: '''
            var foo = 'I am a user-visible constant';
            ''',
          expectedOutput: '''
            var foo = 'I am a user-visible constant';
            ''',
        );
        final expectedFileContent = '';
        expect(messages.messageContents(), expectedFileContent);
      });
    });
  });
}

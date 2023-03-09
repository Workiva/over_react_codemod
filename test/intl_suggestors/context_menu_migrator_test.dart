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

  group('ContextMenuMigrator', () {
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
        ContextMenuMigrator('TestClassIntl', messages),
        resolvedContext: resolvedContext,
      );
    });

    tearDown(() {
      messages.delete();
    });

    group('Context menu', () {
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
            '\n  static String get abc => Intl.message(\'abc\', name: \'TestClassIntl_abc\');';
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
            "\n  static String abc(String thing) => Intl.message('abc \${thing}', args: [thing], name: 'TestClassIntl_abc');";
        expect(messages.messageContents(), expected);
      });
    });
  });
}

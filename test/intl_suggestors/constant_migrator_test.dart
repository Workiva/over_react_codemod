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

  group('Constant Migrator', () {
    final FileSystem fs = MemoryFileSystem();
    late File file;
    late SuggestorTester testSuggestor;

    setUp(() async {
      final Directory tmp = await fs.systemTempDirectory.createTemp();
      file = tmp.childFile('TestClassIntl')..createSync(recursive: true);
      testSuggestor = getSuggestorTester(
        ConstantStringMigrator('TestClassIntl', file),
        resolvedContext: resolvedContext,
      );
    });

    tearDown(() {
      file.deleteSync();
    });

    group('Constants', () {
      test('standlalone constant', () async {
        await testSuggestor(
          input: '''
            const foo = 'I am a user-visible constant';
            ''',
          expectedOutput: '''
            final String foo = TestClassIntl.iAmAUservisibleConstant;
            ''',
        );
        final expectedFileContent =
            '\n\tstatic String get iAmAUservisibleConstant => Intl.message(\'I am a user-visible constant\', name: \'TestClassIntl_iAmAUservisibleConstant\',);';
        expect(file.readAsStringSync(), expectedFileContent);
      });

      test('non-matching standlalone constant', () async {
        await testSuggestor(
          input: '''
            const foo = 'probably-not';
            ''',
          expectedOutput: '''
            const foo = 'probably-not';
            ''',
        );
        final expectedFileContent = '';
        expect(file.readAsStringSync(), expectedFileContent);
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
            static final String foo = TestClassIntl.iAmAUservisibleConstant;
          }
            ''',
        );
        final expectedFileContent =
            '\n\tstatic String get iAmAUservisibleConstant => Intl.message(\'I am a user-visible constant\', name: \'TestClassIntl_iAmAUservisibleConstant\',);';
        expect(file.readAsStringSync(), expectedFileContent);
      });
    });
  });
}

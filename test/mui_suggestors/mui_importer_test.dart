import 'package:analyzer/error/error.dart';
import 'package:over_react_codemod/src/mui_suggestors/mui_importer.dart';
import 'package:test/test.dart';

import '../resolved_file_context.dart';
import '../util.dart';

void main() {
  final resolvedContext = SharedAnalysisContext.overReact;

  // Don't forget that testSuggestor tests idempotency by default, which is
  // especially important for this suggestor.

  group('muiImporter', () {
    final testSuggestor = getSuggestorTester(
      muiImporter,
      resolvedContext: resolvedContext,
    );

    test(
        'adds a RMUI import when there is an undefined `mui` identifier in the file',
        () async {
      await testSuggestor(
        input: /*language=dart*/ '''
            content() => mui.Button();
        ''',
        isExpectedError: isUndefinedMuiError,
        expectedOutput: /*language=dart*/ '''
            import 'package:react_material_ui/react_material_ui.dart' as mui;
            content() => mui.Button();
        ''',
      );
    });

    test(
        'adds a RMUI import when there is an undefined `mui` identifier in a part file',
        () async {
      // testSuggestor isn't really set up for multiple files,
      // so the test setup here is a little more manual.

      const partFilename = 'mui_importer_test_part.dart';
      const mainLibraryFilename = 'mui_importer_test_main_library.dart';

      final partFileContext =
          await resolvedContext.resolvedFileContextForTest('''
            part of '${mainLibraryFilename}';
  
            content() => mui.Button();
        ''',
              filename: partFilename,
              // Don't pre-resolve since this isn't a library.
              preResolveLibrary: false,
              throwOnAnalysisErrors: false);

      final mainLibraryFileContext =
          await resolvedContext.resolvedFileContextForTest(
        '''
            part '${partFilename}';
        ''',
        filename: mainLibraryFilename,
        isExpectedError: isUndefinedMuiError,
      );

      final mainPatches = await muiImporter(mainLibraryFileContext).toList();
      expect(mainPatches, [
        hasPatchText(contains(
            "import 'package:react_material_ui/react_material_ui.dart' as mui;")),
      ]);

      final partPatches = await muiImporter(partFileContext).toList();
      expect(partPatches, isEmpty);
    });

    group('does not add an RMUI import when', () {
      test('a `mui` identifier in the file is not undefined', () async {
        await testSuggestor(
          input: /*language=dart*/ '''
              dynamic mui;
              content() => mui.Button();
          ''',
        );
      });

      test('there is no `mui` identifier in the file', () async {
        await testSuggestor(
          input: /*language=dart*/ '''
              content() {}
          ''',
        );
      });
    });
  });
}

bool isUndefinedMuiError(AnalysisError error) =>
    error.message.contains("Undefined name 'mui'");

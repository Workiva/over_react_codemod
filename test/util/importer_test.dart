// Copyright 2021 Workiva Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:analyzer/error/error.dart';
import 'package:over_react_codemod/src/mui_suggestors/constants.dart';
import 'package:over_react_codemod/src/util/importer.dart';
import 'package:test/test.dart';

import '../resolved_file_context.dart';
import '../util.dart';

void main() {
  group('importerSuggestorBuilder', () {
    final resolvedContext = SharedAnalysisContext.overReact;
    final muiImporter = importerSuggestorBuilder(
        importUri: rmuiImportUri, importNamespace: muiNs);

    // Warm up analysis in a setUpAll so that if getting the resolved AST times out
    // (which is more common for the WSD context), it fails here instead of failing the first test.
    setUpAll(resolvedContext.warmUpAnalysis);

    // Don't forget that testSuggestor tests idempotency by default, which is
    // especially important for this suggestor.
    final testSuggestor = getSuggestorTester(
      muiImporter,
      resolvedContext: resolvedContext,
    );

    group(
        'adds a RMUI import when there is an undefined `mui` identifier in the file',
        () {
      bool isFakeUriError(AnalysisError error) =>
          error.errorCode.name.toLowerCase() == 'uri_does_not_exist' &&
          error.message.contains('fake');

      test('when there are no other imports', () async {
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

      group('when there are other imports', () {
        test('(alphabetized before RMUI)', () async {
          await testSuggestor(
            input: /*language=dart*/ '''
                import 'package:over_react/over_react.dart';
            
                content() => mui.Button();
            ''',
            isExpectedError: isUndefinedMuiError,
            expectedOutput: /*language=dart*/ '''
                import 'package:over_react/over_react.dart';
                import 'package:react_material_ui/react_material_ui.dart' as mui;
                
                content() => mui.Button();
            ''',
          );
        });

        test('(alphabetized after RMUI)', () async {
          await testSuggestor(
            input: /*language=dart*/ '''
                import 'package:z_fake_package/z_fake_package.dart';
            
                content() => mui.Button();
            ''',
            isExpectedError: (e) => isUndefinedMuiError(e) || isFakeUriError(e),
            expectedOutput: /*language=dart*/ '''
                import 'package:react_material_ui/react_material_ui.dart' as mui;
                import 'package:z_fake_package/z_fake_package.dart';
                
                content() => mui.Button();
            ''',
          );
        });

        test('(one alphabetized before and after RMUI)', () async {
          await testSuggestor(
            input: /*language=dart*/ '''
                import 'package:over_react/over_react.dart';
                import 'package:z_fake_package/z_fake_package.dart';
            
                content() => mui.Button();
            ''',
            isExpectedError: (e) => isUndefinedMuiError(e) || isFakeUriError(e),
            expectedOutput: /*language=dart*/ '''
                import 'package:over_react/over_react.dart';
                import 'package:react_material_ui/react_material_ui.dart' as mui;
                import 'package:z_fake_package/z_fake_package.dart';
                
                content() => mui.Button();
            ''',
          );
        });

        test('(more than one alphabetized before and after RMUI)', () async {
          await testSuggestor(
            input: /*language=dart*/ '''
                import 'package:over_react/over_react.dart';
                import 'package:over_react/components.dart';
                import 'package:z_fake_package/z_fake_package_1.dart';
                import 'package:z_fake_package/z_fake_package_2.dart';
            
                content() => mui.Button();
            ''',
            isExpectedError: (e) => isUndefinedMuiError(e) || isFakeUriError(e),
            expectedOutput: /*language=dart*/ '''
                import 'package:over_react/over_react.dart';
                import 'package:over_react/components.dart';
                import 'package:react_material_ui/react_material_ui.dart' as mui;
                import 'package:z_fake_package/z_fake_package_1.dart';
                import 'package:z_fake_package/z_fake_package_2.dart';
                
                content() => mui.Button();
            ''',
          );
        });

        test('(a relative import, alphabetized before RMUI)', () async {
          await testSuggestor(
            input: /*language=dart*/ '''
                import 'package:over_react/over_react.dart';
                
                import 'a/fake_relative_file.dart';
            
                content() => mui.Button();
            ''',
            isExpectedError: (e) => isUndefinedMuiError(e) || isFakeUriError(e),
            expectedOutput: /*language=dart*/ '''
                import 'package:over_react/over_react.dart';
                import 'package:react_material_ui/react_material_ui.dart' as mui;
                
                import 'a/fake_relative_file.dart';
                
                content() => mui.Button();
            ''',
          );
        });

        test('(a dart import)', () async {
          await testSuggestor(
            input: /*language=dart*/ '''
                import 'dart:html';
            
                content() => mui.Button();
            ''',
            isExpectedError: (e) => isUndefinedMuiError(e) || isFakeUriError(e),
            expectedOutput: /*language=dart*/ '''
                import 'dart:html';
                
                import 'package:react_material_ui/react_material_ui.dart' as mui;
                
                content() => mui.Button();
            ''',
          );
        });
      });

      test('when there is just a library declaration', () async {
        await testSuggestor(
          input: /*language=dart*/ '''
              library lib;
          
              content() => mui.Button();
          ''',
          isExpectedError: (e) => isUndefinedMuiError(e) || isFakeUriError(e),
          expectedOutput: /*language=dart*/ '''
              library lib;
          
              import 'package:react_material_ui/react_material_ui.dart' as mui;
              
              content() => mui.Button();
          ''',
        );
      });

      test('when there are only parts', () async {
        await testSuggestor(
          input: /*language=dart*/ '''
              part 'fake_part.dart';
          
              content() => mui.Button();
          ''',
          isExpectedError: (e) => isUndefinedMuiError(e) || isFakeUriError(e),
          expectedOutput: /*language=dart*/ '''
              import 'package:react_material_ui/react_material_ui.dart' as mui;
              
              part 'fake_part.dart';
              
              content() => mui.Button();
          ''',
        );
      });

      test('when there are only exports', () async {
        await testSuggestor(
          input: /*language=dart*/ '''
              export 'package:over_react/over_react.dart';
          
              content() => mui.Button();
          ''',
          isExpectedError: isUndefinedMuiError,
          expectedOutput: /*language=dart*/ '''
              import 'package:react_material_ui/react_material_ui.dart' as mui;
              
              export 'package:over_react/over_react.dart';
              
              content() => mui.Button();
          ''',
        );
      });

      test('when there are imports and parts', () async {
        await testSuggestor(
          input: /*language=dart*/ '''
              import 'package:over_react/over_react.dart';
              
              part 'fake_part.dart';
          
              content() => mui.Button();
          ''',
          isExpectedError: (e) => isUndefinedMuiError(e) || isFakeUriError(e),
          expectedOutput: /*language=dart*/ '''
              import 'package:over_react/over_react.dart';
              import 'package:react_material_ui/react_material_ui.dart' as mui;
              
              part 'fake_part.dart';
              
              content() => mui.Button();
          ''',
        );
      });

      test('when there are exports and parts', () async {
        await testSuggestor(
          input: /*language=dart*/ '''
              export 'package:over_react/over_react.dart';
              
              part 'fake_part.dart';
          
              content() => mui.Button();
          ''',
          isExpectedError: (e) => isUndefinedMuiError(e) || isFakeUriError(e),
          expectedOutput: /*language=dart*/ '''
              import 'package:react_material_ui/react_material_ui.dart' as mui;
              
              export 'package:over_react/over_react.dart';
              
              part 'fake_part.dart';
              
              content() => mui.Button();
          ''',
        );
      });

      test('when there are imports, exports, and parts', () async {
        await testSuggestor(
          input: /*language=dart*/ '''
              import 'package:over_react/over_react.dart';
          
              export 'package:over_react/over_react.dart';
              
              part 'fake_part.dart';
          
              content() => mui.Button();
          ''',
          isExpectedError: (e) => isUndefinedMuiError(e) || isFakeUriError(e),
          expectedOutput: /*language=dart*/ '''
              import 'package:over_react/over_react.dart';
              import 'package:react_material_ui/react_material_ui.dart' as mui;
          
              export 'package:over_react/over_react.dart';
              
              part 'fake_part.dart';
              
              content() => mui.Button();
          ''',
        );
      });
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

      test('for a different package name', () async {
        final testSuggestor = getSuggestorTester(
          importerSuggestorBuilder(
              importUri: 'package:over_react/over_react.dart',
              importNamespace: 'or'),
          resolvedContext: resolvedContext,
        );
        await testSuggestor(
          input: /*language=dart*/ '''
            
                content() => or.Fragment();
            ''',
          isExpectedError: (error) =>
              error.message.contains("Undefined name 'or'"),
          expectedOutput: /*language=dart*/ '''
                import 'package:over_react/over_react.dart' as or;
                
                content() => or.Fragment();
            ''',
        );
      });
    });
  });
}

bool isUndefinedMuiError(AnalysisError error) =>
    error.message.contains("Undefined name 'mui'");

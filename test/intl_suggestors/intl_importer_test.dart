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
import 'package:over_react_codemod/src/intl_suggestors/intl_importer.dart';
import 'package:test/test.dart';

import '../resolved_file_context.dart';
import '../util.dart';

void main() {
  group('intlImporter', () {
    final resolvedContext = SharedAnalysisContext.overReact;

    // Warm up analysis in a setUpAll so that if getting the resolved AST times out
    // (which is more common for the WSD context), it fails here instead of failing the first test.
    setUpAll(resolvedContext.warmUpAnalysis);

    // Don't forget that testSuggestor tests idempotency by default, which is
    // especially important for this suggestor.
    final testSuggestor = getSuggestorTester(
      (context) => intlImporter(context),
      resolvedContext: resolvedContext,
    );

    group(
        'adds a `intl` import when there is an undefined `intl` identifier in the file',
        () {
      bool isFakeUriError(AnalysisError error) =>
          error.errorCode.name.toLowerCase() == 'uri_does_not_exist' &&
          error.message.contains('fake');

      test('when there are no other imports', () async {
        await testSuggestor(
          input: /*language=dart*/ '''
              content() => Intl.message('foo');
          ''',
          isExpectedError: isUndefinedIntlError,
          expectedOutput: /*language=dart*/ '''
              import 'package:intl/intl.dart';
              content() => Intl.message('foo');
          ''',
        );
      });

      group('when there are other imports', () {
        test('(alphabetized before `intl`)', () async {
          await testSuggestor(
            input: /*language=dart*/ '''
              import 'package:over_react/over_react.dart';
              content() => Intl.message('foo');
            ''',
            isExpectedError: isUndefinedIntlError,
            expectedOutput: /*language=dart*/ '''
              import 'package:intl/intl.dart';
              import 'package:over_react/over_react.dart';
              
              content() => Intl.message('foo');
            ''',
          );
        });

        test('(alphabetized after intl)', () async {
          await testSuggestor(
            input: /*language=dart*/ '''
              import 'package:z_fake_package/z_fake_package.dart';

              content() => Intl.message('foo');
            ''',
            isExpectedError: (e) => isUndefinedIntlError(e) || isFakeUriError(e),
            expectedOutput: /*language=dart*/ '''
              import 'package:intl/intl.dart';
              import 'package:z_fake_package/z_fake_package.dart';

              content() => Intl.message('foo');
            ''',
          );
        });

        test('(one alphabetized before and after `intl`)', () async {
          await testSuggestor(
            input: /*language=dart*/ '''
                import 'package:a_fake_package/a_fake_package.dart';
                import 'package:z_fake_package/z_fake_package.dart';

              content() => Intl.message('foo');
            ''',
            isExpectedError: (e) => isUndefinedIntlError(e) || isFakeUriError(e),
            expectedOutput: /*language=dart*/ '''
              import 'package:a_fake_package/a_fake_package.dart';
              import 'package:intl/intl.dart';
              import 'package:z_fake_package/z_fake_package.dart';

              content() => Intl.message('foo');
            ''',
          );
        });

        test('(more than one alphabetized before and after `intl`)', () async {
          await testSuggestor(
            input: /*language=dart*/ '''
                import 'package:a_fake_package/a_fake_package_1.dart';
                import 'package:a_fake_package/a_fake_package_2.dart';
                import 'package:z_fake_package/z_fake_package_1.dart';
                import 'package:z_fake_package/z_fake_package_2.dart';

              content() => Intl.message('foo');
            ''',
            isExpectedError: (e) => isUndefinedIntlError(e) || isFakeUriError(e),
            expectedOutput: /*language=dart*/ '''
              import 'package:a_fake_package/a_fake_package_1.dart';
              import 'package:a_fake_package/a_fake_package_2.dart';
              import 'package:intl/intl.dart';
              import 'package:z_fake_package/z_fake_package_1.dart';
              import 'package:z_fake_package/z_fake_package_2.dart';

              content() => Intl.message('foo');
            ''',
          );
        });

        test('(a relative import, alphabetized before `intl`)', () async {
          await testSuggestor(
            input: /*language=dart*/ '''
              import 'package:over_react/over_react.dart';

              import 'a/fake_relative_file.dart';

              content() => Intl.message('foo');
            ''',
            isExpectedError: (e) => isUndefinedIntlError(e) || isFakeUriError(e),
            expectedOutput: /*language=dart*/ '''
              import 'package:intl/intl.dart';
              import 'package:over_react/over_react.dart';

              import 'a/fake_relative_file.dart';

              content() => Intl.message('foo');
            ''',
          );
        });

        test('(a dart import)', () async {
          await testSuggestor(
            input: /*language=dart*/ '''
              import 'dart:html';

              content() => Intl.message('foo');
            ''',
            isExpectedError: (e) => isUndefinedIntlError(e) || isFakeUriError(e),
            expectedOutput: /*language=dart*/ '''
              import 'dart:html';

              import 'package:intl/intl.dart';

              content() => Intl.message('foo');
            ''',
          );
        });
      });

      test('when there is just a library declaration', () async {
        await testSuggestor(
          input: /*language=dart*/ '''
              library lib;

              content() => Intl.message('foo');
          ''',
          isExpectedError: (e) => isUndefinedIntlError(e) || isFakeUriError(e),
          expectedOutput: /*language=dart*/ '''
              library lib;

              import 'package:intl/intl.dart';

              content() => Intl.message('foo');
          ''',
        );
      });

      test('when there are only parts', () async {
        await testSuggestor(
          input: /*language=dart*/ '''
              part 'fake_part.dart';

              content() => Intl.message('foo');
          ''',
          isExpectedError: (e) => isUndefinedIntlError(e) || isFakeUriError(e),
          expectedOutput: /*language=dart*/ '''
              import 'package:intl/intl.dart';

              part 'fake_part.dart';

              content() => Intl.message('foo');
          ''',
        );
      });

      test('when there are only exports', () async {
        await testSuggestor(
          input: /*language=dart*/ '''
              export 'package:over_react/over_react.dart';

              content() => Intl.message('foo');
          ''',
          isExpectedError: isUndefinedIntlError,
          expectedOutput: /*language=dart*/ '''
              import 'package:intl/intl.dart';

              export 'package:over_react/over_react.dart';

              content() => Intl.message('foo');
          ''',
        );
      });

      test('when there are imports and parts', () async {
        await testSuggestor(
          input: /*language=dart*/ '''
              import 'package:over_react/over_react.dart';

              part 'fake_part.dart';

              content() => Intl.message('foo');
          ''',
          isExpectedError: (e) => isUndefinedIntlError(e) || isFakeUriError(e),
          expectedOutput: /*language=dart*/ '''
              import 'package:intl/intl.dart';
              import 'package:over_react/over_react.dart';

              part 'fake_part.dart';

              content() => Intl.message('foo');
          ''',
        );
      });

      test('when there are exports and parts', () async {
        await testSuggestor(
          input: /*language=dart*/ '''
              export 'package:over_react/over_react.dart';

              part 'fake_part.dart';

              content() => Intl.message('foo');
          ''',
          isExpectedError: (e) => isUndefinedIntlError(e) || isFakeUriError(e),
          expectedOutput: /*language=dart*/ '''
              import 'package:intl/intl.dart';

              export 'package:over_react/over_react.dart';

              part 'fake_part.dart';

              content() => Intl.message('foo');
          ''',
        );
      });

      test('when there are imports, exports, and parts', () async {
        await testSuggestor(
          input: /*language=dart*/ '''
              import 'package:over_react/over_react.dart';

              export 'package:over_react/over_react.dart';

              part 'fake_part.dart';

              content() => Intl.message('foo');
          ''',
          isExpectedError: (e) => isUndefinedIntlError(e) || isFakeUriError(e),
          expectedOutput: /*language=dart*/ '''
              import 'package:intl/intl.dart';
              import 'package:over_react/over_react.dart';

              export 'package:over_react/over_react.dart';

              part 'fake_part.dart';

              content() => Intl.message('foo');
          ''',
        );
      });
    });

    test(
        'adds a `intl` import when there is an undefined `intl` identifier in a part file',
        () async {
      // testSuggestor isn't really set up for multiple files,
      // so the test setup here is a little more manual.

      const partFilename = 'intl_importer_test_part.dart';
      const mainLibraryFilename = 'intl_importer_test_main_library.dart';

      final partFileContext =
          await resolvedContext.resolvedFileContextForTest('''
            part of '${mainLibraryFilename}';

            content() => Intl.testString;
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
        isExpectedError: isUndefinedIntlError,
      );

      final mainPatches = await intlImporter(mainLibraryFileContext).toList();
      expect(mainPatches, [
        hasPatchText(contains(
            "import 'package:intl/intl.dart';")),
      ]);

      final partPatches = await intlImporter(partFileContext).toList();
      expect(partPatches, isEmpty);
    });

    group('does not add an `intl` import when', () {
      test('a `Intl` identifier in the file is not undefined', () async {
        await testSuggestor(
          input: /*language=dart*/ '''
              dynamic Intl;
              content() => Intl.testString;
          ''',
        );
      });
      test('there is no `intl` identifier in the file', () async {
        await testSuggestor(
          input: /*language=dart*/ '''
              content() {}
          ''',
        );
      });
    });
  });
}

bool isUndefinedIntlError(AnalysisError error) =>
    error.message.contains("Undefined name 'Intl'");

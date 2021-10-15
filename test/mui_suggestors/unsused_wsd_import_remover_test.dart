import 'package:over_react_codemod/src/mui_suggestors/unused_wsd_import_remover.dart';
import 'package:test/test.dart';

import '../resolved_file_context.dart';
import '../util.dart';

void main() {
  final resolvedContext = SharedAnalysisContext.wsd;

  // Warm up analysis in a setUpAll so that if getting the resolved AST times out
  // (which is more common for the WSD context), it fails here instead of failing the first test.
  setUpAll(resolvedContext.warmUpAnalysis);

  group('unusedWsdImportRemover', () {
    final testSuggestor = getSuggestorTester(
      unusedWsdImportRemover,
      resolvedContext: resolvedContext,
    );

    test('does nothing when there are no imports', () async {
      await testSuggestor(input: '');
    });

    test('does nothing for unused non-WSD imports', () async {
      await testSuggestor(
        input: /*language=dart*/ '''
            import 'package:over_react/over_react.dart';
        ''',
      );
    });

    group('removes unused WSD imports in a file', () {
      test('when there are imports before it', () async {
        await testSuggestor(
          input: /*language=dart*/ '''
              import 'package:over_react/over_react.dart';
              import 'package:web_skin_dart/ui_components.dart';
          
              content() => Dom.div()();
          ''',
          expectedOutput: /*language=dart*/ '''
              import 'package:over_react/over_react.dart';
          
              content() => Dom.div()();
          ''',
        );
      });

      test('when it is the first import and token', () async {
        await testSuggestor(
          input: /*language=dart*/ '''
              import 'package:web_skin_dart/ui_components.dart';
              import 'package:over_react/over_react.dart';
          
              content() => Dom.div()();
          ''',
          expectedOutput: /*language=dart*/ '''
              import 'package:over_react/over_react.dart';
          
              content() => Dom.div()();
          ''',
        );
      });

      test('when it is the first import', () async {
        await testSuggestor(
          input: /*language=dart*/ '''
              library lib;
          
              import 'package:web_skin_dart/ui_components.dart';
              import 'package:over_react/over_react.dart';
          
              content() => Dom.div()();
          ''',
          expectedOutput: /*language=dart*/ '''
              library lib;
              
              import 'package:over_react/over_react.dart';
          
              content() => Dom.div()();
          ''',
        );
      });

      test('unless they are in use', () async {
        await testSuggestor(
          input: /*language=dart*/ '''
              import 'package:over_react/over_react.dart';
              import 'package:web_skin_dart/ui_components.dart';
          
              content() => Button()();
          ''',
        );
      });

      test('when only some are unused', () async {
        await testSuggestor(
          input: /*language=dart*/ '''
              import 'package:over_react/over_react.dart';
              import 'package:web_skin_dart/ui_components.dart';
              import 'package:web_skin_dart/component2/all.dart' as wsd2;
          
              content() => wsd2.Button()();
          ''',
          expectedOutput: /*language=dart*/ '''
              import 'package:over_react/over_react.dart';
              import 'package:web_skin_dart/component2/all.dart' as wsd2;
          
              content() => wsd2.Button()();
          ''',
        );
      });
    });
  });
}

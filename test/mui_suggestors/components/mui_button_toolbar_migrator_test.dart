import 'package:over_react_codemod/src/mui_suggestors/components/mui_button_toolbar_migrator.dart';
import 'package:test/test.dart';

import '../../resolved_file_context.dart';
import '../../util.dart';
import 'shared.dart';

void main() {
  final resolvedContext = SharedAnalysisContext.wsd;

  // Warm up analysis in a setUpAll so that if it times out, the root cause is
  // more obvious than the first test timing out.
  setUpAll(resolvedContext.warmUpAnalysis);

  group('MuiButtonToolbarMigrator', () {
    final testSuggestor = getSuggestorTester(
      MuiButtonToolbarMigrator(),
      resolvedContext: resolvedContext,
    );

    group('migrates WSD ButtonToolbars', () {
      test('that are either unnamespaced or namespaced, and either v1 or v2',
          () async {
        await testSuggestor(
          input: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                ButtonToolbar()();
                wsd_v1.ButtonToolbar()();
                wsd_v2.ButtonToolbar()();
              }
          '''),
          expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                mui.ButtonToolbar()();
                mui.ButtonToolbar()();
                mui.ButtonToolbar()();
              }
          '''),
        );
      });

      test('and not non-WSD ButtonToolbars or other components', () async {
        await testSuggestor(
          input: withOverReactAndWsdImports(/*language=dart*/ '''
              // Shadows the WSD ButtonToolbar
              UiFactory ButtonToolbar;
              content() {
                // Non-WSD ButtonToolbar
                ButtonToolbar()();
                
                Tooltip()();
                Dom.div()();
              }
          '''),
        );
      });
    });

    test('updates the factory', () async {
      await testSuggestor(
        input: withOverReactAndWsdImports(/*language=dart*/ '''
            content() {
              ButtonToolbar()();
            }
        '''),
        expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
            content() {
              mui.ButtonToolbar()();
            }
        '''),
      );
    });
  }, tags: 'wsd');
}

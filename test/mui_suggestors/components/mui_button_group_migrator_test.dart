import 'package:over_react_codemod/src/mui_suggestors/components/mui_button_group_migrator.dart';
import 'package:test/test.dart';

import '../../resolved_file_context.dart';
import '../../util.dart';

void main() {
  group('MuiButtonGroupMigrator', () {
    final testSuggestor = getSuggestorTester(
      MuiButtonGroupMigrator(),
      resolvedContext: SharedAnalysisContext.wsd,
    );

    group('migrates WSD ButtonGroups', () {
      test('that are either unnamespaced or namespaced, and either v1 or v2',
          () async {
        await testSuggestor(
          input: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                ButtonGroup()();
                wsd_v1.ButtonGroup()();
                wsd_v2.ButtonGroup()();
              }
          '''),
          expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                mui.ButtonGroup()();
                mui.ButtonGroup()();
                mui.ButtonGroup()();
              }
          '''),
        );
      });

      test('and not non-WSD ButtonGroups or other components', () async {
        await testSuggestor(
          input: withOverReactAndWsdImports(/*language=dart*/ '''
              // Shadows the WSD ButtonGroup
              UiFactory ButtonGroup;
              content() {
                // Non-WSD ButtonGroup
                ButtonGroup()();
                
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
              ButtonGroup()();
            }
        '''),
        expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
            content() {
              mui.ButtonGroup()();
            }
        '''),
      );
    });

    group('updates props', () {
      test('isJustified', () async {
        await testSuggestor(
          input: withOverReactAndWsdImports(/*language=dart*/ '''
              content(bool value) {
                (ButtonGroup()..isJustified = value)();
              }
          '''),
          expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
              content(bool value) {
                (mui.ButtonGroup()..fullWidth = value)();
              }
          '''),
        );
      });

      group('isVertical, when the RHS is a', () {
        test('boolean literal', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (ButtonGroup()..isVertical = true)();
                  (ButtonGroup()..isVertical = false)();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (mui.ButtonGroup()..orientation = mui.ButtonGroupOrientation.vertical)();
                  (mui.ButtonGroup()..orientation = mui.ButtonGroupOrientation.horizontal)();
                }
            '''),
          );
        });

        test('other expression', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
                content(bool value) {
                  (ButtonGroup()..isVertical = value)();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
                content(bool value) {
                  (mui.ButtonGroup()
                    ..orientation = value 
                        ? mui.ButtonGroupOrientation.vertical 
                        : mui.ButtonGroupOrientation.horizontal
                  )();
                }
            '''),
          );
        });
      });

      group('size', () {
        test('mapping size constants properly', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (ButtonGroup()..size = ButtonGroupSize.XXSMALL)();
                  (ButtonGroup()..size = ButtonGroupSize.XSMALL)();
                  (ButtonGroup()..size = ButtonGroupSize.SMALL)();
                  (ButtonGroup()..size = ButtonGroupSize.DEFAULT)();
                  (ButtonGroup()..size = ButtonGroupSize.LARGE)();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (mui.ButtonGroup()..size = mui.ButtonSize.xxsmall)();
                  (mui.ButtonGroup()..size = mui.ButtonSize.xsmall)();
                  (mui.ButtonGroup()..size = mui.ButtonSize.small)();
                  (mui.ButtonGroup()..size = mui.ButtonSize.medium)();
                  (mui.ButtonGroup()..size = mui.ButtonSize.large)();
                }
            '''),
          );
        });

        test('flagging when the size is another expression', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
                content(dynamic otherSize) {
                  (ButtonGroup()..size = otherSize)();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
                content(dynamic otherSize) {
                  (mui.ButtonGroup()
                    // FIXME(mui_migration) - size prop - manually migrate
                    ..size = otherSize
                  )();
                }
            '''),
          );
        });
      });
    });
  });
}

// TODO move to shared file
String withOverReactAndWsdImports(String source) {
  return '''
    import 'package:over_react/over_react.dart';
    import 'package:web_skin_dart/component2/all.dart';
    import 'package:web_skin_dart/component2/all.dart' as wsd_v2;
    import 'package:web_skin_dart/ui_components.dart' as wsd_v1;
    
    $source
  ''';
}

import 'package:over_react_codemod/src/mui_suggestors/components/mui_button_migrator.dart';
import 'package:test/test.dart';

import '../../resolved_file_context.dart';
import '../../util.dart';
import 'shared.dart';

void main() {
  group('MuiButtonMigrator', () {
    final testSuggestor = getSuggestorTester(
      MuiButtonMigrator(),
      resolvedContext: SharedAnalysisContext.wsd,
    );

    group('migrates WSD Buttons', () {
      test('that are either unnamespaced or namespaced, and either v1 or v2',
          () async {
        await testSuggestor(
          input: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                Button()();
                wsd_v1.Button()();
                wsd_v2.Button()();
              }
          '''),
          expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                mui.Button()();
                mui.Button()();
                mui.Button()();
              }
          '''),
        );
      });

      test('and not non-WSD Buttons or other components', () async {
        await testSuggestor(
          input: withOverReactAndWsdImports(/*language=dart*/ '''
              // Shadows the WSD Button
              UiFactory Button;
              content() {
                // Non-WSD Button
                Button()();
                
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
              Button()();
            }
        '''),
        expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
            content() {
              mui.Button()();
            }
        '''),
      );
    });

    group('updates props', () {
      test('isActive', () async {
        await testSuggestor(
          input: withOverReactAndWsdImports(/*language=dart*/ '''
              content(bool value) {
                (Button()..isActive = value)();
              }
          '''),
          expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
              content(bool value) {
                (mui.Button()..aria.pressed = value)();
              }
          '''),
        );
      });

      test('isBlock', () async {
        await testSuggestor(
          input: withOverReactAndWsdImports(/*language=dart*/ '''
              content(bool value) {
                (Button()..isBlock = value)();
              }
          '''),
          expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
              content(bool value) {
                (mui.Button()..fullWidth = value)();
              }
          '''),
        );
      });

      test('isFlat', () async {
        await testSuggestor(
          input: withOverReactAndWsdImports(/*language=dart*/ '''
              content(bool value) {
                (Button()..isFlat = value)();
              }
          '''),
          expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
              content(bool value) {
                (mui.Button()..disableElevation = value)();
              }
          '''),
        );
      });

      group('skin', () {
        test(
            'mapping link skin constants properly and changing the factory to LinkButton',
            () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (Button()..skin = ButtonSkin.LINK)();
                  (Button()..skin = ButtonSkin.OUTLINE_LINK)();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (mui.LinkButton())();
                  (mui.LinkButton()..variant = mui.ButtonVariant.outlined)();
                }
            '''),
          );
        });

        test('mapping skin constants properly', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (Button()..skin = ButtonSkin.DANGER)();
                  (Button()..skin = ButtonSkin.ALTERNATE)();
                  (Button()..skin = ButtonSkin.LIGHT)();
                  (Button()..skin = ButtonSkin.WHITE)();
                  (Button()..skin = ButtonSkin.INVERSE)();
                  (Button()..skin = ButtonSkin.DEFAULT)();
                  (Button()..skin = ButtonSkin.PRIMARY)();
                  (Button()..skin = ButtonSkin.SUCCESS)();
                  (Button()..skin = ButtonSkin.WARNING)();
                  
                  (Button()..skin = ButtonSkin.VANILLA)();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (mui.Button()..color = mui.ButtonColor.error)();
                  (mui.Button()..color = mui.ButtonColor.secondary)();
                  (mui.Button()..color = mui.ButtonColor.wsdBtnLight)();
                  (mui.Button()..color = mui.ButtonColor.wsdBtnWhite)();
                  (mui.Button()..color = mui.ButtonColor.wsdBtnInverse)();
                  (mui.Button()..color = mui.ButtonColor.inherit)();
                  (mui.Button()..color = mui.ButtonColor.primary)();
                  (mui.Button()..color = mui.ButtonColor.success)();
                  (mui.Button()..color = mui.ButtonColor.warning)();
                  
                  (mui.Button()
                    ..color = mui.ButtonColor.inherit
                    ..variant = mui.ButtonVariant.text
                  )();
                }
            '''),
          );
        });

        test('mapping outline skin constants properly', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (Button()..skin = ButtonSkin.OUTLINE_DEFAULT)();
                  
                  (Button()..skin = ButtonSkin.OUTLINE_DANGER)();
                  (Button()..skin = ButtonSkin.OUTLINE_ALTERNATE)();
                  (Button()..skin = ButtonSkin.OUTLINE_PRIMARY)();
                  (Button()..skin = ButtonSkin.OUTLINE_SUCCESS)();
                  (Button()..skin = ButtonSkin.OUTLINE_WARNING)();
                }
            '''),
            // Formatting is a little wonky here so it doesn't take up as many lines.
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (mui.Button()..variant = mui.ButtonVariant.outlined)();
                  
                  (mui.Button()  ..color = mui.ButtonColor.error  ..variant = mui.ButtonVariant.outlined  )();
                  (mui.Button()  ..color = mui.ButtonColor.secondary  ..variant = mui.ButtonVariant.outlined  )();
                  (mui.Button()  ..color = mui.ButtonColor.primary  ..variant = mui.ButtonVariant.outlined  )();
                  (mui.Button()  ..color = mui.ButtonColor.success  ..variant = mui.ButtonVariant.outlined  )();
                  (mui.Button()  ..color = mui.ButtonColor.warning  ..variant = mui.ButtonVariant.outlined  )();
                }
            '''),
          );
        });

        test('flagging when the skin is another expression', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
                content(dynamic otherSkin) {
                  (Button()..skin = otherSkin)();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
                content(dynamic otherSkin) {
                  (mui.Button()
                    // FIXME(mui_migration) - skin prop - manually migrate
                    ..skin = otherSkin
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
                  (Button()..size = ButtonSize.XXSMALL)();
                  (Button()..size = ButtonSize.XSMALL)();
                  (Button()..size = ButtonSize.SMALL)();
                  (Button()..size = ButtonSize.DEFAULT)();
                  (Button()..size = ButtonSize.LARGE)();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (mui.Button()..size = mui.ButtonSize.xxsmall)();
                  (mui.Button()..size = mui.ButtonSize.xsmall)();
                  (mui.Button()..size = mui.ButtonSize.small)();
                  (mui.Button()..size = mui.ButtonSize.medium)();
                  (mui.Button()..size = mui.ButtonSize.large)();
                }
            '''),
          );
        });

        test('flagging when the size is another expression', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
                content(dynamic otherSize) {
                  (Button()..size = otherSize)();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
                content(dynamic otherSize) {
                  (mui.Button()
                    // FIXME(mui_migration) - size prop - manually migrate
                    ..size = otherSize
                  )();
                }
            '''),
          );
        });
      });

      test('isCallout', () async {
        await testSuggestor(
          input: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                (Button()..isCallout = true)();
              }
          '''),
          expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                (mui.Button()
                  // FIXME(mui_migration) - isCallout prop - manually migrate
                  ..isCallout = true
                )();
              }
          '''),
        );
      });

      test('pullRight', () async {
        await testSuggestor(
          input: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                (Button()..pullRight = true)();
              }
          '''),
          expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                (mui.Button()
                  // FIXME(mui_migration) - pullRight prop - manually migrate
                  ..pullRight = true
                )();
              }
          '''),
        );
      });

      test('role', () async {
        await testSuggestor(
          input: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                (Button()..role = 'foo')();
              }
          '''),
          expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                (mui.Button()..dom.role = 'foo')();
              }
          '''),
        );
      });

      test('target', () async {
        await testSuggestor(
          input: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                (Button()..target = 'foo')();
              }
          '''),
          expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                (mui.Button()..dom.target = 'foo')();
              }
          '''),
        );
      });

      test('overlayTriggerProps', () async {
        await testSuggestor(
          input: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                (Button()..overlayTriggerProps = {})();
              }
          '''),
          expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                (mui.Button()
                  // FIXME(mui_migration) - overlayTriggerProps prop - manually migrate
                  ..overlayTriggerProps = {}
                )();
              }
          '''),
        );
      });

      test('tooltipContent', () async {
        await testSuggestor(
          input: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                (Button()..tooltipContent = '')();
              }
          '''),
          expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                (mui.Button()
                  // FIXME(mui_migration) - tooltipContent prop - manually migrate
                  ..tooltipContent = ''
                )();
              }
          '''),
        );
      });
    });
  });
}

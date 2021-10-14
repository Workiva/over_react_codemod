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

    test(
        'does not migrate non-WSD Button/FormSubmitInput/FormResetInput factories,'
        ' toolbar factories, or other components', () async {
      await testSuggestor(
        input: withOverReactAndWsdImports(/*language=dart*/ '''
            // Shadows the WSD factories
            UiFactory Button;
            UiFactory FormSubmitInput;
            UiFactory FormResetInput;
            
            content() {
              // Non-WSD (shadowed)
              Button()();
              FormSubmitInput()();
              FormResetInput()();
              
              // Toolbars
              // (There are no toolbars versions of FormSubmitInput/FormResetInput)
              toolbars_v1.Button()();
              toolbars_v2.Button()();
              
              // Other components
              Tooltip()();
              Dom.div()();
            }
        '''),
      );
    });

    group('updates the factory', () {
      test('for Button (potentially namespaced or v1/v2)', () async {
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

      group(
          'for FormResetInput (potentially namespaced or v1/v2),'
          ' also adding relevant props', () {
        test('when there are no props', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  FormResetInput()();
                  wsd_v1.FormResetInput()();
                  wsd_v2.FormResetInput()();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (mui.Button()..type = 'reset')();
                  (mui.Button()..type = 'reset')();
                  (mui.Button()..type = 'reset')();
                }
            '''),
          );
        });

        test('when there are existing cascades', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (FormResetInput()
                    // `type` should go after all existing cascades
                    ..id = 'id'
                  )();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (mui.Button()
                    // `type` should go after all existing cascades
                    ..id = 'id'
                    ..type = 'reset'
                  )();
                }
            '''),
          );
        });
      });

      group(
          'for FormSubmit (potentially namespaced or v1/v2),'
          ' also adding relevant props', () {
        test('when there are no parens around the builder', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  FormSubmitInput()();
                  wsd_v1.FormSubmitInput()();
                  wsd_v2.FormSubmitInput()();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (mui.Button()
                    ..color = mui.ButtonColor.primary
                    ..type = 'submit'
                  )();
                  (mui.Button()
                    ..color = mui.ButtonColor.primary
                    ..type = 'submit'
                  )();
                  (mui.Button()
                    ..color = mui.ButtonColor.primary
                    ..type = 'submit'
                  )();
                }
            '''),
          );
        });

        test('when there are parens around the builder', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (FormSubmitInput())();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (mui.Button()
                    ..color = mui.ButtonColor.primary
                    ..type = 'submit'
                  )();
                }
            '''),
          );
        });

        test('when there are cascades on the builder', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (FormSubmitInput()
                    // `color` should go before existing cascades, and `type` afterwards
                    ..id = 'id'
                  )();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
                content() {
                  (mui.Button()
                    ..color = mui.ButtonColor.primary
                    // `color` should go before existing cascades, and `type` afterwards
                    ..id = 'id'
                    ..type = 'submit'
                  )();
                }
            '''),
          );
        });
      });
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

      group('always flagging for manual migration:', () {
        void sharedTest(String propName, {required String rhs}) async {
          test(propName, () async {
            await testSuggestor(
              input: withOverReactAndWsdImports('''
                  content() {
                    (Button()..$propName = $rhs)();
                  }
              '''),
              expectedOutput: withOverReactAndWsdImports('''
                  content() {
                    (mui.Button()
                      // FIXME(mui_migration) - $propName prop - manually migrate
                      ..$propName = $rhs
                    )();
                  }
              '''),
            );
          });
        }

        sharedTest('isCallout', rhs: 'true');
        sharedTest('pullRight', rhs: 'true');
        sharedTest('overlayTriggerProps', rhs: '{}');
        sharedTest('tooltipContent', rhs: '""');
      });
    });
  });
}

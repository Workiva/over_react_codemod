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

    group('handles icon children', () {
      test('flagging when there is an ambiguous child', () async {
        await testSuggestor(
          input: withOverReactAndWsdImports(/*language=dart*/ '''
              mixin FooProps on UiProps {}
          
              content(
                dynamic dynamicChild,
                Object arbitraryObjectChild,
                UiProps untypedBuilder,
                FooProps typedBuilder,
                UiFactory untypedLocalFactory,
                UiFactory<FooProps> typedLocalFactory,
              ) {
                Button()('dynamicChild', dynamicChild);
                Button()('arbitraryObjectChild', arbitraryObjectChild);
                Button()([
                  'collectionElementChild',
                  if (true) 'collectionElementChild',
                ]);
                Button()('untypedBuilder', untypedBuilder());
                Button()('typedBuilder', typedBuilder());
                Button()('untypedLocalFactory', untypedLocalFactory()());
                Button()('typedLocalFactory', typedLocalFactory()());
                Button()(['nonVariadic', dynamicChild]);
                Button()(dynamicChild, 'dynamicChildAsStart');
              }
          '''),
          expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
              mixin FooProps on UiProps {}
          
              content(
                dynamic dynamicChild,
                Object arbitraryObjectChild,
                UiProps untypedBuilder,
                FooProps typedBuilder,
                UiFactory untypedLocalFactory,
                UiFactory<FooProps> typedLocalFactory,
              ) {
                mui.Button()('dynamicChild',
                    // FIXME(mui_migration) - Button child - manually verify that this child is not an icon that should be moved to `endIcon` 
                    dynamicChild);
                mui.Button()('arbitraryObjectChild',
                    // FIXME(mui_migration) - Button child - manually verify that this child is not an icon that should be moved to `endIcon` 
                    arbitraryObjectChild);
                mui.Button()([
                  'collectionElementChild',
                  // FIXME(mui_migration) - Button child - manually verify that this child is not an icon that should be moved to `endIcon`
                  if (true) 'collectionElementChild',
                ]);
                mui.Button()('untypedBuilder',
                    // FIXME(mui_migration) - Button child - manually verify that this child is not an icon that should be moved to `endIcon` 
                    untypedBuilder());
                mui.Button()('typedBuilder',
                    // FIXME(mui_migration) - Button child - manually verify that this child is not an icon that should be moved to `endIcon` 
                    typedBuilder());
                mui.Button()('untypedLocalFactory',
                    // FIXME(mui_migration) - Button child - manually verify that this child is not an icon that should be moved to `endIcon` 
                    untypedLocalFactory()());
                mui.Button()('typedLocalFactory',
                    // FIXME(mui_migration) - Button child - manually verify that this child is not an icon that should be moved to `endIcon` 
                    typedLocalFactory()());
                mui.Button()(['nonVariadic',
                    // FIXME(mui_migration) - Button child - manually verify that this child is not an icon that should be moved to `endIcon` 
                    dynamicChild]);
                mui.Button()(
                    // FIXME(mui_migration) - Button child - manually verify that this child is not an icon that should be moved to `startIcon`
                    dynamicChild, 'dynamicChildAsStart');
              }
          '''),
        );
      });

      test('not flagging for unambiguous non-Icon children', () async {
        await testSuggestor(
          input: withOverReactAndWsdImports(/*language=dart*/ '''
              UiFactory<FooProps> Foo;
              mixin FooProps on UiProps {}
          
              content() {
                // Primitive children
                Button()('int', 1);
                Button()('double', 1.0);
                Button()('num', 1 as num);
                Button()('string', '');
                Button()('bool', false);
                Button()('null', null);
                
                // Resolved, non-Icon top-level factories
                Button()('otherFactory', Foo()());
                
                // Non-variadic
                Button()(['otherFactory', Foo()()]);
              }
          '''),
          expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
              UiFactory<FooProps> Foo;
              mixin FooProps on UiProps {}
          
              content() {
                // Primitive children
                mui.Button()('int', 1);
                mui.Button()('double', 1.0);
                mui.Button()('num', 1 as num);
                mui.Button()('string', '');
                mui.Button()('bool', false);
                mui.Button()('null', null);
                
                // Resolved, non-Icon top-level factories
                mui.Button()('otherFactory', Foo()());
                
                // Non-variadic
                mui.Button()(['otherFactory', Foo()()]);
              }
          '''),
        );
      });

      test('moving Icons in the first child position to startIcon', () async {
        await testSuggestor(
          input: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                Button()(
                  (Icon()..glyph = IconGlyph.STAR)(),
                  'other child',
                );
                Button()(
                  (Icon()..glyph = IconGlyph.STAR)(),
                  'other child',
                  'one more child',
                );
                // non-variadic
                Button()([
                  (Icon()..glyph = IconGlyph.STAR)(),
                  'other child',
                ]);
              }
          '''),
          expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                (mui.Button()
                  ..startIcon = (Icon()..glyph = IconGlyph.STAR)()
                )(
                  'other child',
                );
                (mui.Button()
                  ..startIcon = (Icon()..glyph = IconGlyph.STAR)()
                )(
                  'other child',
                  'one more child',
                );
                // non-variadic
                (mui.Button()
                  ..startIcon = (Icon()..glyph = IconGlyph.STAR)()
                )([
                  'other child',
                ]);
              }
          '''),
        );
      });

      test('moving Icons in the last child position to endIcon', () async {
        await testSuggestor(
          input: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                Button()(
                  'other child',
                  (Icon()..glyph = IconGlyph.STAR)(),
                );
                // non-variadic
                Button()([
                  'other child',
                  (Icon()..glyph = IconGlyph.STAR)(),
                ]);
              }
          '''),
          expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                (mui.Button()
                  ..endIcon = (Icon()..glyph = IconGlyph.STAR)()
                )(
                  'other child',
                );
                // non-variadic
                (mui.Button()
                  ..endIcon = (Icon()..glyph = IconGlyph.STAR)()
                )([
                  'other child',
                ]);
              }
          '''),
        );
      });

      test('not moving Icons that are not the first or last child', () async {
        await testSuggestor(
          input: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                Button()(
                  'other child',
                  (Icon()..glyph = IconGlyph.STAR)(),
                  'one more child',
                );
                // non-variadic
                Button()([
                  'other child',
                  (Icon()..glyph = IconGlyph.STAR)(),
                  'one more child',
                ]);
              }
          '''),
          expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                mui.Button()(
                  'other child',
                  (Icon()..glyph = IconGlyph.STAR)(),
                  'one more child',
                );
                // non-variadic
                mui.Button()([
                  'other child',
                  (Icon()..glyph = IconGlyph.STAR)(),
                  'one more child',
                ]);
              }
          '''),
        );
      });

      test('not moving Icons that are the single child', () async {
        await testSuggestor(
          input: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                Button()(
                  (Icon()..glyph = IconGlyph.STAR)(),
                );
                // non-variadic
                Button()([
                  (Icon()..glyph = IconGlyph.STAR)(),
                ]);
              }
          '''),
          expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
              content() {
                mui.Button()(
                  (Icon()..glyph = IconGlyph.STAR)(),
                );
                // non-variadic
                mui.Button()([
                  (Icon()..glyph = IconGlyph.STAR)(),
                ]);
              }
          '''),
        );
      });

      test('not moving Icons when `noText = true`', () async {
        await testSuggestor(
          input: withOverReactAndWsdImports(/*language=dart*/ '''
              content(bool otherValue) {
                // Should not be moved:
                (Button()..noText = true)(
                  'other child',
                  (Icon()..glyph = IconGlyph.STAR)(),
                );
                
                // Should be moved:
                (Button()..noText = false)(
                  'other child',
                  (Icon()..glyph = IconGlyph.STAR)(),
                );
                (Button()..noText = otherValue)(
                  'other child',
                  (Icon()..glyph = IconGlyph.STAR)(),
                );
              }
          '''),
          expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
              content(bool otherValue) {
                // Should not be moved:
                (mui.Button()..noText = true)(
                  'other child',
                  (Icon()..glyph = IconGlyph.STAR)(),
                );
                
                // Should be moved:
                (mui.Button()
                  ..noText = false
                  ..endIcon = (Icon()..glyph = IconGlyph.STAR)()
                )(
                  'other child',
                );
                (mui.Button()
                  ..noText = otherValue
                  ..endIcon = (Icon()..glyph = IconGlyph.STAR)()
                )(
                  'other child',
                );
              }
          '''),
        );
      });
    });

    test('flags buttons when `DialogFooter` occurs somewhere in the same file',
        () async {
      await testSuggestor(
        input: withOverReactAndWsdImports(/*language=dart*/ '''
            renderFooter() => DialogFooter()();
            content() {   
              Button()();
            }
        '''),
        expectedOutput: withOverReactAndWsdImports(/*language=dart*/ '''
            renderFooter() => DialogFooter()();
            content() {
              // FIXME(mui_migration) check whether this button is nested inside a DialogFooter. If so, wrap it in a mui.ButtonToolbar with `..sx = {'float': 'right'}`.
              mui.Button()();
            }
        '''),
      );
    });
  }, tags: 'wsd');
}

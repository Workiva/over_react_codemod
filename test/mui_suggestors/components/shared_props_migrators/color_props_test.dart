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

import 'package:meta/meta.dart';
import 'package:test/test.dart';

import '../../../util.dart';
import '../shared.dart';

enum ColorPropsMigratorSkippableTests { BACKGROUND_COLOR_DOC_TYPE_COLORS }

/// Shared tests for components that are migrating a component that mixes in
/// `ColorPropsMixin`.
void colorPropsMigratorTests(
    {@required SuggestorTester? testSuggestor,
    @required String? startingFactoryName,
    String? extraEndingProps,
    List<ColorPropsMigratorSkippableTests> testsToSkip = const []}) {
  if (startingFactoryName == null || testSuggestor == null) {
    throw ArgumentError(
        'startingFactoryName and testSuggestor are required parameters');
  }

  if (extraEndingProps == null) {
    extraEndingProps = '';
  }

  group('shared MuiChipPropsMigrator', () {
    group('backgroundColor', () {
      test('maps non-DOC_TYPE color constants properly', () async {
        await testSuggestor(
          input: withOverReactAndWsdImports('''
                content() {
                  ($startingFactoryName()..backgroundColor = BackgroundColor.DANGER)();
                  ($startingFactoryName()..backgroundColor = BackgroundColor.ALTERNATE)();
                  ($startingFactoryName()..backgroundColor = BackgroundColor.DEFAULT)();
                  ($startingFactoryName()..backgroundColor = BackgroundColor.SUCCESS)();
                  ($startingFactoryName()..backgroundColor = BackgroundColor.WARNING)();
                }
            '''),
          expectedOutput: withOverReactAndWsdImports('''
                content() {
                  (mui.Chip()..color = mui.ChipColor.error$extraEndingProps)();
                  (mui.Chip()..color = mui.ChipColor.secondary$extraEndingProps)();
                  (mui.Chip()..color = mui.ChipColor.inherit$extraEndingProps)();
                  (mui.Chip()..color = mui.ChipColor.success$extraEndingProps)();
                  (mui.Chip()..color = mui.ChipColor.warning$extraEndingProps)();
                }
            '''),
        );
      });

      if (testsToSkip.contains(
          ColorPropsMigratorSkippableTests.BACKGROUND_COLOR_DOC_TYPE_COLORS)) {
        test('maps DOC_TYPE color constants properly', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports('''
                content() {
                  ($startingFactoryName()..backgroundColor = BackgroundColor.DOC_TYPE_BLUE)();
                  ($startingFactoryName()..backgroundColor = BackgroundColor.DOC_TYPE_LIGHT_BLUE)();
                  ($startingFactoryName()..backgroundColor = BackgroundColor.DOC_TYPE_TEAL)();
                  ($startingFactoryName()..backgroundColor = BackgroundColor.DOC_TYPE_GRAY)();
                  ($startingFactoryName()..backgroundColor = BackgroundColor.DOC_TYPE_RED)();
                  ($startingFactoryName()..backgroundColor = BackgroundColor.DOC_TYPE_GREEN)();
                  ($startingFactoryName()..backgroundColor = BackgroundColor.DOC_TYPE_PURPLE)();
                  ($startingFactoryName()..backgroundColor = BackgroundColor.DOC_TYPE_ORANGE)();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports('''
                content() {
                  (mui.Chip()..color = mui.ChipColor.wsdLabelBlue$extraEndingProps)();
                  (mui.Chip()..color = mui.ChipColor.wsdLabelLightBlue$extraEndingProps)();
                  (mui.Chip()..color = mui.ChipColor.wsdLabelTeal$extraEndingProps)();
                  (mui.Chip()..color = mui.ChipColor.wsdLabelGray$extraEndingProps)();
                  (mui.Chip()..color = mui.ChipColor.wsdLabelRed$extraEndingProps)();
                  (mui.Chip()..color = mui.ChipColor.wsdLabelGreen$extraEndingProps)();
                  (mui.Chip()..color = mui.ChipColor.wsdLabelPurple$extraEndingProps)();
                  (mui.Chip()..color = mui.ChipColor.wsdLabelOrange$extraEndingProps)();
                }
            '''),
          );
        });
      }

      test('maps Zesty Crayon colors to the sx prop', () async {
        await testSuggestor(
          input: withOverReactAndWsdImports('''
                content() {
                  ($startingFactoryName()..backgroundColor = BackgroundColor.GREEN)();
                  ($startingFactoryName()..backgroundColor = BackgroundColor.BLUE)();
                  ($startingFactoryName()..backgroundColor = BackgroundColor.ORANGE)();
                  ($startingFactoryName()..backgroundColor = BackgroundColor.RED)();
                  ($startingFactoryName()..backgroundColor = BackgroundColor.GRAY)();
                }
            '''),
          expectedOutput: withOverReactAndWsdImports('''
                content() {
                  (mui.Chip()..sx = {'backgroundColor': (mui.Theme theme) => theme.palette.green.main, 'color': (mui.Theme theme) => theme.palette.common.white,}$extraEndingProps)();
                  (mui.Chip()..sx = {'backgroundColor': (mui.Theme theme) => theme.palette.blue.main, 'color': (mui.Theme theme) => theme.palette.common.white,}$extraEndingProps)();
                  (mui.Chip()..sx = {'backgroundColor': (mui.Theme theme) => theme.palette.orange.main, 'color': (mui.Theme theme) => theme.palette.common.white,}$extraEndingProps)();
                  (mui.Chip()..sx = {'backgroundColor': (mui.Theme theme) => theme.palette.red.main, 'color': (mui.Theme theme) => theme.palette.common.white,}$extraEndingProps)();
                  (mui.Chip()..sx = {'backgroundColor': (mui.Theme theme) => theme.palette.gray.main, 'color': (mui.Theme theme) => theme.palette.common.white,}$extraEndingProps)();
                }
            '''),
        );
      });

      group('flagging when the backgroundColor', () {
        test('is another expression', () async {
          await testSuggestor(
            input: withOverReactAndWsdImports('''
                content(dynamic otherBackgroundColor) {
                  ($startingFactoryName()..backgroundColor = otherBackgroundColor)();
                }
            '''),
            expectedOutput: withOverReactAndWsdImports('''
                content(dynamic otherBackgroundColor) {
                  (mui.Chip()
                    // FIXME(mui_migration) - backgroundColor prop - manually migrate
                    ..backgroundColor = otherBackgroundColor
                    $extraEndingProps
                  )();
                }
            '''),
          );
        });
      });
    });

    group('borderColor', () {
      test('gets flagged for manual migration', () async {
        await testSuggestor(
          input: withOverReactAndWsdImports('''
                content() {
                  ($startingFactoryName()..borderColor = BorderColor.DANGER)();
                }
            '''),
          expectedOutput: withOverReactAndWsdImports('''
                content() {
                  (mui.Chip()
                  // FIXME(mui_migration) - borderColor prop - this can be converted to the `sx` prop.
                  ..borderColor = BorderColor.DANGER
                  $extraEndingProps)();
                }
            '''),
        );
      });
    });

    group('textColor', () {
      test('gets flagged for manual migration', () async {
        await testSuggestor(
          input: withOverReactAndWsdImports('''
                content() {
                  ($startingFactoryName()..textColor = TextColor.DANGER)();
                }
            '''),
          expectedOutput: withOverReactAndWsdImports('''
                content() {
                  (mui.Chip()
                  // FIXME(mui_migration) - textColor prop - this can be converted to the `sx` prop.
                  ..textColor = TextColor.DANGER
                  $extraEndingProps)();
                }
            '''),
        );
      });
    });
  });
}

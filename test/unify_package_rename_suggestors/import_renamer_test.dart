// Copyright 2023 Workiva Inc.
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

import 'package:over_react_codemod/src/unify_package_rename_suggestors/import_renamer.dart';
import 'package:test/test.dart';

import '../util.dart';

void main() {
  group('importRenamer', () {
    final testSuggestor = getSuggestorTester(
      importRenamerSuggestorBuilder(
        oldPackageName: 'react_material_ui',
        newPackageName: 'unify_ui',
        oldPackageNamespace: 'mui',
        newPackageNamespace: 'unify',
      ),
    );

    test('does nothing when there are no imports', () async {
      await testSuggestor(input: '');
    });

    test('does nothing for non-react_material_ui imports', () async {
      await testSuggestor(
        input: /*language=dart*/ '''
            import 'package:over_react/over_react.dart';
        ''',
      );
    });

    // All tests strings are split by package name to work around issues with dependency_validator.
    group('updates react_material_ui imports in a file', () {
      test('', () async {
        await testSuggestor(
          input: '''
              import 'package:over_react/over_react.dart';
              import 'package:react_material_ui/react_material_ui.dart';
              import 'package:react_material_ui/z_alpha_may_break_at_runtime_do_not_release_to_customers.dart';
              import 'package:react_material_ui/components/badge.dart';
              import 'package:react_material_ui/abc.dart';
          
              content() => Dom.div()();
          ''',
          expectedOutput: '''
              import 'package:over_react/over_react.dart';
              import 'package:'''
              '''unify_ui/abc.dart';
              import 'package:'''
              '''unify_ui/components/badge.dart';
              import 'package:'''
              '''unify_ui/unify_ui.dart';
              import 'package:'''
              '''unify_ui/z_alpha_may_break_at_runtime_do_not_release_to_customers.dart';
          
              content() => Dom.div()();
          ''',
        );
      });

      test('in alphabetical order', () async {
        await testSuggestor(
          input: '''
              import 'package:react_material_ui/components/accordion.dart' as mui; import 'package:react_material_ui/components/alert.dart' as mui; import 'package:react_material_ui/components/app_bar.dart' as mui; import 'package:react_material_ui/components/autocomplete.dart' as mui; import 'package:react_material_ui/components/avatar.dart' as mui; import 'package:react_material_ui/components/badge.dart' as mui; import 'package:react_material_ui/components/box.dart' as mui; import 'package:react_material_ui/components/breadcrumbs.dart' as mui; import 'package:react_material_ui/components/button.dart' as mui; import 'package:react_material_ui/components/button_group.dart' as mui; import 'package:react_material_ui/components/button_toolbar.dart' as mui; import 'package:react_material_ui/components/card.dart' as mui; import 'package:react_material_ui/components/checkbox.dart' as mui; import 'package:react_material_ui/components/chip.dart' as mui; import 'package:react_material_ui/components/circular_progress.dart' as mui; import 'package:react_material_ui/components/container.dart' as mui; import 'package:react_material_ui/components/css_baseline.dart' as mui; import 'package:react_material_ui/components/date_pickers.dart' as mui; import 'package:react_material_ui/components/dialog.dart' as mui; import 'package:react_material_ui/components/divider.dart' as mui; import 'package:react_material_ui/components/drawer.dart' as mui; import 'package:react_material_ui/components/dropdown_button.dart' as mui; import 'package:react_material_ui/components/empty_view.dart' as mui; import 'package:react_material_ui/components/form_wrappers.dart' as mui; import 'package:react_material_ui/components/grid.dart' as mui; import 'package:react_material_ui/components/icon.dart' as mui; import 'package:react_material_ui/components/icon_button.dart' as mui; import 'package:react_material_ui/components/linear_progress.dart' as mui; import 'package:react_material_ui/components/link.dart' as mui; import 'package:react_material_ui/components/mui_list.dart' as mui; import 'package:react_material_ui/components/loading_button.dart' as mui; import 'package:react_material_ui/components/lockable_text_field.dart' as mui; import 'package:react_material_ui/components/masonry.dart' as mui; import 'package:react_material_ui/components/menu.dart' as mui; import 'package:react_material_ui/components/pagination.dart' as mui; import 'package:react_material_ui/components/paper.dart' as mui; import 'package:react_material_ui/components/popover.dart' as mui; import 'package:react_material_ui/components/popper.dart' as mui; import 'package:react_material_ui/components/radio.dart' as mui; import 'package:react_material_ui/components/react_virtuoso.dart' as mui; import 'package:react_material_ui/components/select.dart' as mui; import 'package:react_material_ui/components/skeleton.dart' as mui; import 'package:react_material_ui/components/slider.dart' as mui; import 'package:react_material_ui/components/stack.dart' as mui; import 'package:react_material_ui/components/stepper.dart' as mui; import 'package:react_material_ui/components/switch.dart' as mui; import 'package:react_material_ui/components/table.dart' as mui; import 'package:react_material_ui/components/tabs.dart' as mui; import 'package:react_material_ui/components/text_field.dart' as mui; import 'package:react_material_ui/components/toggle_button.dart' as mui; import 'package:react_material_ui/components/tooltip.dart' as mui; import 'package:react_material_ui/components/transitions.dart' as mui; import 'package:react_material_ui/components/typography.dart' as mui; import 'package:react_material_ui/components/unify_icons.dart' as mui; import 'package:react_material_ui/styles/hooks.dart' as mui;
              import 'package:react_material_ui/styles/styled.dart' as mui;
          
              content() => Dom.div()();
          ''',
          expectedOutput: '''
              import 'package:'''
              '''unify_ui/styles/styled.dart' as unify;
              import 'package:'''
              '''unify_ui/unify_ui.dart' as unify;
          
              content() => Dom.div()();
          ''',
        );
      });

      test(
          'for special cases when the new file path is different from the old one',
          () async {
        await testSuggestor(
          input: '''
              import 'package:react_material_ui/react_material_ui.dart';
              import 'package:over_react/over_react.dart';
              import 'package:web_skin_dart/ui_components.dart';
              import 'package:react_material_ui/for_cp_use_only/styled.dart';
              import 'package:react_material_ui/components/mui_list.dart';
              import 'package:react_material_ui/styles/styled.dart';
          
              content() => Dom.div()();
          ''',
          expectedOutput: '''
              import 'package:over_react/over_react.dart';
              import 'package:'''
              '''unify_ui/components/list.dart';
              import 'package:'''
              '''unify_ui/styles/styled.dart';
              import 'package:'''
              '''unify_ui/styles/styled.dart';
              import 'package:'''
              '''unify_ui/unify_ui.dart';
              import 'package:web_skin_dart/ui_components.dart';
          
              content() => Dom.div()();
          ''',
        );
      });

      test('with namespaces', () async {
        await testSuggestor(
          input: '''
              library lib;
          
              import 'package:react_material_ui/components/accordion.dart' as mui; import 'package:react_material_ui/components/alert.dart' as mui; import 'package:react_material_ui/components/app_bar.dart' as mui; import 'package:react_material_ui/components/autocomplete.dart' as mui; import 'package:react_material_ui/components/avatar.dart' as mui; import 'package:react_material_ui/components/badge.dart' as mui; import 'package:react_material_ui/components/box.dart' as mui; import 'package:react_material_ui/components/breadcrumbs.dart' as mui; import 'package:react_material_ui/components/button.dart' as mui; import 'package:react_material_ui/components/button_group.dart' as mui; import 'package:react_material_ui/components/button_toolbar.dart' as mui; import 'package:react_material_ui/components/card.dart' as mui; import 'package:react_material_ui/components/checkbox.dart' as mui; import 'package:react_material_ui/components/chip.dart' as mui; import 'package:react_material_ui/components/circular_progress.dart' as mui; import 'package:react_material_ui/components/container.dart' as mui; import 'package:react_material_ui/components/css_baseline.dart' as mui; import 'package:react_material_ui/components/date_pickers.dart' as mui; import 'package:react_material_ui/components/dialog.dart' as mui; import 'package:react_material_ui/components/divider.dart' as mui; import 'package:react_material_ui/components/drawer.dart' as mui; import 'package:react_material_ui/components/dropdown_button.dart' as mui; import 'package:react_material_ui/components/empty_view.dart' as mui; import 'package:react_material_ui/components/form_wrappers.dart' as mui; import 'package:react_material_ui/components/grid.dart' as mui; import 'package:react_material_ui/components/icon.dart' as mui; import 'package:react_material_ui/components/icon_button.dart' as mui; import 'package:react_material_ui/components/linear_progress.dart' as mui; import 'package:react_material_ui/components/link.dart' as mui; import 'package:react_material_ui/components/mui_list.dart' as mui; import 'package:react_material_ui/components/loading_button.dart' as mui; import 'package:react_material_ui/components/lockable_text_field.dart' as mui; import 'package:react_material_ui/components/masonry.dart' as mui; import 'package:react_material_ui/components/menu.dart' as mui; import 'package:react_material_ui/components/pagination.dart' as mui; import 'package:react_material_ui/components/paper.dart' as mui; import 'package:react_material_ui/components/popover.dart' as mui; import 'package:react_material_ui/components/popper.dart' as mui; import 'package:react_material_ui/components/radio.dart' as mui; import 'package:react_material_ui/components/react_virtuoso.dart' as mui; import 'package:react_material_ui/components/select.dart' as mui; import 'package:react_material_ui/components/skeleton.dart' as mui; import 'package:react_material_ui/components/slider.dart' as mui; import 'package:react_material_ui/components/stack.dart' as mui; import 'package:react_material_ui/components/stepper.dart' as mui; import 'package:react_material_ui/components/switch.dart' as mui; import 'package:react_material_ui/components/table.dart' as mui; import 'package:react_material_ui/components/tabs.dart' as mui; import 'package:react_material_ui/components/text_field.dart' as mui; import 'package:react_material_ui/components/toggle_button.dart' as mui; import 'package:react_material_ui/components/tooltip.dart' as mui; import 'package:react_material_ui/components/transitions.dart' as mui; import 'package:react_material_ui/components/typography.dart' as mui; import 'package:react_material_ui/components/unify_icons.dart' as mui; import 'package:react_material_ui/styles/hooks.dart' as mui;
              import 'package:react_material_ui/z_alpha_may_break_at_runtime_do_not_release_to_customers.dart' as alpha_mui;
              import 'package:react_material_ui/z_alpha_may_break_at_runtime_do_not_release_to_customers.dart' as mui_alpha;
              import 'package:over_react/over_react.dart' as mui;
              import 'package:react_material_ui/components/badge.dart' as mui;
              import 'package:react_material_ui/components/alert.dart' as something_else;
              import 'package:react_material_ui/styles/theme_provider.dart' as mui_theme show UnifyThemeProvider;
          
              content() => Dom.div()();
          ''',
          expectedOutput: '''
              library lib;
              
              import 'package:over_react/over_react.dart' as mui;
              import 'package:'''
              '''unify_ui/components/alert.dart' as something_else;
              import 'package:'''
              '''unify_ui/components/badge.dart' as unify;
              import 'package:'''
              '''unify_ui/styles/theme_provider.dart' as unify_theme show UnifyThemeProvider;
              import 'package:'''
              '''unify_ui/unify_ui.dart' as unify;
              import 'package:'''
              '''unify_ui/z_alpha_may_break_at_runtime_do_not_release_to_customers.dart' as alpha_unify;
              import 'package:'''
              '''unify_ui/z_alpha_may_break_at_runtime_do_not_release_to_customers.dart' as alpha_unify;
          
              content() => Dom.div()();
          ''',
        );
      });

      test('with show / hide', () async {
        await testSuggestor(
          input: '''
              import 'package:react_material_ui/react_material_ui.dart' hide Alert;
              import 'package:react_material_ui/z_alpha_may_break_at_runtime_do_not_release_to_customers.dart' as mui_alpha hide Alert show LinearProgress;
              import 'package:react_material_ui/components/badge.dart' show Badge hide BadgeColor;
              import 'package:react_material_ui/components/alert.dart' as something_else show Alert;
              import 'package:react_material_ui/styles/theme_provider.dart' as mui_theme show UnifyThemeProvider;
          
              content() => Dom.div()();
          ''',
          expectedOutput: '''
              import 'package:'''
              '''unify_ui/components/alert.dart' as something_else show Alert;
              import 'package:'''
              '''unify_ui/components/badge.dart' show Badge hide BadgeColor;
              import 'package:'''
              '''unify_ui/styles/theme_provider.dart' as unify_theme show UnifyThemeProvider;
              import 'package:'''
              '''unify_ui/unify_ui.dart' hide Alert;
              import 'package:'''
              '''unify_ui/z_alpha_may_break_at_runtime_do_not_release_to_customers.dart' as alpha_unify hide Alert show LinearProgress;
              
              content() => Dom.div()();
          ''',
        );
      });

      test('unless the imports are already updated to the new name', () async {
        await testSuggestor(
          input: '''
              library lib;
          
              import 'package:'''
              '''unify_ui/unify_ui.dart' as mui;
              import 'package:'''
              '''unify_ui/unify_ui.dart';
              import 'package:'''
              '''unify_ui/z_alpha_may_break_at_runtime_do_not_release_to_customers.dart' as mui_alpha;
              import 'package:'''
              '''unify_ui/z_alpha_may_break_at_runtime_do_not_release_to_customers.dart';
              import 'package:'''
              '''unify_ui/abc.dart';
          
              content() => Dom.div()();
          ''',
        );
      });

      test('also works for other package name inputs', () async {
        final testSuggestor = getSuggestorTester(
          importRenamerSuggestorBuilder(
            oldPackageName: 'old',
            newPackageName: 'new',
            oldPackageNamespace: 'o',
            newPackageNamespace: 'n',
          ),
        );
        await testSuggestor(
          input: '''
              import 'package:over_react/over_react.dart';
              import 'package:'''
              '''old/old.dart' as o;
              import 'package:'''
              '''old/components/badge.dart';
          
              content() => Dom.div()();
          ''',
          expectedOutput: '''
              import 'package:'''
              '''new/components/badge.dart';
              import 'package:'''
              '''new/old.dart' as n;
              import 'package:over_react/over_react.dart';
          
              content() => Dom.div()();
          ''',
        );
      });
    });
  });
}

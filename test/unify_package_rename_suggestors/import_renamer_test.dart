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
              import 'package:react_material_ui/react_material_ui.dart' as mui;
              import 'package:react_material_ui/styles/styled.dart' as mui;
          
              content() => Dom.div()();
          ''',
          expectedOutput: '''
              import 'package:'''
              '''unify_ui/styles/styled.dart' as mui;
              import 'package:'''
              '''unify_ui/unify_ui.dart' as mui;
          
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
              import 'package:react_material_ui/components/usage_must_be_approved_by_unify_team_for_legal_reasons_rmui/data_grid_premium.dart';
              import 'package:react_material_ui/styles/styled.dart';
              
          
              content() => Dom.div()();
          ''',
          expectedOutput: '''
              import 'package:over_react/over_react.dart';
              import 'package:'''
              '''unify_ui/components/list.dart';
              import 'package:'''
              '''unify_ui/components/usage_must_be_approved_by_unify_team_for_legal_reasons/data_grid_premium.dart';
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
          
              import 'package:react_material_ui/react_material_ui.dart' as mui;
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
              '''unify_ui/components/badge.dart' as mui;
              import 'package:'''
              '''unify_ui/styles/theme_provider.dart' as mui_theme show UnifyThemeProvider;
              import 'package:'''
              '''unify_ui/unify_ui.dart' as mui;
              import 'package:'''
              '''unify_ui/z_alpha_may_break_at_runtime_do_not_release_to_customers.dart' as alpha_mui;
              import 'package:'''
              '''unify_ui/z_alpha_may_break_at_runtime_do_not_release_to_customers.dart' as mui_alpha;
          
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
              '''unify_ui/styles/theme_provider.dart' as mui_theme show UnifyThemeProvider;
              import 'package:'''
              '''unify_ui/unify_ui.dart' hide Alert;
              import 'package:'''
              '''unify_ui/z_alpha_may_break_at_runtime_do_not_release_to_customers.dart' as mui_alpha hide Alert show LinearProgress;
              
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
              '''new/old.dart' as o;
              import 'package:over_react/over_react.dart';
          
              content() => Dom.div()();
          ''',
        );
      });
    });
  });
}

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

// todo add import order tests

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

    group('updates react_material_ui imports in a file', () {
      test('', () async {
        await testSuggestor(
          input: /*language=dart*/ '''
              import 'package:over_react/over_react.dart';
              import 'package:react_material_ui/react_material_ui.dart';
              import 'package:react_material_ui/z_alpha_may_break_at_runtime_do_not_release_to_customers.dart';
              import 'package:react_material_ui/components/badge.dart';
              import 'package:react_material_ui/abc.dart';
          
              content() => Dom.div()();
          ''',
          expectedOutput: /*language=dart*/ '''
              import 'package:over_react/over_react.dart';
              import 'package:unify_ui/unify_ui.dart';
              import 'package:unify_ui/z_alpha_may_break_at_runtime_do_not_release_to_customers.dart';
              import 'package:unify_ui/components/badge.dart';
              import 'package:unify_ui/abc.dart';
          
              content() => Dom.div()();
          ''',
        );
      });

      test('for special cases when the new file path is different from the old one', () async {
        await testSuggestor(
          input: /*language=dart*/ '''
              import 'package:react_material_ui/react_material_ui.dart';
              import 'package:over_react/over_react.dart';
              import 'package:web_skin_dart/ui_components.dart';
              import 'package:react_material_ui/for_cp_use_only/styled.dart';
              import 'package:react_material_ui/components/mui_list.dart';
              import 'package:react_material_ui/styles/styled.dart';
          
              content() => Dom.div()();
          ''',
          expectedOutput: /*language=dart*/ '''
              import 'package:unify_ui/unify_ui.dart';
              import 'package:over_react/over_react.dart';
              import 'package:web_skin_dart/ui_components.dart';
              import 'package:unify_ui/styles/styled.dart';
              import 'package:unify_ui/components/list.dart';
              import 'package:unify_ui/styles/styled.dart';
          
              content() => Dom.div()();
          ''',
        );
      });

      test(
          'unless there is a namespace on the main entrypoints that will be updated by a different suggestor',
          () async {
        await testSuggestor(
          input: /*language=dart*/ '''
              library lib;
          
              import 'package:react_material_ui/react_material_ui.dart' as mui;
              import 'package:react_material_ui/z_alpha_may_break_at_runtime_do_not_release_to_customers.dart' as alpha_mui;
              import 'package:react_material_ui/z_alpha_may_break_at_runtime_do_not_release_to_customers.dart' as mui_alpha;
              import 'package:over_react/over_react.dart' as mui;
              import 'package:react_material_ui/components/badge.dart' as mui;
          
              content() => Dom.div()();
          ''',
          expectedOutput: /*language=dart*/ '''
              library lib;
              
              import 'package:react_material_ui/react_material_ui.dart' as mui;
              import 'package:react_material_ui/z_alpha_may_break_at_runtime_do_not_release_to_customers.dart' as alpha_mui;
              import 'package:react_material_ui/z_alpha_may_break_at_runtime_do_not_release_to_customers.dart' as mui_alpha;
              import 'package:over_react/over_react.dart' as mui;
              import 'package:unify_ui/components/badge.dart' as unify;
          
              content() => Dom.div()();
          ''',
        );
      });

      test('unless the imports are already updated to the new name', () async {
        await testSuggestor(
          input: /*language=dart*/ '''
              library lib;
          
              import 'package:unify_ui/unify_ui.dart' as mui;
              import 'package:unify_ui/unify_ui.dart';
              import 'package:unify_ui/z_alpha_may_break_at_runtime_do_not_release_to_customers.dart' as mui_alpha;
              import 'package:unify_ui/z_alpha_may_break_at_runtime_do_not_release_to_customers.dart';
              import 'package:unify_ui/abc.dart';
          
              content() => Dom.div()();
          ''',
        );
      });

      test('also works for other package name inputs', () async {
        final testSuggestor = getSuggestorTester(
          ImportRenamer(
              oldPackageName: 'test_old',
              newPackageName: 'test_new',
              oldPackageNamespace: 'old',
              newPackageNamespace: 'new'),
        );
        await testSuggestor(
          input: /*language=dart*/ '''
              import 'package:test_old/abc.dart' as mui;
              import 'package:over_react/over_react.dart';
              import 'package:test_old/components/badge.dart';
          
              content() => Dom.div()();
          ''',
          expectedOutput: /*language=dart*/ '''
              import 'package:test_new/abc.dart' as mui;
              import 'package:over_react/over_react.dart';
              import 'package:test_new/components/badge.dart';
          
              content() => Dom.div()();
          ''',
        );
      });
    });
  });
}

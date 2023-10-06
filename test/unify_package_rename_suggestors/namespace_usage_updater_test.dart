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

import 'package:over_react_codemod/src/unify_package_rename_suggestors/namespace_usage_updater.dart';
import 'package:test/test.dart';

import '../resolved_file_context.dart';
import '../util.dart';

// todo also test builders
// todo also test non-component usage of the namespace

void main() {
  final resolvedContext = SharedAnalysisContext.rmui;

  // Warm up analysis in a setUpAll so that if getting the resolved AST times out
  // (which is more common for the WSD context), it fails here instead of failing the first test.
  setUpAll(resolvedContext.warmUpAnalysis);

  group('PackageRenameComponentUsageMigrator', () {
    final testSuggestor = getSuggestorTester(
      NamespaceUsageUpdater(),
      resolvedContext: resolvedContext,
    );

    group('namespace on component usage', () {
      test('mui namespace from react_material_ui is migrated to unify', () async {
        await testSuggestor(
          input: /*language=dart*/ '''
    import 'package:react_material_ui/react_material_ui.dart' as mui;
    
    content() {
      mui.Button()();
      mui.Checkbox()();
      mui.ButtonColor.success;
      mui.useTheme();
      mui.UnifyIcons.expandMore()();
      mui.Button;
      mui.Button();
    }
''',
          expectedOutput: /*language=dart*/ '''
    import 'package:react_material_ui/react_material_ui.dart' as mui;
    
    content() {
      unify.Button()();
      unify.Checkbox()();
      unify.ButtonColor.success;
      unify.useTheme();
      unify.UnifyIcons.expandMore()();
      unify.Button;
      unify.Button();
    }
''',
        );
      });

      test('alpha namespace from react_material_ui is migrated to unify', () async {
        await testSuggestor(
          input: /*language=dart*/ '''
    import 'package:react_material_ui/z_alpha_may_break_at_runtime_do_not_release_to_customers.dart' as alpha_mui;
    import 'package:react_material_ui/z_alpha_may_break_at_runtime_do_not_release_to_customers.dart' as mui_alpha;
    
    content() {
      alpha_mui.Rating()();
      mui_alpha.Rating()();
      alpha_mui.TimelinePosition.left;
      alpha_mui.useGridApiRef();
      alpha_mui.Popper;
      alpha_mui.Popper();
      mui_alpha.TimelinePosition.left;
      mui_alpha.useGridApiRef();
      mui_alpha.Popper;
      mui_alpha.Popper();
    }
''',
          expectedOutput: /*language=dart*/ '''
    import 'package:react_material_ui/z_alpha_may_break_at_runtime_do_not_release_to_customers.dart' as alpha_mui;
    import 'package:react_material_ui/z_alpha_may_break_at_runtime_do_not_release_to_customers.dart' as mui_alpha;
    
    content() {
      alpha_unify.Rating()();
      unify_alpha.Rating()();
      alpha_unify.TimelinePosition.left;
      alpha_unify.useGridApiRef();
      alpha_unify.Popper;
      alpha_unify.Popper();
      unify_alpha.TimelinePosition.left;
      unify_alpha.useGridApiRef();
      unify_alpha.Popper;
      unify_alpha.Popper();
    }
''',
        );
      });

      test('nested component implementations', () async {
        await testSuggestor(
          input: /*language=dart*/ '''
    import 'package:react_material_ui/react_material_ui.dart' as mui;
    import 'package:over_react/over_react.dart';
    
    content() {
      Fragment()(mui.ButtonToolbar()(
        (mui.Button()..size = mui.ButtonSize.small)('Foo'),
        (mui.Button()
          ..size = mui.ButtonSize.small
          ..color = mui.ButtonColor.primary
        )(
          'Bar',
        ),
      ));
      
      return (mui.Autocomplete()
        ..componentsProps = {
          'popper': mui.Popper()..placement = 'top-end',
          'popupIndicator': mui.IconButton()..sx = {'width': '20px'},
        }
        ..renderInput = mui.wrapRenderInput((textFieldProps) => (mui.TextField()
          ..addProps(textFieldProps)
          ..InputLabelProps = (mui.InputLabel()
            ..shrink = false)
        )())
      );
    }
''',
          expectedOutput: /*language=dart*/ '''
    import 'package:react_material_ui/react_material_ui.dart' as mui;
    
    content() {
      unify.ButtonToolbar()(
        (unify.Button()..size = unify.ButtonSize.small)('Foo'),
        (unify.Button()
          ..size = unify.ButtonSize.small
          ..color = unify.ButtonColor.primary
        )(
          'Bar',
        ),
      );
    }
''',
        );
      });

      test('mui namespace from a different package is not migrated', () async {
        await testSuggestor(
          input: /*language=dart*/ '''
    import 'package:over_react/over_react.dart' as mui;
    import 'package:over_react/over_react.dart' as alpha_mui;
    import 'package:over_react/over_react.dart' as mui_alpha;
    
    content() {
      mui.Fragment()();
      alpha_mui.Fragment()();
      mui_alpha.Fragment()();
    }
''',
        );
      });

      test('non-mui namespace on a react_material_ui import', () async {
        await testSuggestor(
          input: /*language=dart*/ '''
    import 'package:react_material_ui/react_material_ui.dart' as abc;
    import 'package:react_material_ui/z_alpha_may_break_at_runtime_do_not_release_to_customers.dart' as other;
    import 'package:react_material_ui/z_alpha_may_break_at_runtime_do_not_release_to_customers.dart' as something;
    
    content() {
      abc.Button()();
      abc.Checkbox()();
      other.Rating;
      something.Rating();
    }
''',
        );
      });

      test('no namespace on a react_material_ui import', () async {
        await testSuggestor(
          input: /*language=dart*/ '''
    import 'package:react_material_ui/react_material_ui.dart';
    
    content() {
      Button()();
      Checkbox()();
    }
''',
        );
      });
    });
  });
}

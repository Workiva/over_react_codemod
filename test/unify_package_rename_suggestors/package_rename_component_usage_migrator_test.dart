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

import 'package:over_react_codemod/src/unify_package_rename_suggestors/package_rename_component_usage_migrator.dart';
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
      PackageRenameComponentUsageMigrator(),
      resolvedContext: resolvedContext,
    );

    group('rename components', () {
      test('from react_material_ui to unify equivalents', () async {
        await testSuggestor(
          input: /*language=dart*/ '''
    import 'package:react_material_ui/react_material_ui.dart' as mui;
    import 'package:react_material_ui/react_material_ui.dart';
    import 'package:react_material_ui/react_material_ui.dart' as random_rmui_namespace;
    import 'package:react_material_ui/components/providers/workiva_mui_theme_provider.dart';
    
    content() {
      mui.Alert()();
      Alert()();
      random_rmui_namespace.Alert()();
      mui.LinkButton()();
      LinkButton()();
      random_rmui_namespace.LinkButton()();
      mui.MuiList()();
      MuiList()();
      random_rmui_namespace.MuiList()();
      WorkivaMuiThemeProvider()();
    }
''',
          expectedOutput: /*language=dart*/ '''
    import 'package:react_material_ui/react_material_ui.dart' as mui;
    import 'package:react_material_ui/react_material_ui.dart';
    import 'package:react_material_ui/react_material_ui.dart' as random_rmui_namespace;
    import 'package:react_material_ui/components/providers/workiva_mui_theme_provider.dart';

    content() {
      unify_wsd.WsdAlert()();
      unify_wsd.WsdAlert()();
      unify_wsd.WsdAlert()();
      unify_wsd.WsdLinkButton()();
      unify_wsd.WsdLinkButton()();
      unify_wsd.WsdLinkButton()();
      mui.UnifyList()();
      UnifyList()();
      random_rmui_namespace.UnifyList()();
      UnifyThemeProvider()();
    }
''',
        );
      });

      test('except when they are not from react_material_ui', () async {
        await testSuggestor(
          input: /*language=dart*/ '''
    import 'package:over_react/over_react.dart';
    
    // Shadows the RMUI factories
    UiFactory Alert;
    UiFactory LinkButton;
    UiFactory MuiList;
    UiFactory WorkivaMuiThemeProvider;
    
    content() {
      Alert()();
      LinkButton()();
      MuiList()();
      WorkivaMuiThemeProvider()();
    }
''',
        );
      });
    });

    group('fixme comments', () {
      test('for specific components that need manual intervention', () async {
        await testSuggestor(
          input: /*language=dart*/ '''
    import 'package:react_material_ui/react_material_ui.dart' as mui;
    import 'package:react_material_ui/react_material_ui.dart';
    
    content() {
      mui.Badge()();
      Badge()();
      mui.LinearProgress()();
      LinearProgress()();
    }
''',
          expectedOutput: /*language=dart*/ '''
    import 'package:react_material_ui/react_material_ui.dart' as mui;
    import 'package:react_material_ui/react_material_ui.dart';

    content() {
      // FIXME(unify_package_rename) Check what theme provider is wrapping this component: if it is a UnifyThemeProvider, remove this FIXME - no action is required; otherwise, migrate this component back to Web Skin Dart.
      mui.Badge()();
      // FIXME(unify_package_rename) Check what theme provider is wrapping this component: if it is a UnifyThemeProvider, remove this FIXME - no action is required; otherwise, migrate this component back to Web Skin Dart.
      Badge()();
      // FIXME(unify_package_rename) Check what theme provider is wrapping this component: if it is a UnifyThemeProvider, remove this FIXME - no action is required; otherwise, migrate this component back to Web Skin Dart.
      mui.LinearProgress()();
      // FIXME(unify_package_rename) Check what theme provider is wrapping this component: if it is a UnifyThemeProvider, remove this FIXME - no action is required; otherwise, migrate this component back to Web Skin Dart.
      LinearProgress()();
    }
''',
        );
      });

      test('except when they are not from react_material_ui', () async {
        await testSuggestor(
          input: /*language=dart*/ '''
    import 'package:over_react/over_react.dart';
    
    // Shadows the RMUI factories
    UiFactory Badge;
    UiFactory LinearProgress;
    
    content() {
      Badge()();
      LinearProgress()();
    }
''',
        );
      });
    });
  });
}

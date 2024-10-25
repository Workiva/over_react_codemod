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

import 'package:over_react_codemod/src/unify_package_rename_suggestors/unify_rename_suggestor.dart';
import 'package:test/test.dart';

import '../resolved_file_context.dart';
import '../util.dart';

void main() {
  final resolvedContext = SharedAnalysisContext.rmui;

  // Warm up analysis in a setUpAll so that if getting the resolved AST times out
  // (which is more common for the WSD context), it fails here instead of failing the first test.
  setUpAll(resolvedContext.warmUpAnalysis);

  group('UnifyRenameSuggestor', () {
    final testSuggestor = getSuggestorTester(
      UnifyRenameSuggestor(),
      resolvedContext: resolvedContext,
    );

    test('does not update namespaces',
          () async {
        await testSuggestor(
          input: /*language=dart*/ '''
    import 'package:react_material_ui/react_material_ui.dart' as mui;
    import 'package:react_material_ui/react_material_ui.dart' as abc;
    import 'package:react_material_ui/styles/color_utils.dart' as mui;
    import 'package:react_material_ui/z_alpha_may_break_at_runtime_do_not_release_to_customers.dart' as alpha_mui;
    
    content() {
      mui.Button()();
      mui.ButtonColor.success;
      mui.useTheme();
      mui.UnifyIcons.expandMore()();
      alpha_mui.Rating()();
      abc.Button()();
    }
''',
        );
    });

    group('renames', () {
      test('components from react_material_ui to unify equivalents', () async {
        await testSuggestor(
          input: /*language=dart*/ '''
    import 'package:react_material_ui/react_material_ui.dart' as mui;
    import 'package:react_material_ui/react_material_ui.dart';
    import 'package:react_material_ui/react_material_ui.dart' as random_rmui_namespace;
    import 'package:react_material_ui/components/providers/workiva_mui_theme_provider.dart';
    
    content() {
      mui.Alert()();
      mui.Alert();
      mui.Alert;
      mui.AlertSize.small;
      AlertSize.small;
      AlertSeverity.error;
      mui.AlertColor.warning;
      mui.AlertVariant.outlined;
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
      unify_wsd.WsdAlert();
      unify_wsd.WsdAlert;
      unify_wsd.WsdAlertSize.small;
      unify_wsd.WsdAlertSize.small;
      unify_wsd.WsdAlertSeverity.error;
      unify_wsd.WsdAlertColor.warning;
      unify_wsd.WsdAlertVariant.outlined;
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

      test('objects from react_material_ui to unify equivalents', () async {
        await testSuggestor(
          input: /*language=dart*/ '''
    import 'package:react_material_ui/react_material_ui.dart' as mui;
    import 'package:react_material_ui/react_material_ui.dart';
    import 'package:react_material_ui/react_material_ui.dart' as random_rmui_namespace;
    
    content() {
      mui.AutocompleteOnChangeObject;
      mui.AutocompleteOnChangeObject();
      random_rmui_namespace.BackdropTimeoutObject;
      BadgeAnchorOriginObjectHorizontal;
      MenuAnchorOriginObject();
      (Slider()..marks = [SliderMarksObject(value: 10)])();
    }
''',
          expectedOutput: /*language=dart*/ '''
    import 'package:react_material_ui/react_material_ui.dart' as mui;
    import 'package:react_material_ui/react_material_ui.dart';
    import 'package:react_material_ui/react_material_ui.dart' as random_rmui_namespace;
    
    content() {
      mui.AutocompleteChangeDetails;
      mui.AutocompleteChangeDetails();
      random_rmui_namespace.BackdropObject;
      BadgeOriginHorizontal;
      MenuPopoverOrigin();
      (Slider()..marks = [SliderMark(value: 10)])();
    }
''',
        );
      });

      test('ButtonColor updates', () async {
        await testSuggestor(
          input: /*language=dart*/ '''
    import 'package:react_material_ui/react_material_ui.dart' as mui;
    import 'package:react_material_ui/react_material_ui.dart';
    
    content() {
      mui.ButtonColor.success;
      mui.ButtonColor.wsdBtnInverse;
      mui.ButtonColor.wsdBtnLight;
      mui.ButtonColor.wsdBtnWhite;
      ButtonColor.success;
      ButtonColor.wsdBtnInverse;
      ButtonColor.wsdBtnLight;
      ButtonColor.wsdBtnWhite;
    }
''',
          expectedOutput: /*language=dart*/ '''
    import 'package:react_material_ui/react_material_ui.dart' as mui;
    import 'package:react_material_ui/react_material_ui.dart';
    
    content() {
      mui.ButtonColor.success;
      unify_wsd.WsdButtonColor.wsdBtnInverse;
      unify_wsd.WsdButtonColor.wsdBtnLight;
      unify_wsd.WsdButtonColor.wsdBtnWhite;
      ButtonColor.success;
      unify_wsd.WsdButtonColor.wsdBtnInverse;
      unify_wsd.WsdButtonColor.wsdBtnLight;
      unify_wsd.WsdButtonColor.wsdBtnWhite;
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
    class BackdropTimeoutObject {}
    abstract class ButtonColor {
      static const String wsdBtnLight = 'wsdBtnLight';
    }
    
    content() {
      Alert()();
      LinkButton()();
      MuiList()();
      WorkivaMuiThemeProvider()();
      BackdropTimeoutObject;
      ButtonColor.wsdBtnLight;
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

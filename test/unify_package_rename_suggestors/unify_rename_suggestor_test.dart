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

// todo also test builders
// todo also test non-component usage of the namespace

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

    group('namespace on component usage', () {
      test('mui namespace from react_material_ui is migrated to unify', () async {
        await testSuggestor(
          input: /*language=dart*/ '''
    import 'package:react_material_ui/react_material_ui.dart' as mui;
    import 'package:react_material_ui/styles/color_utils.dart' as mui;
    
    content() {
      mui.Button()();
      mui.Checkbox()();
      mui.ButtonColor.success;
      mui.useTheme();
      mui.UnifyIcons.expandMore()();
      mui.Button;
      mui.Button();
      mui.darken('abc', 1);
    }
''',
          expectedOutput: /*language=dart*/ '''
    import 'package:react_material_ui/react_material_ui.dart' as mui;
    import 'package:react_material_ui/styles/color_utils.dart' as mui;
    
    content() {
      unify.Button()();
      unify.Checkbox()();
      unify.ButtonColor.success;
      unify.useTheme();
      unify.UnifyIcons.expandMore()();
      unify.Button;
      unify.Button();
      unify.darken('abc', 1);
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
      alpha_unify.Rating()();
      alpha_unify.TimelinePosition.left;
      alpha_unify.useGridApiRef();
      alpha_unify.Popper;
      alpha_unify.Popper();
      alpha_unify.TimelinePosition.left;
      alpha_unify.useGridApiRef();
      alpha_unify.Popper;
      alpha_unify.Popper();
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
        (mui.Button()..color = mui.ButtonColor.wsdBtnLight)('Foo'),
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
        ..sx = {
          'color': (mui.Theme theme) =>
                  mui.getThemePalette(theme).common.white
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
    import 'package:over_react/over_react.dart';
    
    content() {
      Fragment()(unify.ButtonToolbar()(
        (unify.Button()..color = unify_wsd.WsdButtonColor.wsdBtnLight)('Foo'),
        (unify.Button()
          ..size = unify.ButtonSize.small
          ..color = unify.ButtonColor.primary
        )(
          'Bar',
        ),
      ));
      
      return (unify.Autocomplete()
        ..componentsProps = {
          'popper': unify.Popper()..placement = 'top-end',
          'popupIndicator': unify.IconButton()..sx = {'width': '20px'},
        }
        ..sx = {
          'color': (unify.Theme theme) =>
                  unify.getThemePalette(theme).common.white
        }
        ..renderInput = unify.wrapRenderInput((textFieldProps) => (unify.TextField()
          ..addProps(textFieldProps)
          ..InputLabelProps = (unify.InputLabel()
            ..shrink = false)
        )())
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
      mui.useRef();
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
      unify_wsd.WsdAlert()();
      unify_wsd.WsdAlert()();
      unify_wsd.WsdLinkButton()();
      unify_wsd.WsdLinkButton()();
      unify_wsd.WsdLinkButton()();
      unify.UnifyList()();
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
      unify.AutocompleteChangeDetails;
      unify.AutocompleteChangeDetails();
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
      unify.ButtonColor.success;
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
      unify.Badge()();
      // FIXME(unify_package_rename) Check what theme provider is wrapping this component: if it is a UnifyThemeProvider, remove this FIXME - no action is required; otherwise, migrate this component back to Web Skin Dart.
      Badge()();
      // FIXME(unify_package_rename) Check what theme provider is wrapping this component: if it is a UnifyThemeProvider, remove this FIXME - no action is required; otherwise, migrate this component back to Web Skin Dart.
      unify.LinearProgress()();
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

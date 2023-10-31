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

/// Info on a unify_ui import.
class UnifyImportInfo {
  UnifyImportInfo(this.uri,
      {this.rmuiUri,
      this.namespace,
      this.possibleMuiNamespaces,
      this.showHideInfo});

  /// Unify import URI.
  String uri;

  /// Recommended Unify version of the import namespace, if applicable.
  String? namespace;

  /// List of common RMUI versions of the namespace for the import, if applicable.
  List<String>? possibleMuiNamespaces;

  /// Previous RMUI import URI (if it's different from the unify_ui path).
  String? rmuiUri;

  /// Additional show / hide information used in [importRenamerSuggestorBuilder] to add to updated imports.
  String? showHideInfo;
}

/// A list of the standard imports for unify_ui that should be updated.
///
/// Only adds namespace information if the import is commonly used with a namespace.
/// Only adds RMUI uri information if it is different from a simple package name swap.
final rmuiImportsToUpdate = [
  UnifyImportInfo(
    'package:unify_ui/unify_ui.dart',
    rmuiUri: 'package:react_material_ui/react_material_ui.dart',
    namespace: 'unify',
    possibleMuiNamespaces: ['mui', 'rmui'],
  ),
  UnifyImportInfo(
    'package:unify_ui/z_alpha_may_break_at_runtime_do_not_release_to_customers.dart',
    rmuiUri:
        'package:react_material_ui/z_alpha_may_break_at_runtime_do_not_release_to_customers.dart',
    namespace: 'alpha_unify',
    possibleMuiNamespaces: ['alpha_mui', 'mui_alpha'],
  ),
  UnifyImportInfo(
    'package:unify_ui/components/list.dart',
    rmuiUri: 'package:react_material_ui/components/mui_list.dart',
  ),
  UnifyImportInfo(
    'package:unify_ui/styles/styled.dart',
    rmuiUri: 'package:react_material_ui/for_cp_use_only/styled.dart',
  ),
  UnifyImportInfo('package:unify_ui/styles/theme_provider.dart',
      rmuiUri: 'package:react_material_ui/styles/theme_provider.dart',
      namespace: 'unify_theme',
      possibleMuiNamespaces: ['mui_theme'])
];

/// A map of RMUI component names to their new names in unify_ui.
///
/// This is based on the list of changes in the migration guide: https://github.com/Workiva/react_material_ui/tree/master/react_material_ui#how-to-migrate-from-reactmaterialui-to-unifyui
const rmuiToUnifyIdentifierRenames = {
  // Components
  'Alert': 'WsdAlert',
  'AlertPropsMixin': 'WsdAlertPropsMixin',
  'LinkButton': 'WsdLinkButton',
  'LinkButtonPropsMixin': 'WsdLinkButtonPropsMixin',
  'MuiList': 'UnifyList',
  'MuiListPropsMixin': 'UnifyListPropsMixin',
  'WorkivaMuiThemeProvider': 'UnifyThemeProvider',
  'WorkivaMuiThemeProviderPropsMixin': 'UnifyThemeProviderPropsMixin',
  // Alert objects
  'AlertIconMappingObject': 'WsdAlertIconMappingObject',
  // Autocomplete objects
  'AutocompleteFilterOptionsObject': 'AutocompleteFilterOptionsState',
  'AutocompleteOnChangeObject': 'AutocompleteChangeDetails',
  'AutocompleteRenderOptionObject': 'AutocompleteRenderOptionState',
  // Backdrop objects
  'BackdropTimeoutObject': 'BackdropObject',
  'BackdropTransitionDurationObject': 'BackdropObject',
  // Badge objects
  'BadgeAnchorOriginObject': 'BadgeOrigin',
  'BadgeAnchorOriginObjectVertical': 'BadgeOriginVertical',
  'BadgeAnchorOriginObjectHorizontal': 'BadgeOriginHorizontal',
  // Breadcrumb objects
  'BreadcrumbNavCrumbsObject': 'BreadcrumbNavBreadcrumbModel',
  // CSSTransition objects
  'CSSTransitionClassNamesObject': 'CSSTransitionClassNames',
  // DropdownButton objects
  'DropdownButtonOnPlacementUpdate': 'DropdownButtonPlacement',
  // Menu objects
  'MenuAnchorOriginObject': 'MenuPopoverOrigin',
  'MenuTransformOriginObject': 'MenuPopoverOrigin',
  'MenuAnchorOriginObjectVertical': 'MenuPopoverOriginVertical',
  'MenuTransformOriginObjectVertical': 'MenuPopoverOriginVertical',
  'MenuAnchorOriginObjectHorizontal': 'MenuPopoverOriginHorizontal',
  'MenuTransformOriginObjectHorizontal': 'MenuPopoverOriginHorizontal',
  'MenuAnchorPositionObject': 'MenuPopoverPosition',
  // Popover objects
  'PopoverAnchorOriginObject': 'PopoverOrigin',
  'PopoverTransformOriginObject': 'PopoverOrigin',
  'PopoverAnchorOriginObjectVertical': 'PopoverOriginVertical',
  'PopoverTransformOriginObjectVertical': 'PopoverOriginVertical',
  'PopoverAnchorOriginObjectHorizontal': 'PopoverOriginHorizontal',
  'PopoverTransformOriginObjectHorizontal': 'PopoverOriginHorizontal',
  'PopoverAnchorPositionObject': 'PopoverPosition',
  // Popper objects
  'PopperAnchorElObject': 'PopperVirtualElement',
  'PopperModifiersObject': 'PopperModifier',
  'PopperModifiersObjectPhase': 'PopperModifierPhases',
  'PopperPopperOptionsObject': 'PopperOptionsGeneric',
  'PopperPopperOptionsObjectPlacement': 'PopperPlacement',
  'PopperPopperOptionsObjectStrategy': 'PopperPositioningStrategy',
  // Slider objects
  'SliderMarksObject': 'SliderMark',
  // Snackbar objects
  'SnackbarAnchorOriginObject': 'SnackbarOrigin',
  'SnackbarAnchorOriginObjectVertical': 'SnackbarOriginVertical',
  'SnackbarAnchorOriginObjectHorizontal': 'SnackbarOriginHorizontal',
  // TablePagination objects
  'TablePaginationLabelDisplayedRowsObject':
      'TablePaginationLabelDisplayedRowsArgs',
};

/// The namespace that will be used for the `unify_ui/components/wsd.dart` import that is added.
const unifyWsdNamespace = 'unify_wsd';

/// The uri for the `unify_ui/components/wsd.dart` import that is added.
const unifyWsdUri = 'package:unify_ui/components/wsd.dart';

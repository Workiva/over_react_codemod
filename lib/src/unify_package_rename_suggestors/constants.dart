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

// todo comment
class UnifyImportInfo {
  UnifyImportInfo(this.uri, {this.rmuiUri, this.namespace, this.possibleMuiNamespaces});
  String? namespace;
  List<String>? possibleMuiNamespaces;
  String uri;
  String? rmuiUri;
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
    'package:unify_ui/components/wsd.dart',
    namespace: unifyWsdNamespace,
  ),
  UnifyImportInfo(
    'package:unify_ui/components/list.dart',
    rmuiUri: 'package:react_material_ui/components/mui_list.dart',
  ),
  UnifyImportInfo(
    'package:unify_ui/styles/styled.dart',
    rmuiUri: 'package:react_material_ui/for_cp_use_only/styled.dart',
  )
];

/// A map of RMUI component names to their new names in unify_ui.
const rmuiToUnifyComponentNames = {
  'Alert': 'WsdAlert',
  'LinkButton': 'WsdLinkButton',
  'MuiList': 'UnifyList',
  'WorkivaMuiThemeProvider': 'UnifyThemeProvider',
};

/// The namespace that will be used for the `unify_ui/components/wsd.dart` import that is added.
const unifyWsdNamespace = 'unify_wsd';

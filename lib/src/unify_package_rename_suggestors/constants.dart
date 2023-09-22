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

/// A map of the standard namespaces for rmui imports to their unify equivalents.
const rmuiToUnifyNamespaces = {
  'mui': 'unify',
  'alpha_mui': 'alpha_unify',
  'mui_alpha': 'unify_alpha',
};

/// A map of RMUI component names to their new names in unify_ui.
const rmuiToUnifyComponentNames = {
  'Alert': 'WsdAlert',
  'LinkButton': 'WsdLinkButton',
  'MuiList': 'UnifyList',
  'WorkivaMuiThemeProvider': 'UnifyThemeProvider',
};

/// The namespace that will be used for the `unify_ui/components/wsd.dart` import that is added.
const unifyWsdNamespace = 'unify_wsd';

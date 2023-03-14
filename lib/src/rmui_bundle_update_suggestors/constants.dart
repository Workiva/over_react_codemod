// Copyright 2021 Workiva Inc.
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

/// The script for the dev RMUI bundle.
const rmuiBundleDev =
    'packages/react_material_ui/react-material-ui-development.umd.js';

/// The script for the prod RMUI bundle.
const rmuiBundleProd = 'packages/react_material_ui/react-material-ui.umd.js';

/// The script for the dev RMUI bundle.
const rmuiBundleDevUpdated =
    'packages/react_material_ui/js/react-material-ui.browser.dev.esm.js';

/// The script for the prod RMUI bundle.
const rmuiBundleProdUpdated =
    'packages/react_material_ui/js/react-material-ui.browser.min.esm.js';

/// Regex to get the type attribute if it exists.
final typeAttributePattern = RegExp('type=[\"\']([^\"\']*)[\"\']');

/// Regex to get the src attribute if it exists.
final srcAttributePattern = RegExp('src=[\"\']([^\"\']*)[\"\']');

/// The type attribute that needs to be added for the new RMUI bundles.
final typeModuleAttribute = 'type="module"';

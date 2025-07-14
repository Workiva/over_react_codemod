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

/// The script for the dev Unify bundle.
const unifyBundleDev = 'packages/unify_ui/js/unify-ui.browser.dev.esm.js';

/// The script for the prod Unify bundle.
const unifyBundleProd = 'packages/unify_ui/js/unify-ui.browser.min.esm.js';

/// The type attribute that needs to be added to script tags for the new RMUI bundles.
final typeModuleAttribute = 'type="module"';

/// The crossorigin attribute that needs to be added to link tags for the new RMUI bundles.
final crossOriginAttribute = 'crossorigin=""';

/// Returns a pattern to get the [attribute] if it exists.
RegExp getAttributePattern(String attribute) {
  return RegExp('$attribute=[\"\']([^\"\']*)[\"\']');
}

/// A script that can be searched for via a link tag [pattern] for a
/// specific path ([pathSubpattern]).
class Link {
  final String pathSubpattern;

  const Link({required this.pathSubpattern});

  /// A pattern for finding a link tag with a matching path.
  RegExp get pattern => RegExp(
      r'(?<preceding_whitespace>[^\S\r\n]*)<link[^>]*href="(?<path_prefix>[^"]*)' +
          pathSubpattern +
          r'"[^>]*>(?<trailing_new_line>\n?)');

  @override
  String toString() =>
      'Script(pathSubpattern: $pathSubpattern, pattern: $pattern)';
}

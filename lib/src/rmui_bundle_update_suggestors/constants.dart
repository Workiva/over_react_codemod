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

/// A script that can be searched for via a script tag [pattern] for a
/// specific path ([pathSubpattern]).
class Script {
  final String pathSubpattern;

  const Script({required this.pathSubpattern});

  /// A pattern for finding a script tag with a matching path,
  /// including preceding whitespace and any path prefix.
  ///
  /// See:
  ///
  /// - [ScriptMatch.precedingWhitespaceGroup]
  /// - [ScriptMatch.pathPrefixGroup]
  RegExp get pattern => RegExp(
      r'(?<preceding_whitespace>[^\S\r\n]*)<script.*src="(?<path_prefix>.*)' +
          pathSubpattern +
          r'".*</script>');

  @override
  String toString() =>
      'Script(pathSubpattern: $pathSubpattern, pattern: $pattern)';
}

/// A script that can be searched for via a script tag [pattern] for a
/// specific [path], and can also be used to construct a [scriptTag] that
/// can be inserted into a file.
class ScriptToAdd extends Script {
  final String path;

  ScriptToAdd({required this.path})
      : super(pathSubpattern: RegExp.escape(path));

  String scriptTag({required String pathPrefix}) =>
      '<script src="$pathPrefix$path"></script>';

  @override
  String toString() => 'ScriptToAdd(path: $path, pattern: $pattern)';
}

extension ScriptMatch on RegExpMatch {
  /// The named capturing group for the whitespace preceding a script tag.
  ///
  /// For matches of [Script.pattern] only.
  String get precedingWhitespaceGroup => namedGroup('preceding_whitespace')!;

  /// The named capturing group for any path in a matched script tag that
  /// becomes before [Script.pathSubpattern].
  ///
  /// For matches of [Script.pattern] only.
  String get pathPrefixGroup => namedGroup('path_prefix')!;
}

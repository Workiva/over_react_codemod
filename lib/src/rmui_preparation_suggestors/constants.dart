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

/// The name of the Workiva theme for RMUI components.
const wkTheme = 'wkTheme';

/// The script for the dev RMUI bundle.
final rmuiBundleDev = ScriptToAdd(
    path: 'packages/react_material_ui/react-material-ui-development.umd.js');

/// The script for the prod RMUI bundle.
final rmuiBundleProd =
    ScriptToAdd(path: 'packages/react_material_ui/react-material-ui.umd.js');

/// The script pattern for finding react-dart JS scripts.
const reactJsScript =
    SrcTag(tagName: 'script', pathSubpattern: r'packages/react/react\w*.js');

/// An HTML [tagName] tag with a src attribute that can be searched for via a [pattern] for a
/// specific path ([pathSubpattern]).
class SrcTag {
  /// The name of the tag being searched for (ex. 'script', 'link').
  final String tagName;
  final String pathSubpattern;

  const SrcTag({required this.tagName, required this.pathSubpattern});

  /// A pattern for finding a script tag with a matching path,
  /// including preceding whitespace and any path prefix.
  ///
  /// See:
  ///
  /// - [ScriptMatch.precedingWhitespaceGroup]
  /// - [ScriptMatch.pathPrefixGroup]
  RegExp get pattern => RegExp(r'(?<preceding_whitespace>[^\S\r\n]*)<' +
      tagName +
      '.*src="(?<path_prefix>.*)' +
      pathSubpattern +
      r'".*</' +
      tagName +
      '>');

  @override
  String toString() =>
      'Script(pathSubpattern: $pathSubpattern, pattern: $pattern)';
}

/// A script that can be searched for via a script tag [pattern] for a
/// specific [path], and can also be used to construct a [scriptTag] that
/// can be inserted into a file.
class ScriptToAdd extends SrcTag {
  final String path;

  ScriptToAdd({required this.path})
      : super(tagName: 'script', pathSubpattern: RegExp.escape(path));

  String scriptTag({required String pathPrefix}) =>
      '<script src="$pathPrefix$path"></script>';

  @override
  String toString() => 'ScriptToAdd(path: $path, pattern: $pattern)';
}

extension ScriptMatch on RegExpMatch {
  /// The named capturing group for the whitespace preceding a script tag.
  ///
  /// For matches of [SrcTag.pattern] only.
  String get precedingWhitespaceGroup => namedGroup('preceding_whitespace')!;

  /// The named capturing group for any path in a matched script tag that
  /// becomes before [SrcTag.pathSubpattern].
  ///
  /// For matches of [SrcTag.pattern] only.
  String get pathPrefixGroup => namedGroup('path_prefix')!;
}

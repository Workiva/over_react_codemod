// Copyright 2019 Workiva Inc.
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

/// Utility functions that are not specific to any particular over_react
/// codemod or suggestor.
library over_react_codemod.src.util;

import 'package:path/path.dart' as p;

import 'constants.dart';

/// Returns a Dart single-line ignore comment that tells the analyzer to ignore
/// the given set of analysis/lint rules.
///
/// The returned ignore comment will simply be a comma-joined string of the set
/// of rules selected via the boolean parameters (`true` means include the rule
/// in the ignore comment, `false` means exclude it) with the necessary
/// `'// ignore: '` prefix.
///
///     buildIgnoreComment(mixinOfNonClass: true);
///     // '// ignore: mixin_of_non_class'
///     buildIgnoreComment(mixinOfNonClass: true, undefinedClass: true);
///     // '// ignore: mixin_of_non_class, undefined_class'
String buildIgnoreComment({
  bool constInitializedWithNonConstantValue = false,
  bool mixinOfNonClass = false,
  bool undefinedClass = false,
  bool undefinedIdentifier = false,
  bool uriHasNotBeenGenerated = false,
}) {
  final ignores = [];
  if (constInitializedWithNonConstantValue) {
    ignores.add('const_initialized_with_non_constant_value');
  }
  if (mixinOfNonClass) {
    ignores.add('mixin_of_non_class');
  }
  if (undefinedClass) {
    ignores.add('undefined_class');
  }
  if (undefinedIdentifier) {
    ignores.add('undefined_identifier');
  }
  if (uriHasNotBeenGenerated) {
    ignores.add('uri_has_not_been_generated');
  }
  return '// ignore: ${ignores.join(', ')}';
}

String convertPartOfUriToRelativePath(String libraryPath, Uri partOfUri) {
  if (partOfUri.scheme == 'package') {
    // Canonicalize to ensure that if we find different relative paths to
    // the same file, they will still match.
    return p.canonicalize(
      // Add a `./lib` path segment to the beginning since that is
      // effectively what the `package:` syntax means. We know the package
      // URI must be to the local package because a file cannot be a part
      // of an external library.
      p.join(
        './lib',
        // Strips the first path segment, which is just the package name.
        partOfUri.pathSegments.sublist(1).join(p.separator),
      ),
    );
  } else {
    // Canonicalize to ensure that if we find different relative paths to
    // the same file, they will still match.
    return p.canonicalize(
      // Convert the path to be relative to the CWD of the codemod rather
      // than the current file.
      p.join(
        // containing directory of the current library
        p.dirname(libraryPath),
        // relative path from current file to parent library file
        partOfUri.path,
      ),
    );
  }
}

/// Returns true if over_react is **not** used in the given [contents], and
/// false otherwise.
///
/// Use this to avoid parsing the AST for a file unnecessarily.
///
/// Note that a return value of false does not guarantee that over_reat is used
/// (in other words, a false negative is possible). This is because a regex
/// pattern match is used, and misses the following case:
///
/// - An over_react annotation is used at the beginning of a line in the middle
///   of a multi-line string literal.
bool doesNotUseOverReact(String contents) {
  return !_usesOverReactRegex.hasMatch(contents);
}

final _usesOverReactRegex = RegExp(
  // Matches the annotation's `@` symbol at the beginning of the line, which
  // ensures that comments are ignored.
  r'^@' +
      // Matches any of the 9 over_react annotations.
      r'(?:' +
      overReactAnnotationNames.join('|') +
      r')' +
      // Matches the opening paren, ensuring there aren't additional chars in the
      // annotation name.
      // Note that the closing paren is NOT matched, because some of the annotations
      // accept arguments.
      r'\(',
  caseSensitive: true,
  multiLine: true,
);

/// Returns [value] without the leading private generated prefix (`_$`) if it is
/// present.
///
/// If the private generated prefix is not present, [value] will be returned as
/// is.
///
///     stripPrivateGeneratedPrefix('_$FooProps')
///     // 'FooProps'
///     stripPrivateGeneratedPrefix('_$_FooProps')
///     // '_FooProps'
///     stripPrivateGeneratedPrefix('FooProps')
///     // 'FooProps'
///     stripPrivateGeneratedPrefix('Foo_$Props')
///     // 'Foo_$Props'
String stripPrivateGeneratedPrefix(String value) {
  return value.startsWith(privateGeneratedPrefix)
      ? value.substring(privateGeneratedPrefix.length)
      : value;
}

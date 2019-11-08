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

import 'package:analyzer/dart/ast/ast.dart';
import 'package:args/args.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import 'constants.dart';

typedef String CompanionBuilder(String className,
    {String annotations, String commentPrefix, String docComment});

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

/// Returns the source code for a companion `@Props()` or `@AbstractProps()`
/// class named [className].
///
/// Callers do not need to worry about the format/state of the given
/// [className] (i.e. whether or not it has already been renamed for Dart 2
/// compatibility); it will be normalized.
///
/// If the [docComment] string is non-null and non-empty, it will be included
/// before the class.
///
/// If the [annotations] string is non-null and non-empty, it will be included
/// before the class.
///
/// If given, [commentPrefix] will be inserted at the beginning of the
/// double-slash comment on the companion class declaration. Use this as a way
/// to reference a cleanup ticket or issue number.
String buildPropsCompanionClass(
  String className, {
  String annotations,
  String commentPrefix,
  String docComment,
  TypeParameterList typeParameters,
}) =>
    _buildPropsOrStateCompanionClass(className, propsMetaType,
        annotations: annotations,
        commentPrefix: commentPrefix,
        docComment: docComment,
        typeParameters: typeParameters);

/// Returns the source code for a companion `@State()` or `@AbstractState()`
/// class named [className].
///
/// Callers do not need to worry about the format/state of the given
/// [className] (i.e. whether or not it has already been renamed for Dart 2
/// compatibility); it will be normalized.
///
/// If the [docComment] string is non-null and non-empty, it will be included
/// before the class.
///
/// If the [annotations] string is non-null and non-empty, it will be included
/// before the class.
///
/// If given, [commentPrefix] will be inserted at the beginning of the
/// double-slash comment on the companion class declaration. Use this as a way
/// to reference a cleanup ticket or issue number.
String buildStateCompanionClass(
  String className, {
  String annotations,
  String commentPrefix,
  String docComment,
  TypeParameterList typeParameters,
}) =>
    _buildPropsOrStateCompanionClass(className, stateMetaType,
        annotations: annotations,
        commentPrefix: commentPrefix,
        docComment: docComment,
        typeParameters: typeParameters);

/// Returns the source code for a companion class based on the given
/// [className] and [metaType].
///
/// The returned class will have the following attributes:
/// - Name: the result of calling [stripPrivateGeneratedPrefix] on [className].
/// - Super class: the class name with the private generated prefix.
///   [className]
/// - Mixin: same as super class but with a `AccessorsMixin` suffix.
/// - A static meta field typed as [metaType] (should be either `PropsMeta` or
///   `StateMeta`) and with an initialized value of `$metaFor<name>` where name
///   is the same as the class name.
/// - Annotations if [annotations] is non-null and non-empty.
/// - A doc comment if [docComment] is non-null and non-empty.
/// - A single-line comment indicating that this class is temporary and will be
///   removed when Dart 1 support is no longer needed. If a [commentPrefix] is
///   given, it will be inserted at the beginning of this single-line comment.
///
/// Callers do not need to worry about the format/state of the given
/// [className] (i.e. whether or not it has already been renamed for Dart 2
/// compatibility); it will be normalized.
String _buildPropsOrStateCompanionClass(
  String className,
  String metaType, {
  String annotations,
  String commentPrefix,
  String docComment,
  TypeParameterList typeParameters,
}) {
  annotations ??= '';
  commentPrefix ??= '';
  docComment ??= '';

  final classCommentsAndAnnotations = <String>[];
  if (docComment.isNotEmpty) {
    classCommentsAndAnnotations.add(docComment);
  }
  if (annotations.isNotEmpty) {
    classCommentsAndAnnotations.add(annotations);
  }
  classCommentsAndAnnotations.add(
      '// ${commentPrefix}This will be removed once the transition to Dart 2 is complete.');

  var typeParamsOnClass = '';
  var typeParamsOnSuper = '';
  if (typeParameters != null) {
    typeParamsOnClass = typeParameters.toSource();
    typeParamsOnSuper = (StringBuffer()
          ..write('<')
          ..write(
              typeParameters.typeParameters.map((t) => t.name.name).join(', '))
          ..write('>'))
        .toString();
  }

  final strippedClassName = stripPrivateGeneratedPrefix(className);
  final mixinIgnoreComment = buildIgnoreComment(
    mixinOfNonClass: true,
    undefinedClass: true,
  );
  final metaIgnoreComment = buildIgnoreComment(
    constInitializedWithNonConstantValue: true,
    undefinedClass: true,
    undefinedIdentifier: true,
  );
  // With triple-quote strings, the first newline is ignored if the first line
  // is empty, so this string purposely includes an extra blank line.
  return '''

${classCommentsAndAnnotations.join('\n')}
class $strippedClassName$typeParamsOnClass extends ${privateGeneratedPrefix}$strippedClassName$typeParamsOnSuper
    with
        $mixinIgnoreComment
        ${privateGeneratedPrefix}${strippedClassName}AccessorsMixin$typeParamsOnSuper {
  $metaIgnoreComment
  static const $metaType meta = ${privateGeneratedPrefix}metaFor$strippedClassName;
}
''';
}

/// Returns the canonicalized relative path for the given [partOfUri].
///
/// If [partOfUri] is a `package:` URI, the returned path will be relative to
/// current working directory (assumed to be the package root).
///
/// Otherwise, [partOfUri] must be a relative URI. The returned path will be
/// this relative path joined with the containing directory of [libraryPath].
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

/// Method that creates a new dependency range by targeting a higher range.
///
/// This can be used to update dependency ranges without lowering a current
/// constraint unintentionally.
VersionRange generateNewVersionRange(
    VersionRange currentRange, VersionRange targetRange) {
  return VersionRange(
    min:
        currentRange.min > targetRange.min ? currentRange.min : targetRange.min,
    includeMin: true,
    max: targetRange.max,
  );
}

/// Returns a string representation of [constraint], converting it to caret
/// notation when possible.
///
/// Example:
/// ```dart
/// // ^1.2.3
/// print(friendlyVersionConstraint(VersionConstraint.parse('>=1.2.3 <2.0.0')));
///
/// // >1.2.3 <3.0.0
/// print(friendlyVersionConstraint(VersionConstraint.parse('>1.2.3 <3.0.0')));
/// ```
String friendlyVersionConstraint(VersionConstraint constraint) {
  if (constraint is VersionRange && constraint.min != null) {
    final caretConstraint = VersionConstraint.compatibleWith(constraint.min);
    if (caretConstraint == constraint) {
      return caretConstraint.toString();
    }
  }

  return constraint.toString();
}

/// Return whether or not a particular pubspec.yaml dependency value string
/// should be wrapped in quotations.
bool mightNeedYamlEscaping(String scalarValue) =>
    // Values starting with `>` need escaping.
    // Whitelist a non-exhaustive list of allowable characters,
    // flagging that the value should be escaped when we're not sure.
    !RegExp(r'^[^>][-+.<>=^ \w]*$').hasMatch(scalarValue);

/// Parses a `--comment-prefix=<value>` command-line option from [args] if
/// present, returning `<value>` (or null if the option is omitted) **and
/// removes the relevant items from the [args] list.**
///
/// **[args] may be modified in place.**
String parseAndRemoveCommentPrefixArg(List<String> args) {
  final _commentPrefixParser = ArgParser()..addOption('comment-prefix');

  final commentPrefixArgs = <String>[];
  for (var i = 0; i < args.length; i++) {
    if (args[i].startsWith('--comment-prefix')) {
      if (args[i].contains('=')) {
        commentPrefixArgs.add(args[i]);
        args.removeAt(i);
      } else if (i + 1 < args.length) {
        commentPrefixArgs..add(args[i])..add(args[i + 1]);
        args..removeAt(i)..removeAt(i + 1);
      }
      break;
    }
  }

  if (commentPrefixArgs.isEmpty) {
    return null;
  }

  return _commentPrefixParser.parse(commentPrefixArgs)['comment-prefix'];
}

/// Returns the Dart-2-compatible class name for the given props or state
/// [className].
///
/// Use to rename a class in the original Dart-1-only format to the
/// version expected for forwards-compatibility with Dart 2, while also
/// accounting for already-renamed classes. In other words, if the given class
/// name is already correct, the same value will be returned.
///
///     renamePropsOrStateClass('FooProps');
///     // '_$FooProps'
///     renamePropsOrStateClass('_$FooProps');
///     // '_$FooProps'
///     renamePropsOrStateClass('_FooProps');
///     // '_$_FooProps'
///     renamePropsOrStateClass('_$_FooProps');
///     // '_$_FooProps'
String renamePropsOrStateClass(String className) {
  return '$privateGeneratedPrefix${stripPrivateGeneratedPrefix(className)}';
}

/// Returns whether or not a pubspec.yaml version should be updated.
///
/// This is useful when a certain min or max needs to be enforced but the
/// current dependency can take many different forms.
bool shouldUpdateVersionRange({
  @required VersionConstraint constraint,
  @required VersionRange targetConstraint,
  bool shouldIgnoreMin = false,
}) {
  if (constraint.isAny) return false;
  if (constraint is VersionRange) {
    var constraintsHaveMax =
        (targetConstraint.max != null && constraint.max != null);
    var constraintsHaveMin =
        (targetConstraint.min != null && constraint.min != null);
    // Short circuit if the constraints are the same.
    if (targetConstraint == constraint) return false;
    // If this is null, the dependency is set to >= with no upper limit.
    if (constraint.max == null && constraint.min != null) {
      // In that case, we need the min to be at least as high as our
      // target. If it is, do not update.
      if (constraint.min >= targetConstraint.min) {
        return false;
      }

      return true;
    } else {
      // If there is a maximum, and it is higher than target max (but the
      // lower bound is still greater or equal to the target) do not
      // update.
      if (constraintsHaveMax && constraint.max >= targetConstraint.max) {
        // If the codemod is asserting a specific minimum, the
        // constraint min does not matter.
        if (constraintsHaveMin &&
            constraint.min >= targetConstraint.min &&
            !shouldIgnoreMin) {
          return false;
        }
      }

      return true;
    }
  }

  return false;
}

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

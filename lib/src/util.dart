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

import 'dart:collection';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:args/args.dart';
import 'package:codemod/codemod.dart';
import 'package:collection/collection.dart' show IterableExtension;
import 'package:glob/glob.dart';
import 'package:over_react_codemod/src/boilerplate_suggestors/boilerplate_utilities.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import 'constants.dart';

typedef CompanionBuilder = String Function(String className,
    {String? annotations, String? commentPrefix, String? docComment});

/// Returns an iterable of all the comments from [beginToken] to the end of the
/// file.
///
/// Comments are part of the normal stream, and need to be accessed via
/// [Token.precedingComments], so it's difficult to iterate over them without
/// this method.
Iterable<Token> allComments(Token beginToken) sync* {
  Token? currentToken = beginToken;
  while (currentToken != null && !currentToken.isEof) {
    Token? currentComment = currentToken.precedingComments;
    while (currentComment != null) {
      yield currentComment;
      currentComment = currentComment.next;
    }
    currentToken = currentToken.next;
  }
  // Also check comments preceding EOF.
  Token? currentComment = currentToken!.precedingComments;
  while (currentComment != null) {
    yield currentComment;
    currentComment = currentComment.next;
  }
}

bool _isCommentToken(Token token) {
  return const {TokenType.SINGLE_LINE_COMMENT, TokenType.MULTI_LINE_COMMENT}
      .contains(token.type);
}

/// Returns all the comments before a given [node], including doc comments.
Iterable<Token> allCommentsForNode(AstNode node) sync* {
  Token? firstCommentToken;

  final beginToken = node.beginToken;
  if (_isCommentToken(beginToken)) {
    firstCommentToken = beginToken;
    while (firstCommentToken!.previous != null) {
      firstCommentToken = firstCommentToken.previous;
    }
  } else {
    firstCommentToken = beginToken.precedingComments;
  }

  // No comments on this node.
  if (firstCommentToken == null) return;

  Token? currentComment = firstCommentToken;
  while (currentComment != null) {
    yield currentComment;
    currentComment = currentComment.next;
  }
}

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

/// Returns the canonicalized relative path for the given [partOfUri].
///
/// If [partOfUri] is a `package:` URI, the returned path will be relative to
/// current working directory (assumed to be the package root).
///
/// Otherwise, [partOfUri] must be a relative URI. The returned path will be
/// this relative path joined with the containing directory of [libraryPath].
String convertPartOfUriToRelativePath(String? libraryPath, Uri partOfUri) {
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
        p.dirname(libraryPath!),
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
    min: currentRange.min! > targetRange.min!
        ? currentRange.min
        : targetRange.min,
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
    final caretConstraint = VersionConstraint.compatibleWith(constraint.min!);
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
String? parseAndRemoveCommentPrefixArg(List<String> args) {
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

/// Locates the [commentToRemove] and - if found - removes it from the
/// [node] using the [yieldPatch] provided.
void removeCommentFromNode(
    AstNode node, String commentToRemove, YieldPatch yieldPatch) {
  final nodeCommentLines = allComments(node.beginToken);
  final commentLinesToRemove =
      commentToRemove.split('\n').map((line) => line.trim()).toList();
  final firstLineOfCommentToRemove = commentLinesToRemove.first;
  final firstMatchingCommentLineToken = nodeCommentLines.firstWhereOrNull(
      (token) => token.toString().trim() == firstLineOfCommentToRemove);

  if (firstMatchingCommentLineToken != null) {
    if (commentLinesToRemove.length == 1) {
      // Remove single line comment
      yieldPatch('', firstMatchingCommentLineToken.offset,
          firstMatchingCommentLineToken.end);
    } else {
      final lastLineOfCommentToRemove =
          commentLinesToRemove[commentLinesToRemove.length - 2];
      final lastMatchingCommentLineToken = nodeCommentLines.lastWhereOrNull(
          (token) => token.toString().trim() == lastLineOfCommentToRemove);
      if (lastMatchingCommentLineToken != null) {
        // Remove multi line comment
        yieldPatch('', firstMatchingCommentLineToken.offset,
            lastMatchingCommentLineToken.end);
      }
    }
  }
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
  required VersionConstraint constraint,
  required VersionRange targetConstraint,
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
      if (constraint.min! >= targetConstraint.min!) {
        return false;
      }

      return true;
    } else {
      // If there is a maximum, and it is higher than target max (but the
      // lower bound is still greater or equal to the target) do not
      // update.
      if (constraintsHaveMax && constraint.max! >= targetConstraint.max!) {
        // If the codemod is asserting a specific minimum, the
        // constraint min does not matter.
        if (constraintsHaveMin &&
            constraint.min! >= targetConstraint.min! &&
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

Iterable<String> pubspecYamlPaths() =>
    filePathsFromGlob(Glob('**pubspec.yaml', recursive: true));

Iterable<String> allDartPathsExceptHidden() =>
    filePathsFromGlob(Glob('**.dart', recursive: true));

Iterable<String> allDartPathsExceptHiddenAndGenerated() =>
    filePathsFromGlob(Glob('**.dart', recursive: true))
        .where((path) => !path.endsWith('.g.dart'));

/// Returns whether or not [sourceText] contains invalid code.
///
/// Used to override [Suggestor.shouldSkip] when parsing errors should be
/// skipped instead of thrown when [Suggestor.generatePatches] is called.
bool hasParseErrors(String sourceText) {
  final parsed = parseString(content: sourceText, throwIfDiagnostics: false);
  return parsed.errors.isNotEmpty;
}

/// Returns a lazy iterable of all descendants of [node], in breadth-first order.
Iterable<AstNode> allDescendants(AstNode node) sync* {
  final nodesQueue = Queue<AstNode>()..add(node);
  while (nodesQueue.isNotEmpty) {
    final current = nodesQueue.removeFirst();
    for (final child in current.childEntities) {
      if (child is AstNode) {
        yield child;
        nodesQueue.add(child);
      }
    }
  }
}

/// Returns a lazy iterable of all descendants of [node] of type [T], in breadth-first order.
Iterable<T> allDescendantsOfType<T extends AstNode>(AstNode node) =>
    allDescendants(node).whereType<T>();

/// Finds a dependency within a pubspec and returns the [VersionRange].
VersionRange? getDependencyVersion(String pubspecContent, String dependency) {
  final dependencyValidatorRegex =
      RegExp('^  $dependency: (.+)\$', multiLine: true);
  final dependencyMatch = dependencyValidatorRegex.firstMatch(pubspecContent);
  if (dependencyMatch == null) return null;

  final versionString = dependencyMatch.group(1);

  if (versionString == null) return null;

  return parseVersionRange(versionString.replaceAll('"', ''));
}

VersionRange parseVersionRange(String text) {
  final constraint = VersionConstraint.parse(text);
  if (constraint is! VersionRange) {
    throw ArgumentError.value(
        text, 'text', 'not a VersionRange; was a ${constraint.runtimeType}');
  }
  return constraint;
}

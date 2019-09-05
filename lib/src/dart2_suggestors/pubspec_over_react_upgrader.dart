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

import 'package:codemod/codemod.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:source_span/source_span.dart';

import '../constants.dart';
import '../util.dart';

/// Suggestor that attempts to update `pubspec.yaml` files to ensure a safe
/// minimum bound on the `over_react` dependency.
///
/// If `over_react` is already listed, but the minimum bound is not high enough,
/// the version constraint will be updated. If `over_react` is missing from
/// the file, it will be added.
class PubspecOverReactUpgrader implements Suggestor {
  /// Version constraint that ensures a version of over_react compatible with
  /// the new forwards- and backwards-compatible component boilerplate.
  static final VersionRange dart1And2Constraint =
      VersionConstraint.parse('^1.30.2');

  /// Version constraint that ensures a version of over_react compatible with
  /// the Dart 2 builder and also opens the range up to over_react 2.x which is
  /// the first release that drops support for Dart 1.
  static final VersionRange dart2Constraint =
      VersionConstraint.parse('>=1.30.2 <3.0.0');

  /// Constraint to update over_react to.
  final VersionRange targetConstraint;

  /// Whether or not the codemod should ignore the constraint minimum when
  /// considering whether to write a patch.
  final bool shouldIgnoreMin;

  /// Whether or not the codemod should add `over_react` if it is not already
  /// found.
  final bool shouldAddDependencies;

  PubspecOverReactUpgrader(this.targetConstraint,
      {this.shouldAddDependencies = true})
      : shouldIgnoreMin = false;

  /// Constructor used to ignore checks and ensure that the codemod always
  /// tries to update the constraint.
  ///
  /// This is useful because the codemod may want to enforce a specific
  /// range, rather than a target upper or lower bound. The only time this
  /// will not update the pubspec is if the target version range is equal to
  /// the version that is already there (avoiding an empty patch error).
  PubspecOverReactUpgrader.alwaysUpdate(this.targetConstraint,
      {this.shouldAddDependencies = true})
      : shouldIgnoreMin = true;

  @override
  Iterable<Patch> generatePatches(SourceFile sourceFile) sync* {
    final contents = sourceFile.getText(0);
    final overReactMatch = overReactDependencyRegExp.firstMatch(contents);

    if (overReactMatch != null) {
      // over_react is already in pubspec.yaml
      final constraintValue = overReactMatch.group(2);
      final constraint = VersionConstraint.parse(constraintValue);

      if (shouldUpdateVersionRange(
          targetConstraint: targetConstraint,
          constraint: constraint,
          shouldIgnoreMin: shouldIgnoreMin)) {
        // Wrap the new constraint in quotes if required.
        var newValue =
            generateNewVersionRange(constraint, targetConstraint).toString();

        if (mightNeedYamlEscaping(newValue)) {
          newValue = '"$newValue"';
        }

        // Update the version constraint to ensure a safe minimum bound.
        yield Patch(
            sourceFile,
            sourceFile.span(overReactMatch.start, overReactMatch.end),
            '  over_react: $newValue');
      }
    } else if (shouldAddDependencies) {
      // over_react is missing in pubspec.yaml, so add it.
      final dependeniesKeyMatch = dependencyRegExp.firstMatch(contents);
      if (dependeniesKeyMatch != null) {
        // Wrap the new constraint in quotes if required.
        var newValue = targetConstraint.toString();
        if (newValue.contains(' ')) {
          newValue = '"$newValue"';
        }

        yield Patch(
          sourceFile,
          sourceFile.span(dependeniesKeyMatch.end, dependeniesKeyMatch.end),
          '\n  over_react: $newValue',
        );
      }
    }
  }

  @override
  bool shouldSkip(_) => false;
}

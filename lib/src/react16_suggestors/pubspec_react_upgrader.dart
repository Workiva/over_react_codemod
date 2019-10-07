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
/// minimum bound on the `react` dependency.
///
/// If `react` is already listed, but the minimum bound is not high enough,
/// the version constraint will be updated. If `react` is missing from
/// the file, it will be added.
class PubspecReactUpdater implements Suggestor {
  /// Constraint to update react to.
  final VersionRange targetConstraint;

  /// Whether or not the dependency should be added if it is not already
  /// present.
  final bool shouldAddDependencies;

  PubspecReactUpdater(this.targetConstraint,
      {this.shouldAddDependencies = true});

  @override
  Iterable<Patch> generatePatches(SourceFile sourceFile) sync* {
    final contents = sourceFile.getText(0);
    final reactMatch = reactDependencyRegExp.firstMatch(contents);

    if (reactMatch != null) {
      // react is already in pubspec.yaml
      final constraintValue = reactMatch.group(2);
      try {
        final constraint = VersionConstraint.parse(constraintValue);

        if (shouldUpdateVersionRange(
            constraint: constraint, targetConstraint: targetConstraint)) {
          // Wrap the new constraint in quotes if required.
          var newValue = targetConstraint.toString().contains('-alpha') ||
                  targetConstraint.toString().contains('-dev')
              ? targetConstraint.toString()
              : generateNewVersionRange(constraint, targetConstraint)
                  .toString();

          if (mightNeedYamlEscaping(newValue)) {
            newValue = '"$newValue"';
          }

          // Update the version constraint to ensure a safe minimum bound.
          yield Patch(
              sourceFile,
              sourceFile.span(reactMatch.start, reactMatch.end),
              '  react: $newValue');
        }
      } catch (e) {
        // We can skip these. They are versions we don't want to mess with in this codemod.
        if (e.toString().contains('git:') || e.toString().contains('path:')) {
          return;
        }

        rethrow;
      }
    } else if (shouldAddDependencies) {
      // react is missing in pubspec.yaml, so add it.
      final dependenciesKeyMatch = dependencyRegExp.firstMatch(contents);

      if (dependenciesKeyMatch != null) {
        // Wrap the new constraint in quotes if required.
        var newValue = targetConstraint.toString();
        if (mightNeedYamlEscaping(newValue)) {
          newValue = '"$newValue"';
        }

        yield Patch(
          sourceFile,
          sourceFile.span(dependenciesKeyMatch.end, dependenciesKeyMatch.end),
          '\n  react: $newValue',
        );
      }
    }
  }

  @override
  bool shouldSkip(_) => false;
}

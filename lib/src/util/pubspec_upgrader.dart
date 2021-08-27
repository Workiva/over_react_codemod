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

import '../constants.dart';
import '../util.dart';

/// Suggestor that attempts to update `pubspec.yaml` files to ensure a safe
/// minimum bound on a package dependency.
///
/// If the package is already listed, but the minimum bound is not high enough,
/// the version constraint will be updated. If the package is missing from
/// the file, it will be added.
class PubspecUpgrader {
  /// The package name to upgrade
  final String packageName;

  /// Constraint to update the package to.
  final VersionRange targetConstraint;

  /// Whether this is a dev dependency versus a normal dependency.
  final bool isDevDependency;

  /// Whether or not the codemod should ignore the constraint minimum when
  /// considering whether to write a patch.
  final bool shouldIgnoreMin;

  /// Whether or not the codemod should add the package if it is not already
  /// found.
  final bool shouldAddDependencies;

  PubspecUpgrader(this.packageName, this.targetConstraint,
      {this.isDevDependency = false, this.shouldAddDependencies = true})
      : shouldIgnoreMin = false;

  /// Constructor used to ignore checks and ensure that the codemod always
  /// tries to update the constraint.
  ///
  /// This is useful because the codemod may want to enforce a specific
  /// range, rather than a target upper or lower bound. The only time this
  /// will not update the pubspec is if the target version range is equal to
  /// the version that is already there (avoiding an empty patch error).
  PubspecUpgrader.alwaysUpdate(this.packageName, this.targetConstraint,
      {this.isDevDependency = false, this.shouldAddDependencies = true})
      : shouldIgnoreMin = true;

  Stream<Patch> call(FileContext context) async* {
    final packageMatch =
        getDependencyRegExp(packageName).firstMatch(context.sourceText);

    if (packageMatch != null) {
      // this package is already in pubspec.yaml
      final constraintValue = packageMatch.group(2)!;
      try {
        final constraint = VersionConstraint.parse(constraintValue);

        if (shouldUpdateVersionRange(
            targetConstraint: targetConstraint,
            constraint: constraint,
            shouldIgnoreMin: shouldIgnoreMin)) {
          final newConstraint =
              targetConstraint.toString().contains('-alpha') ||
                      targetConstraint.toString().contains('-dev')
                  ? targetConstraint
                  : generateNewVersionRange(
                      constraint as VersionRange, targetConstraint);

          var newValue = friendlyVersionConstraint(newConstraint);
          // Wrap the new constraint in quotes if required.
          if (mightNeedYamlEscaping(newValue)) {
            newValue = '"$newValue"';
          }

          // Update the version constraint to ensure a safe minimum bound.
          yield Patch('  $packageName: $newValue', packageMatch.start,
              packageMatch.end);
        }
      } catch (e) {
        // We can skip these. They are versions we don't want to mess with in this codemod.
        if (e.toString().contains('git:') || e.toString().contains('path:')) {
          return;
        }

        rethrow;
      }
    } else if (shouldAddDependencies) {
      // Package is missing in pubspec.yaml, so add it.
      final keyMatch =
          (isDevDependency ? devDependencyRegExp : dependencyRegExp)
              .firstMatch(context.sourceText);
      if (keyMatch != null) {
        // Wrap the new constraint in quotes if required.
        var newValue = targetConstraint.toString();
        if (newValue.contains(' ')) {
          newValue = '"$newValue"';
        }

        yield Patch(
          '\n  $packageName: $newValue',
          keyMatch.end,
          keyMatch.end,
        );
      }
    }
  }
}

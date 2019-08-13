
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

/// Suggestor that attempts to update `pubspec.yaml` files to ensure a safe
/// minimum bound on the `react` dependency.
///
/// If `react` is already listed, but the minimum bound is not high enough,
/// the version constraint will be updated. If `react` is missing from
/// the file, it will be added.
class React16PubspecUpdater implements Suggestor {
  /// Version constraint that ensures a version of over_react compatible with
  /// the new forwards- and backwards-compatible component boilerplate.
  static final VersionRange dart1And2Constraint =
  VersionConstraint.parse('^1.30.2');

  /// Version constraint that ensures a version of over_react compatible with
  /// the Dart 2 builder and also opens the range up to over_react 2.x which is
  /// the first release that drops support for Dart 1.
  static final VersionRange dart2Constraint =
  VersionConstraint.parse('>=1.30.2 <3.0.0');

  /// Regex that matches the dependency constraint declaration for over_react.
  static final RegExp reactDep = RegExp(
    r'''^\s*react:\s*["']?([\d\s<>=^.]+)["']?\s*$''',
    multiLine: true,
  );

  /// Regex that matches the `dependencies:` key in a pubspec.yaml.
  static final RegExp dependenciesKey = RegExp(
    r'^\s*dependencies:$',
    multiLine: true,
  );

  final VersionRange targetConstraint;

  React16PubspecUpdater(this.targetConstraint);

  @override
  Iterable<Patch> generatePatches(SourceFile sourceFile) sync* {
    final contents = sourceFile.getText(0);
    final reactMatch = reactDep.firstMatch(contents);
    if (reactMatch != null) {
      // react is already in pubspec.yaml
      final line = reactMatch.group(0);
      final constraintValue = reactMatch.group(1);
      final constraint = VersionConstraint.parse(constraintValue);
      if (constraint is VersionRange && constraint.min < targetConstraint.min) {
        // Wrap the new constraint in quotes if required.
        var newValue = targetConstraint.toString();
        if (newValue.contains(' ') &&
            !line.contains("'") &&
            !line.contains('"')) {
          newValue = "'$newValue'";
        }

        // Update the version constraint to ensure a safe minimum bound.
        yield Patch(
          sourceFile,
          sourceFile.span(reactMatch.start, reactMatch.end),
          line.replaceFirst(
            constraintValue,
            newValue,
          ),
        );
      }
    } else {
      // react is missing in pubspec.yaml, so add it.
      final dependenciesKeyMatch = dependenciesKey.firstMatch(contents);

      if (dependenciesKeyMatch != null) {
        // Wrap the new constraint in quotes if required.
        var newValue = targetConstraint.toString();
        if (newValue.contains(' ')) {
          newValue = "'$newValue'";
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
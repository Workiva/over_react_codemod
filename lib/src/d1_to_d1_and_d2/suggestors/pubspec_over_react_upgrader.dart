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
/// minimum bound on the `over_react` dependency.
///
/// If `over_react` is already listed, but the minimum bound is not high enough,
/// the version constraint will be updated. If `over_react` is missing from
/// the file, it will be added.
class PubspecOverReactUpgrader implements Suggestor {
  /// Version constraint that ensures a version of over_react compatible with
  /// the new forwards- and backwards-compatible component boilerplate.
  static final VersionRange overReactConstraint =
      VersionConstraint.parse('^1.30.2');

  /// Regex that matches the dependency constraint declaration for over_react.
  static final RegExp overReactDep = RegExp(
    r'''^\s*over_react:\s*["']?([\d\s<>=^.]+)["']?\s*$''',
    multiLine: true,
  );

  /// Regex that matches the `dependencies:` key in a pubspec.yaml.
  static final RegExp dependenciesKey = RegExp(
    r'^dependencies:$',
    multiLine: true,
  );

  @override
  Iterable<Patch> generatePatches(SourceFile sourceFile) sync* {
    final contents = sourceFile.getText(0);
    final overReactMatch = overReactDep.firstMatch(contents);
    if (overReactMatch != null) {
      // over_react is already in pubspec.yaml
      final line = overReactMatch.group(0);
      final constraintValue = overReactMatch.group(1);
      final constraint = VersionConstraint.parse(constraintValue);
      if (constraint is VersionRange &&
          constraint.min < overReactConstraint.min) {
        // Update the version constraint to ensure a safe minimum bound.
        yield Patch(
          sourceFile,
          sourceFile.span(overReactMatch.start, overReactMatch.end),
          line.replaceFirst(
            constraintValue,
            overReactConstraint.toString(),
          ),
        );
      }
    } else {
      // over_react is missing in pubspec.yaml, so add it.
      final dependeniesKeyMatch = dependenciesKey.firstMatch(contents);
      if (dependeniesKeyMatch != null) {
        yield Patch(
          sourceFile,
          sourceFile.span(dependeniesKeyMatch.end, dependeniesKeyMatch.end),
          '\n  over_react: $overReactConstraint',
        );
      }
    }
  }

  @override
  bool shouldSkip(_) => false;
}

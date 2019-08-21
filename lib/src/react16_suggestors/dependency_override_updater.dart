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
import 'package:source_span/source_span.dart';

/// Suggestor that adds overrides for over_react and react in the pubspec.
class DependencyOverrideUpdater implements Suggestor {
  /// Regex that matches the dependency constraint declaration for over_react.
  static final RegExp overReactDep = RegExp(
    r'''^\s*over_react:\s*["']?([\d\s<>=^.]+)["']?\s*$''',
    multiLine: true,
  );

  /// Regex that matches the dependency constraint declaration for react.
  static final RegExp reactDep = RegExp(
    r'''^\s*react:\s*["']?([\d\s<>=^.]+)["']?\s*$''',
    multiLine: true,
  );

  /// Regex that matches the `dependency_overrides:` key in a pubspec.yaml.
  static final RegExp dependencyOverrideKey = RegExp(
    r'^dependency_overrides:$',
    multiLine: true,
  );

  @override
  Iterable<Patch> generatePatches(SourceFile sourceFile) sync* {
    final contents = sourceFile.getText(0);
    final containsOverReactOverride = containsDependencyOverride(
        dependency: 'over_react', fileContent: contents);
    final containsReactOverride = containsDependencyOverride(
        dependency: 'react-dart', fileContent: contents);
    final reactDependencyMatch = reactDep.firstMatch(contents);
    final overReactDepMatch = reactDep.firstMatch(contents);
    final dependencyOverridesMatch = dependencyOverrideKey.firstMatch(contents);

    if ((overReactDepMatch != null && reactDependencyMatch != null) &&
        (!containsOverReactOverride && !containsReactOverride)) {
      final dependencyOverrides = ''
          '  react:\n'
          '    git:\n'
          '      url: git@github.com:cleandart/react-dart.git\n'
          '      ref: 5.0.0-wip\n'
          '  over_react:\n'
          '    git:\n'
          '      url: git@github.com:Workiva/over_react.git\n'
          '      ref: 3.0.0-wip\n'
          '';

      final lineCount = sourceFile.lines - 1;
      var span = sourceFile.getOffset(lineCount);

      if (dependencyOverridesMatch != null) {
        final lineAfterOverrideSectionStart =
            sourceFile.getLine(dependencyOverridesMatch.end) + 1;

        span = sourceFile.getOffset(lineAfterOverrideSectionStart);

        yield Patch(
            sourceFile, sourceFile.span(span, span), '$dependencyOverrides');
      } else {
        yield Patch(
            sourceFile,
            sourceFile.span(span, span),
            '\n'
            'dependency_overrides:\n'
            '$dependencyOverrides');
      }
    }
  }

  @override
  bool shouldSkip(_) => false;
}

bool containsDependencyOverride({String dependency, String fileContent}) {
  final regexString = r'''^\s*\w{0,4}\s*:\s*[\s\S]*(.com){0,1}.\w*\/''' +
      dependency +
      r'''[\s\S]*\n{0,1}$''';

  final dependencyRegex = RegExp(
    regexString,
    multiLine: true,
  );

  final regexMatch = dependencyRegex.firstMatch(fileContent);

  return regexMatch != null;
}

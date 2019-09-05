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
import 'package:meta/meta.dart';
import 'package:source_span/source_span.dart';
import 'package:yaml/yaml.dart';

import '../constants.dart';
import '../creator_utils.dart';

/// Suggestor that adds overrides for over_react and react in the pubspec.
class DependencyOverrideUpdater implements Suggestor {
  /// Regex that matches the `dependency_overrides:` key in a pubspec.yaml.
  static final RegExp dependencyOverrideKey = dependencyOverrideRegExp;

  @override
  Iterable<Patch> generatePatches(SourceFile sourceFile) sync* {
    final contents = sourceFile.getText(0);
    final dependencyOverrideSectionKey =
        dependencyOverrideKey.firstMatch(contents);

    // This needs to be kept track of because the patches are applied all at
    // once, so even though we will add the dependency_override key the file
    // won't be aware until all the patching is done.
    bool shouldAddDependencyOverrideKey = dependencyOverrideSectionKey == null;

    // Each override has its own object to keep track of what the dependency
    // override is and what it needs to be overridden with.
    // TODO update these versions to the dev branch after major release.
    final reactDependencyOverride = DependencyCreator('react',
        gitOverride: 'https://github.com/cleandart/react-dart.git',
        ref: '5.0.0-wip');

    final overReactDependencyOverride = DependencyCreator('over_react',
        gitOverride: 'https://github.com/Workiva/over_react.git',
        ref: '3.0.0-wip');

    final dependenciesToUpdate = [
      reactDependencyOverride,
      overReactDependencyOverride
    ];

    YamlMap parsedYamlMap;

    try {
      parsedYamlMap = loadYaml(contents);
    } catch (e, stackTrace) {
      if (e is YamlException) {
        throw Exception('Could not parse pubspec.yaml.$e\n$stackTrace');
      } else {
        throw Exception(
            'Unexpected error loading pubspec.yaml.$e\n$stackTrace');
      }
    }

    for (var dependencyOverride in dependenciesToUpdate) {
      final dependency = dependencyOverride.name;
      final overrideString = dependencyOverride.toString();

      if (fileContainsDependencyOverride(
          dependency: dependency, yamlContent: parsedYamlMap)) {
        // The regex that can be used to find the location of the override.
        final dependencyRegex = getDependencyRegEx(
            dependency: dependency, yamlContent: parsedYamlMap);
        final dependencyMatch = dependencyRegex.firstMatch(contents);

        if (dependencyMatch != null) {
          // startPoint is needed because a new line would be added to the
          // top of the patch. This controls whether we need to move the
          // starting line up one or keep it the default.
          int startPoint = dependencyMatch.start;

          if (sourceFile.getLine(dependencyOverrideSectionKey.end) !=
              sourceFile.getLine(dependencyMatch.start - 1)) {
            startPoint = dependencyMatch.start - 1;
          }

          yield Patch(sourceFile,
              sourceFile.span(startPoint, dependencyMatch.end), overrideString);
        }
      } else {
        int insertionOffset;
        int insertionLine;

        // If the section already exists, insert new dependencies directly
        // below the key. If not, insert at the end of the file.
        if (dependencyOverrideSectionKey != null) {
          insertionLine =
              sourceFile.getLine(dependencyOverrideSectionKey.end) + 1;
        } else {
          insertionLine = sourceFile.lines - 1;
        }

        insertionOffset = sourceFile.getOffset(insertionLine);

        if (!shouldAddDependencyOverrideKey) {
          yield Patch(
              sourceFile,
              sourceFile.span(insertionOffset, insertionOffset),
              '$overrideString');
        } else {
          yield Patch(
              sourceFile,
              sourceFile.span(insertionOffset, insertionOffset),
              '\n'
              'dependency_overrides:\n'
              '$overrideString');

          shouldAddDependencyOverrideKey = false;
        }
      }
    }
  }

  @override
  bool shouldSkip(_) => false;
}

bool fileContainsDependencyOverride(
    {@required String dependency, @required YamlMap yamlContent}) {
  if (yamlContent == null) return false;

  if (yamlContent['dependency_overrides'] != null) {
    if (yamlContent['dependency_overrides'][dependency] != null) {
      return true;
    }
  }

  return false;
}

// Method that builds the RegEx that will match the dependency in the pubspec.
RegExp getDependencyRegEx(
    {@required String dependency, @required YamlMap yamlContent}) {
  if (yamlContent == null) throw Exception('Invalid yaml content');

  if (yamlContent['dependency_overrides'] != null) {
    if (yamlContent['dependency_overrides'][dependency] != null) {
      // If the override uses git
      if (yamlContent['dependency_overrides'][dependency]['git'] != null) {
        // A git override can either use a ref to refer to a specific branch,
        // or default to master by not specifying a particular ref.
        if (yamlContent['dependency_overrides'][dependency]['git']['ref'] !=
            null) {
          return RegExp(
              r'''^\s*(''' +
                  dependency +
                  r'''):\s*git:\s*url:\s*(.+)\s*ref:\s*(.+)$''',
              multiLine: true);
        } else {
          return RegExp(
              r'''^\s*(''' + dependency + r'''):\s+git:\s+url:\s*(.+)$''',
              multiLine: true);
        }

        // If the override uses path.
      } else if (yamlContent['dependency_overrides'][dependency]['path'] !=
          null) {
        return RegExp(r'''^\s*(''' + dependency + r'''):\s+path:\s+(.+)$''',
            multiLine: true);

        // If this is the case then the override is simply specifying a new
        // version.
      } else {
        return RegExp(r'''^\s*''' + dependency + r''':\s*(["']?)(.+)\1\s*$''',
            multiLine: true);
      }
    }
  }

  throw Exception('Unable to determine dependency override structure.');
}

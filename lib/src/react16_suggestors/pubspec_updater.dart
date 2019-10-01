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
import 'package:over_react_codemod/src/creator_utils.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:source_span/source_span.dart';
import 'package:yaml/yaml.dart';

import '../constants.dart';
import '../util.dart';

/// Suggestor that attempts to update `pubspec.yaml` files to ensure a safe
/// minimum bound on the `react` dependency.
///
/// If `react` is already listed, but the minimum bound is not high enough,
/// the version constraint will be updated. If `react` is missing from
/// the file, it will be added.
class PubspecUpdater implements Suggestor {
  /// Constraint to update/add.
  final List<DependencyCreator> targets;

  YamlMap parsedYamlMap;
  Set<String> sectionsFound = {};

  /// if it should add or not based on current value
  bool Function(List<DependencyCreator> currentVal, DependencyCreator targetVal, List sectionsFound) shouldAdd;

  bool Function(DependencyCreator currentVal, DependencyCreator targetVal, List sectionsFound) shouldUpdate;

  PubspecUpdater(this.targets,
      {this.shouldAdd, this.shouldUpdate}) {
        if (shouldUpdate == null) shouldUpdate =(_,__,___) => true;
        if (shouldAdd== null) shouldAdd =(_,__,___) => true;
      }

  @override
  Iterable<Patch> generatePatches(SourceFile sourceFile) sync* {
    final contents = sourceFile.getText(0);

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

    if (parsedYamlMap == null || parsedYamlMap.isEmpty){
      parsedYamlMap = YamlMap();
    }


    Map<String, List<DependencyCreator>> targetsBySection = {};

    for(var target in targets) {
      if (targetsBySection[target.section] == null) {
        targetsBySection[target.section] = [];
      }
      targetsBySection[target.section].add(target);
    }

    for(var section in targetsBySection.entries) {
      if (parsedYamlMap.keys.toList().contains(section.key)) {

        for (var target in section.value) {
          List<DependencyCreator> existingDeps = findExisting(target.name, parsedYamlMap);
          if (existingDeps != null && existingDeps.isNotEmpty) {
            for(var dependency in existingDeps) {
              print('should we update?');
              if (!shouldUpdate(dependency, target, parsedYamlMap.keys.toList())) continue;
              print('updating');
              // We need to update some stuff
              var updatePatch = updateDependency(dependency: dependency, target: target, sourceFile: sourceFile);
              if (updatePatch != null) yield updatePatch;
            }
          }
          if (shouldAdd(existingDeps, target, parsedYamlMap.keys.toList())){
            print('adding');
            var addPatch = addDependency(target, sourceFile);
            if (addPatch != null) yield addPatch;
          }
        }
      } else {
        if (shouldAdd([], null, parsedYamlMap.keys.toList())) {
          var sectionPatch = addSection(section.key, targets, sourceFile);
          if (sectionPatch != null) yield sectionPatch;
        }
      }
    }
  }


  List<DependencyCreator> findExisting(String dependencyName, YamlMap yamlMap) {
    List<DependencyCreator> found = [];

    if (yamlMap == null) return found;

    List<String> sectionsToCheck = [
      'dependencies',
      'dev_dependencies',
      'dependency_overrides',
    ];

    for(var section in sectionsToCheck){
      if (yamlMap[section] != null) {
        if (yamlMap[section][dependencyName] != null) {
          if (yamlMap[section][dependencyName] is String) {
            found.add(DependencyCreator(
              dependencyName,
              version: yamlMap[section][dependencyName],
              isDev: section.contains('dev'),
            ));
          } else if (yamlMap[section][dependencyName] is Map) {
            print('git?');
            if (yamlMap[section][dependencyName]['git'] != null) {
              found.add(DependencyCreator(
                  dependencyName,
                  gitOverride: yamlMap[section][dependencyName]['git']['url'] ?? '',
                  ref: yamlMap[section][dependencyName]['git']['ref'],
              ));
            } else if (yamlMap[section][dependencyName]['path'] != null) {
              found.add(DependencyCreator(
                  dependencyName,
                  pathOverride: yamlMap[section][dependencyName]['path'] ?? '',
              ));
            }
          }
        }
      }
    }
    return found;
  }

  Patch addSection(String section, List<DependencyCreator> dependencies, SourceFile sourceFile) {
    var insertionOffset = sourceFile.length;
    print('\n${section}:\n${dependencies.join("")}');
    return Patch(
        sourceFile,
        sourceFile.span(insertionOffset, insertionOffset),
        '\n${section}:\n'+
        dependencies.join("")
      );
  }

  Patch addDependency(DependencyCreator dependency, SourceFile sourceFile) {
      var section = parsedYamlMap.nodes[dependency.section];
      String newVersion = '$dependency';
      var thePatch = Patch(
        sourceFile,
        sourceFile.span(section.span.start.offset-2, section.span.start.offset-2),
        '$newVersion\n',
      );
      print(thePatch.renderDiff(7));
      return thePatch;
  }

  VersionRange generateNewVersionRange(VersionRange currentRange, VersionRange targetRange) {
    String versionRange;

    if (currentRange.min > targetRange.min) {
      versionRange = '>=${currentRange.min.toString()}';
    } else {
      versionRange = '>=${targetRange.min.toString()}';
    }

    if (targetRange.max != null) {
      versionRange += ' <${targetRange.max.toString()}';
    }

    return VersionConstraint.parse(versionRange);
  }

  Patch updateDependency({DependencyCreator dependency, DependencyCreator target, SourceFile sourceFile}) {
      var section = (parsedYamlMap.nodes[dependency.section] as YamlMap);

      if (!dependency.isOverride) {
        var dependencyMatchVersion = (VersionConstraint.parse(section.nodes[dependency.name].span.text.replaceAll(RegExp('[\'\"]+'), '')) as VersionRange);
        var dependencyTargetVersion = (VersionConstraint.parse(target.version) as VersionRange);
        target = DependencyCreator(target.name, version: generateNewVersionRange(dependencyMatchVersion, dependencyTargetVersion).toString());
      }

      String newVersion = '${target.versionForOutput(versionPrefix: '', overridePrefix: '', includeInitalIndent: false)}';

      var thePatch = Patch(
            sourceFile,
            sourceFile.span(
              section.nodes[dependency.name].span.start.offset,
              section.nodes[dependency.name].span.end.offset,
            ),
            newVersion
          );
      print(thePatch.renderDiff(7));
      return thePatch;
  }

  @override
  bool shouldSkip(_) => false;
}

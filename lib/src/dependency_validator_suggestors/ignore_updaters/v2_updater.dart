// Copyright 2021 Workiva Inc.
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
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

/// Handles adding a dependency to the ignore list of a `dependency_validator` pubspec.yaml
/// configuration.
///
/// Example:
/// ```
/// // Before
/// dependency_validator:
///   exclude:
///     - "app/**"
///
/// // After (with [dependency] equal to `a_dependency`)
/// dependency_validator:
///   exclude:
///     - "app/**"
///   ignore:
///     - a_dependency
/// ```
///
/// See: [dependency_validator V2](https://github.com/Workiva/dependency_validator/blob/40e148b78ccb667c633f9b0e7044da10df18052c/README.md)
class V2DependencyValidatorUpdater {
  String dependency;

  V2DependencyValidatorUpdater(this.dependency);

  Stream<Patch> call(FileContext context) async* {
    final pubspec = YamlEditor(context.sourceText);
    const dependencyValidatorKey = 'dependency_validator';
    const ignoreKey = 'ignore';

    final currentDependencyValidatorConfig =
        pubspec.parseAt([dependencyValidatorKey], orElse: () => YamlMap()).value
            as YamlMap;
    if (currentDependencyValidatorConfig.isNotEmpty) {
      // This case adds to an existing ignore list
      if (currentDependencyValidatorConfig.keys.contains(ignoreKey)) {
        final ignoreListNode =
            pubspec.parseAt([dependencyValidatorKey, ignoreKey]);
        final ignoreList = ignoreListNode.value as YamlList;

        if (ignoreList.contains(dependency)) return;
        pubspec.appendToList([dependencyValidatorKey, ignoreKey], dependency);
        yield Patch(pubspec.toString(), 0);

        // This case adds to any config that does not have an ignore list
      } else {
        pubspec.update(
          [dependencyValidatorKey, ignoreKey],
          [dependency],
        );
        yield Patch(pubspec.toString(), 0);
      }
      // If there is no existing "dependency_validator" tag, `YamlEdit` cannot add one, so
      // we just add a new "dependency_validator" config to the end of the file
    } else {
      var prependNewLine = true;

      if (context.sourceFile.length == 0) prependNewLine = false;

      yield Patch(
          '${prependNewLine ? '\n' : ''}$dependencyValidatorKey:\n  $ignoreKey:\n    - $dependency\n',
          context.sourceFile.length);
    }
  }
}

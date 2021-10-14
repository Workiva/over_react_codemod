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

/// Handles adding a dependency to the ignore list of a `dependency_validator` yaml
/// configuration.
///
/// Example:
/// ```
/// // Before
/// exclude:
///   - "app/**"
///
/// // After (with `dependency` equal to "a_dependency")
/// exclude:
///   - "app/**"
/// ignore:
///   - a_dependency
/// ```
///
/// See: [dependency_validator V3](https://github.com/Workiva/dependency_validator/blob/a296309ad75741215d19d2186e71c1a2406507ab/README.md)
class V3DependencyValidatorUpdater {
  String dependency;

  V3DependencyValidatorUpdater(this.dependency);

  Stream<Patch> call(FileContext context) async* {
    final config = YamlEditor(context.sourceText);
    const ignoreKey = 'ignore';

    final currentIgnoreList =
        config.parseAt([ignoreKey], orElse: () => YamlList()).value as YamlList;

    if (currentIgnoreList.isNotEmpty) {
      if (currentIgnoreList.contains(dependency)) return;

      config.appendToList([ignoreKey], dependency);
      yield Patch(config.toString(), 0);
    } else {
      yield Patch('$ignoreKey:\n  - $dependency\n', context.sourceFile.length);
    }
  }
}

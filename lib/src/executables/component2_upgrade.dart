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

import 'dart:io';

import 'package:codemod/codemod.dart';
import 'package:over_react_codemod/src/component2_suggestors/class_name_and_annotation_migrator.dart';
import 'package:over_react_codemod/src/component2_suggestors/componentdidupdate_migrator.dart';
import 'package:over_react_codemod/src/component2_suggestors/componentwillmount_migrator.dart';
import 'package:over_react_codemod/src/component2_suggestors/deprecated_lifecycle_suggestor.dart';
import 'package:over_react_codemod/src/component2_suggestors/setstate_updater.dart';
import 'package:over_react_codemod/src/component2_suggestors/copyunconsumeddomprops_migrator.dart';

const _upgradeAbstractComponentsFlag = '--upgrade-abstract-components';
const _changesRequiredOutput = """
To update your code, switch to Dart 2.1.0 and run the following commands:
  pub global activate over_react_codemod ^1.1.0
  pub global run over_react_codemod:component2_upgrade
Then, review the the changes, address any FIXMEs, and commit.
""";

void main(List<String> args) {
  final shouldUpgradeAbstractComponents = args.contains(_upgradeAbstractComponentsFlag);
  args.removeWhere((arg) => arg == _upgradeAbstractComponentsFlag);

  final query = FileQuery.dir(
    pathFilter: isDartFile,
    recursive: true,
  );
  exitCode = runInteractiveCodemodSequence(
    query,
    [
      // This suggestor needs to be run first in order for subsequent suggestors
      // to run when converting Component to Component2 for the first time.
      ClassNameAndAnnotationMigrator(shouldUpgradeAbstractComponents: shouldUpgradeAbstractComponents),
      ComponentWillMountMigrator(shouldUpgradeAbstractComponents: shouldUpgradeAbstractComponents),
      DeprecatedLifecycleSuggestor(shouldUpgradeAbstractComponents: shouldUpgradeAbstractComponents),
      SetStateUpdater(shouldUpgradeAbstractComponents: shouldUpgradeAbstractComponents),
      ComponentDidUpdateMigrator(shouldUpgradeAbstractComponents: shouldUpgradeAbstractComponents),
      CopyUnconsumedDomPropsMigrator(shouldUpgradeAbstractComponents: shouldUpgradeAbstractComponents),
    ],
    args: args,
    defaultYes: true,
    changesRequiredOutput: _changesRequiredOutput,
  );
}

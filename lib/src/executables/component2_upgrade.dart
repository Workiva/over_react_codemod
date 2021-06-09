// @dart=2.7
// ^ Do not remove until migrated to null safety. More info at https://wiki.atl.workiva.net/pages/viewpage.action?pageId=189370832
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
import 'package:over_react_codemod/src/component2_suggestors/defaultprops_initialstate_migrator.dart';
import 'package:over_react_codemod/src/component2_suggestors/deprecated_lifecycle_suggestor.dart';
import 'package:over_react_codemod/src/component2_suggestors/setstate_updater.dart';
import 'package:over_react_codemod/src/component2_suggestors/copyunconsumeddomprops_migrator.dart';
import 'package:over_react_codemod/src/ignoreable.dart';
import 'package:over_react_codemod/src/util.dart';

const _noPartialUpgradesFlag = '--no-partial-upgrades';
const _upgradeAbstractComponentsFlag = '--upgrade-abstract-components';
const _changesRequiredOutput = """
To update your code, switch to Dart 2.1.0 and run the following commands:
  pub global activate over_react_codemod ^1.1.0
  pub global run over_react_codemod:component2_upgrade
  pub run dart_dev format (If you format this repository).
Then, review the the changes, address any FIXMEs, and commit.
""";

void main(List<String> args) {
  final allowPartialUpgrades = !args.contains(_noPartialUpgradesFlag);
  args.removeWhere((arg) => arg == _noPartialUpgradesFlag);

  final shouldUpgradeAbstractComponents =
      args.contains(_upgradeAbstractComponentsFlag);
  args.removeWhere((arg) => arg == _upgradeAbstractComponentsFlag);

  exitCode = runInteractiveCodemodSequence(
    allDartPathsExceptHiddenAndGenerated(),
    <Suggestor>[
      // This suggestor needs to be run first in order for subsequent suggestors
      // to run when converting Component to Component2 for the first time.
      ClassNameAndAnnotationMigrator(
        allowPartialUpgrades: allowPartialUpgrades,
        shouldUpgradeAbstractComponents: shouldUpgradeAbstractComponents,
      ),
      ComponentWillMountMigrator(
        allowPartialUpgrades: allowPartialUpgrades,
        shouldUpgradeAbstractComponents: shouldUpgradeAbstractComponents,
      ),
      DeprecatedLifecycleSuggestor(
        allowPartialUpgrades: allowPartialUpgrades,
        shouldUpgradeAbstractComponents: shouldUpgradeAbstractComponents,
      ),
      SetStateUpdater(
        allowPartialUpgrades: allowPartialUpgrades,
        shouldUpgradeAbstractComponents: shouldUpgradeAbstractComponents,
      ),
      ComponentDidUpdateMigrator(
        allowPartialUpgrades: allowPartialUpgrades,
        shouldUpgradeAbstractComponents: shouldUpgradeAbstractComponents,
      ),
      CopyUnconsumedDomPropsMigrator(
        allowPartialUpgrades: allowPartialUpgrades,
        shouldUpgradeAbstractComponents: shouldUpgradeAbstractComponents,
      ),
      GetDefaultPropsMigrator(
        allowPartialUpgrades: allowPartialUpgrades,
        shouldUpgradeAbstractComponents: shouldUpgradeAbstractComponents,
      ),
      GetInitialStateMigrator(
        allowPartialUpgrades: allowPartialUpgrades,
        shouldUpgradeAbstractComponents: shouldUpgradeAbstractComponents,
      ),
    ].map((s) => Ignoreable(s)),
    args: args,
    defaultYes: true,
    changesRequiredOutput: _changesRequiredOutput,
  );
}

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
import 'package:over_react_codemod/src/mui_suggestors/components/mui_button_group_migrator.dart';
import 'package:over_react_codemod/src/mui_suggestors/components/mui_button_migrator.dart';
import 'package:over_react_codemod/src/mui_suggestors/components/mui_button_toolbar_migrator.dart';
import 'package:over_react_codemod/src/mui_suggestors/components/mui_inline_alert_migrator.dart';

/// A map of component names to their respective migrators.
///
/// Used to determine which migrators should be run when only a subset of
/// components is being migrated at a time.
final componentMigratorsByName = <String, Suggestor>{
  'Alert': MuiInlineAlertMigrator(),
  'Button': MuiButtonMigrator(),
  'ButtonGroup': MuiButtonGroupMigrator(),
  'ButtonToolbar': MuiButtonToolbarMigrator(),
};

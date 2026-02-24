// Copyright 2026 Workiva Inc.
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
import 'package:over_react_codemod/src/ignoreable.dart';
import 'package:over_react_codemod/src/mui_suggestors/system_props_to_sx_migrator.dart';
import 'package:over_react_codemod/src/util.dart';

void main(List<String> args) async {
  const description = 'Migrates deprecated MUI system props to the `sx` prop,'
      '\nensuring that existing `sx` prop values are preserved and merged correctly.';

  exitCode = await runInteractiveCodemod(
    allDartPathsExceptHidden(),
    aggregate([
      SystemPropsToSxMigrator(),
    ].map((s) => ignoreable(s))),
    defaultYes: true,
    args: args,
    additionalHelpOutput: description,
  );
}

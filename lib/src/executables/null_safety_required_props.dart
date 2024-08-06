// Copyright 2024 Workiva Inc.
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

import 'package:args/command_runner.dart';
import 'package:io/io.dart';
import 'package:over_react_codemod/src/dart3_suggestors/required_props/bin/codemod.dart';
import 'package:over_react_codemod/src/dart3_suggestors/required_props/bin/collect.dart';

void main(List<String> args) async {
  final runner = CommandRunner("null_safety_required_props",
      "Tooling to codemod over_react prop requiredness in preparation for null safety.")
    ..addCommand(CollectCommand())
    ..addCommand(CodemodCommand());

  try {
    await runner.run(args);
  } on UsageException catch (e) {
    print(e);
    exit(ExitCode.usage.code);
  }
}

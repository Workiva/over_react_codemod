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

import 'dart:io';

import 'package:args/args.dart';
import 'package:codemod/codemod.dart';
import 'package:over_react_codemod/src/theme_provider_suggestors/theme_provider_adder.dart';
import 'package:over_react_codemod/src/util.dart';

const _changesRequiredOutput = """
  To update your code, run the following commands in your repository:
  pub global activate over_react_codemod
  pub global run over_react_codemod:wk_theme_provider
""";

const wkTheme = 'wkTheme';

/// Wraps the contents of `react_dom.render` calls in a ThemeProvider with the `wkTheme`.
void main(List<String> args) async {
  final parser = ArgParser.allowAnything();

  final parsedArgs = parser.parse(args);

  final exitCode = await runInteractiveCodemod(
    pubspecYamlPaths(),
    [ThemeProviderAdder(wkTheme)],
    defaultYes: true,
    args: parsedArgs.rest,
    changesRequiredOutput: _changesRequiredOutput,
  );

  exit(exitCode);
}

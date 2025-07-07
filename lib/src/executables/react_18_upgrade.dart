// Copyright 2025 Workiva Inc.
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
import 'package:over_react_codemod/src/ignoreable.dart';
import 'package:over_react_codemod/src/rmui_bundle_update_suggestors/constants.dart';
import 'package:over_react_codemod/src/rmui_bundle_update_suggestors/dart_script_updater.dart';
import 'package:over_react_codemod/src/rmui_bundle_update_suggestors/html_script_updater.dart';
import 'package:over_react_codemod/src/util.dart';
import 'package:over_react_codemod/src/util/pubspec_upgrader.dart';

import '../react_18_upgrade_suggestors/constants.dart';

const _changesRequiredOutput = """
  To update your code, run the following commands in your repository:
  dart pub global activate over_react_codemod
  dart pub global run over_react_codemod:rmui_bundle_update
""";

void main(List<String> args) async {
  final parser = ArgParser.allowAnything();

  final parsedArgs = parser.parse(args);

  // Update react.js bundle files to React 18 versions
  exitCode = await runInteractiveCodemodSequence(
    allHtmlPathsIncludingTemplates(),
    react17to18ReactJsScriptNames.keys.map((key) => HtmlScriptUpdater(key, react17to18ReactJsScriptNames[key]!, updateAttributes: false)),
    defaultYes: true,
    args: parsedArgs.rest,
    additionalHelpOutput: parser.usage,
    changesRequiredOutput: _changesRequiredOutput,
  );

  if (exitCode != 0) return;

  // Remove React 17 react_dom bundle files
  exitCode = await runInteractiveCodemodSequence(
    allHtmlPathsIncludingTemplates(),
    // todo clean up this api
    react17ReactDomJsOnlyScriptNames.map((name) => HtmlScriptUpdater(name, 'abc', removeTag: true)),
    defaultYes: true,
    args: parsedArgs.rest,
    additionalHelpOutput: parser.usage,
    changesRequiredOutput: _changesRequiredOutput,
  );

  if (exitCode != 0) return;

  // Update RMUI bundle script to all Dart files.
  exitCode = await runInteractiveCodemodSequence(
    allDartPathsExceptHidden(),
    [
      DartScriptUpdater(rmuiBundleDev, rmuiBundleDevUpdated),
      DartScriptUpdater(rmuiBundleProd, rmuiBundleProdUpdated),
    ],
    defaultYes: true,
    args: parsedArgs.rest,
    additionalHelpOutput: parser.usage,
    changesRequiredOutput: _changesRequiredOutput,
  );
}

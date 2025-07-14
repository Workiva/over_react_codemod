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
import 'package:over_react_codemod/src/rmui_bundle_update_suggestors/dart_script_updater.dart';
import 'package:over_react_codemod/src/rmui_bundle_update_suggestors/html_script_updater.dart';
import 'package:over_react_codemod/src/util.dart';

const _changesRequiredOutput = """
  To update your code, run the following commands in your repository:
  dart pub global activate over_react_codemod
  dart pub global run over_react_codemod:react_18_upgrade
""";

/// Updates React JS paths in HTML and Dart files from the React 17 versions to the React 18 versions.
void main(List<String> args) async {
  final parser = ArgParser.allowAnything();

  final parsedArgs = parser.parse(args);

  // Work around allowAnything not allowing you to pass flags.
  if (parsedArgs.arguments.contains('--help')) {
    // Print command description; flags and other output will get printed via runInteractiveCodemodSequence.
    print(
        'Updates React JS paths in HTML and Dart files from the React 17 versions to the React 18 versions.\n');
  }

  exitCode = await runInteractiveCodemodSequence(
    allHtmlPathsIncludingTemplates(),
    [
      // Update react.js bundle files to React 18 versions in html files
      ...react17to18ReactJsScriptNames.keys.map((key) => HtmlScriptUpdater(
          key, react17to18ReactJsScriptNames[key]!,
          updateAttributes: false)),
      // Remove React 17 react_dom bundle files in html files
      ...react17ReactDomJsOnlyScriptNames
          .map((name) => HtmlScriptUpdater.remove(name)),
    ],
    defaultYes: true,
    args: parsedArgs.rest,
    additionalHelpOutput: parser.usage,
    changesRequiredOutput: _changesRequiredOutput,
  );

  if (exitCode != 0) return;

  exitCode = await runInteractiveCodemodSequence(
    allDartPathsExceptHidden(),
    [
      // Update react.js bundle files to React 18 versions in Dart files
      ...react17to18ReactJsScriptNames.keys.map((key) => DartScriptUpdater(
          key, react17to18ReactJsScriptNames[key]!,
          updateAttributes: false)),
      // Remove React 17 react_dom bundle files in Dart files
      ...react17ReactDomJsOnlyScriptNames
          .map((name) => DartScriptUpdater.remove(name)),
    ],
    defaultYes: true,
    args: parsedArgs.rest,
    additionalHelpOutput: parser.usage,
    changesRequiredOutput: _changesRequiredOutput,
  );
}

const reactPath = 'packages/react/';

const react17to18ReactJsScriptNames = {
  '${reactPath}react.js': '${reactPath}js/react.dev.js',
  '${reactPath}react_with_addons.js': '${reactPath}js/react.dev.js',
  '${reactPath}react_prod.js': '${reactPath}js/react.min.js',
  '${reactPath}react_with_react_dom_prod.js': '${reactPath}js/react.min.js',
};

const react17ReactDomJsOnlyScriptNames = [
  '${reactPath}react_dom.js',
  '${reactPath}react_dom_prod.js',
];

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
import 'package:over_react_codemod/src/rmui_bundle_suggestors/dart_script_adder.dart';

import 'constants.dart';

/// Suggestor that adds a [scriptToAdd] line after the last usage of a
/// react-dart script in a file.
///
/// Meant to be run on HTML files (use [DartScriptAdder] to run on Dart files).
class HtmlScriptAdder {
  final String scriptToAdd;

  HtmlScriptAdder(this.scriptToAdd);

  Stream<Patch> call(FileContext context) async* {
    // Do not add the script if it already exists in the file.
    if (context.sourceText.contains(scriptToAdd)) return;

    final scriptMatches =
        RegExp(reactJsScriptPattern).allMatches(context.sourceText);

    if (scriptMatches.isNotEmpty) {
      final lastMatch = scriptMatches.last;
      yield Patch(
        // Add the new script with the same indentation as the line before it.
        '\n${lastMatch.group(1)}$scriptToAdd',
        lastMatch.end,
        lastMatch.end,
      );
    }
  }
}

// Copyright 2023 Workiva Inc.
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
import 'package:over_react_codemod/src/rmui_preparation_suggestors/constants.dart';

import 'constants.dart';

/// Suggestor that updates the [existingScriptPath] <script> line to [newScriptPath] and adds `type="module"` attribute to the script tag.
///
/// Meant to be run on HTML files (use [DartScriptUpdater] to run on Dart files).
class HtmlScriptUpdater {
  final String existingScriptPath;
  final String newScriptPath;

  // todo add type="module" to script

  HtmlScriptUpdater(this.existingScriptPath, this.newScriptPath);

  Stream<Patch> call(FileContext context) async* {
    final relevantScriptTags = [
      ...Script(pathSubpattern: existingScriptPath)
          .pattern
          .allMatches(context.sourceText),
      ...Script(pathSubpattern: newScriptPath)
          .pattern
          .allMatches(context.sourceText)
    ];

    // Do not update if neither the existingScriptPath nor newScriptPath are in the file.
    if (relevantScriptTags.isEmpty) return;

    final patches = <Patch>[];

    // Add type="module" attribute to script tag.
    for (final scriptTagMatch in relevantScriptTags) {
      final scriptTag = scriptTagMatch.group(0);
      if (scriptTag == null) continue;
      final typeAttributes = typeAttributePattern.allMatches(scriptTag);
      if (typeAttributes.isNotEmpty) {
        final attribute = typeAttributes.first;
        final value = attribute.group(1);
        if (value == 'module') {
          continue;
        } else {
          // If the value of the type attribute is not "module", overwrite it.
          patches.add(Patch(
            typeModuleAttribute,
            scriptTagMatch.start + attribute.start,
            scriptTagMatch.start + attribute.end,
          ));
        }
      } else {
        // If the type attribute does not exist, add it.
        final srcAttribute = srcAttributePattern.allMatches(scriptTag);
        patches.add(Patch(
          ' ${typeModuleAttribute}',
          scriptTagMatch.start + srcAttribute.first.end,
          scriptTagMatch.start + srcAttribute.first.end,
        ));
      }
    }

    // Update existing path to new path.
    final scriptMatches = existingScriptPath.allMatches(context.sourceText);
    scriptMatches.forEach((match) async {
      patches.add(Patch(
        newScriptPath,
        match.start,
        match.end,
      ));
    });

    yield* Stream.fromIterable(patches);
  }
}

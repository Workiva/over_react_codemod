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

  /// Whether or not to update attributes on script/link tags (like type/crossorigin)
  /// while also updating the script path.
  final bool updateAttributes;
  final bool removeTag;

  HtmlScriptUpdater(this.existingScriptPath, this.newScriptPath,
      {this.updateAttributes = true})
      : removeTag = false;

  /// Use this constructor to remove the whole tag instead of updating it.
  HtmlScriptUpdater.remove(this.existingScriptPath)
      : removeTag = true,
        updateAttributes = false,
        newScriptPath = 'will be ignored';

  Stream<Patch> call(FileContext context) async* {
    final relevantScriptTags = [
      ...Script(pathSubpattern: existingScriptPath)
          .pattern
          .allMatches(context.sourceText),
      ...?(!removeTag
          ? Script(pathSubpattern: newScriptPath)
              .pattern
              .allMatches(context.sourceText)
          : null)
    ];
    final relevantLinkTags = [
      ...Link(pathSubpattern: existingScriptPath)
          .pattern
          .allMatches(context.sourceText),
      ...?(!removeTag
          ? Link(pathSubpattern: newScriptPath)
              .pattern
              .allMatches(context.sourceText)
          : null)
    ];

    // Do not update if neither the existingScriptPath nor newScriptPath are in the file.
    if (relevantScriptTags.isEmpty && relevantLinkTags.isEmpty) return;

    final patches = <Patch>[];

    if (removeTag) {
      for (final tag in [...relevantScriptTags, ...relevantLinkTags]) {
        patches.add(Patch(
          '',
          tag.start,
          tag.end,
        ));
      }
    } else {
      if (updateAttributes) {
        // Add type="module" attribute to script tag.
        for (final scriptTagMatch in relevantScriptTags) {
          final scriptTag = scriptTagMatch.group(0);
          if (scriptTag == null) continue;
          final typeAttributes =
              getAttributePattern('type').allMatches(scriptTag);
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
            final srcAttribute =
                getAttributePattern('src').allMatches(scriptTag);
            patches.add(Patch(
              ' ${typeModuleAttribute}',
              scriptTagMatch.start + srcAttribute.first.end,
              scriptTagMatch.start + srcAttribute.first.end,
            ));
          }
        }

        // Add crossorigin="" attribute to link tag.
        for (final linkTagToMatch in relevantLinkTags) {
          final linkTag = linkTagToMatch.group(0);
          if (linkTag == null) continue;
          final crossOriginAttributes =
              getAttributePattern('crossorigin').allMatches(linkTag);
          if (crossOriginAttributes.isNotEmpty) {
            final attribute = crossOriginAttributes.first;
            final value = attribute.group(1);
            if (value == '') {
              continue;
            } else {
              // If the value of the crossorigin attribute is not "", overwrite it.
              patches.add(Patch(
                crossOriginAttribute,
                linkTagToMatch.start + attribute.start,
                linkTagToMatch.start + attribute.end,
              ));
            }
          } else {
            // If the crossorigin attribute does not exist, add it.
            final hrefAttribute =
                getAttributePattern('href').allMatches(linkTag);
            patches.add(Patch(
              ' ${crossOriginAttribute}',
              linkTagToMatch.start + hrefAttribute.first.end,
              linkTagToMatch.start + hrefAttribute.first.end,
            ));
          }
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
    }

    yield* Stream.fromIterable(patches);
  }
}

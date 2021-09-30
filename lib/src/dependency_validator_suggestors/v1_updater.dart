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

class V1DependencyValidatorUpdater {
  final String dependency;

  V1DependencyValidatorUpdater(this.dependency);

  Stream<Patch> call(FileContext context) async* {
    final fileContent = context.sourceText;

    const command = 'pub run dependency_validator';

    final commandPattern = RegExp('$command(.*)');
    final ignoreArgPattern = RegExp(r"(?:-i ?|--ignore[= ])([^ ']+)");

    final commandMatch = commandPattern.allMatches(fileContent);

    final patches = <Patch>[];

    // There may be multiple matches within a single file
    commandMatch.forEach((match) {
      final allArgs = match.group(1)!;
      final commandArgsStart = match.start + command.length;
      final ignoreArgMatches = ignoreArgPattern.allMatches(allArgs);

      if (ignoreArgMatches.length > 1) {
        final lineStart = context.sourceFile
            .getOffset(context.sourceFile.getLine(match.start));
        patches.add(Patch(
            '//FIXME: unexpected outcome; there should only be one ignore argument\n',
            lineStart,
            lineStart));
        return;
      } else if (ignoreArgMatches.length == 1) {
        var ignoreArgMatch = ignoreArgMatches.first.group(1);

        if (ignoreArgMatch == null) {
          throw StateError(
              'Expected a regex matching group when parsing $allArgs');
        }

        final dependenciesListOffset =
            ignoreArgMatches.first.group(0)!.indexOf(ignoreArgMatch);

        if (ignoreArgMatch.contains(dependency)) {
          return;
        }

        if (ignoreArgMatch.endsWith(',')) {
          ignoreArgMatch += '$dependency';
        } else {
          ignoreArgMatch += ',$dependency';
        }

        // commandArgsStart is where the any arguments will start being added to the command
        // ignoreArgMatches.first.start is where (within the command string) the ignore argument starts
        // dependenciesListOffset is to account for the arg flag (-i or --ignore)
        final startingOffset = commandArgsStart +
            ignoreArgMatches.first.start +
            dependenciesListOffset;
        patches.add(Patch(ignoreArgMatch, startingOffset,
            commandArgsStart + ignoreArgMatches.first.end));
        return;
      } else {
        // This will inject the ignore arg right after the command itself, rather
        // at the end of existing args, because our regex is greedy and doesn't really
        // know when the command args end. Therefore the safest thing when there is no
        // existing ignore arg is to use the command string as the anchor.
        patches
            .add(Patch(' -i $dependency', commandArgsStart, commandArgsStart));
      }
    });

    for (final patch in patches) {
      yield patch;
    }
  }
}

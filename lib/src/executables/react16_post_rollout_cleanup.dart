// @dart=2.7
// ^ Do not remove until migrated to null safety. More info at https://wiki.atl.workiva.net/pages/viewpage.action?pageId=189370832
// Copyright 2019 Workiva Inc.
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
import 'package:glob/glob.dart';
import 'package:logging/logging.dart';
import 'package:over_react_codemod/src/dart2_suggestors/pubspec_over_react_upgrader.dart';
import 'package:over_react_codemod/src/react16_suggestors/comment_remover.dart';
import 'package:over_react_codemod/src/react16_suggestors/pubspec_react_upgrader.dart';
import 'package:over_react_codemod/src/react16_suggestors/react16_utilities.dart';
import 'package:pub_semver/pub_semver.dart';

const _changesRequiredOutput = """
  To update your code, run the following commands in your repository:
  pub global activate over_react_codemod
  pub global run over_react_codemod:react16_post_rollout_cleanup
  pub run dart_dev format (if you format this repository).
  Then, review the the changes, address any FIXMEs, and commit.
""";

void main(List<String> args) {
  final reactVersionConstraint = VersionConstraint.parse('^5.1.0');
  final overReactVersionConstraint = VersionConstraint.parse('^3.1.3');
  final logger = Logger('over_react_codemod.fixmes');

  // Strings that correlate to the React 16 comments' beginning and end. Based
  // on the pattern used for the React 16 update, the comments should always
  // have these strings.
  const startingString = 'Check this box';
  const endingString = 'complete';

  final query = filePathsFromGlob(Glob('**.dart', recursive: true));

  if (hasUnaddressedReact16Comment(query, logger: logger)) {
    logger.severe(
        'There are still unaddressed comments from the React 16 upgrade codemod. '
        'These should be addressed before cleanup is attempted.');
    exitCode = 1;
    return;
  }

  final pubspecYamlQuery =
      filePathsFromGlob(Glob('**pubspec.yaml', recursive: true));

  exitCode = runInteractiveCodemod(
    pubspecYamlQuery,
    AggregateSuggestor([
      PubspecReactUpdater(reactVersionConstraint, shouldAddDependencies: false),
      PubspecOverReactUpgrader(overReactVersionConstraint,
          shouldAddDependencies: false),
    ]),
    args: args,
    defaultYes: true,
    changesRequiredOutput: _changesRequiredOutput,
  );

  if (exitCode != 0) return;

  exitCode = runInteractiveCodemodSequence(
    query,
    [CommentRemover(startingString, endingString)],
    args: args,
    defaultYes: true,
    changesRequiredOutput: _changesRequiredOutput,
  );
}

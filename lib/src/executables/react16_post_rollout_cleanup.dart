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
import 'package:over_react_codemod/src/react16_suggestors/constants.dart';
import 'package:over_react_codemod/src/dart2_suggestors/pubspec_over_react_upgrader.dart';
import 'package:over_react_codemod/src/react16_suggestors/comment_remover.dart';
import 'package:over_react_codemod/src/react16_suggestors/pubspec_react_upgrader.dart';
import 'package:over_react_codemod/src/react16_suggestors/react16_utilities.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import '../react16_suggestors/constants.dart';

const _changesRequiredOutput = """
  To update your code, run the following commands in your repository:
  pub global activate over_react_codemod
  pub global run over_react_codemod:react16_post_rollout_cleanup
  pub run dart_dev format (if you format this repository).
Then, review the the changes, address any FIXMEs, and commit.
""";

void main(List<String> args) {
  final reactVersionConstraint = VersionConstraint.parse('^5.1.0');
  final overReactVersionConstraint = VersionConstraint.parse('^3.1.0');

  final query = FileQuery.dir(
    pathFilter: isDartFile,
    recursive: true,
  );

  if (hasUnaddressedReact16Comment(query)) {
    throw Exception('There are still unaddressed comments from the '
        'React 16 upgrade codemod. These should be addressed before cleaup is'
        ' attempted.');
  }

  final pubspecYamlQuery = FileQuery.dir(
    pathFilter: (path) => p.basename(path) == 'pubspec.yaml',
    recursive: true,
  );

  exitCode = runInteractiveCodemod(
    pubspecYamlQuery,
    AggregateSuggestor([
      PubspecReactUpdater(reactVersionConstraint, shouldAddDependencies: false),
      PubspecOverReactUpgrader(overReactVersionConstraint,
          shouldAddDependencies: false)
    ]),
    args: args,
    defaultYes: true,
    changesRequiredOutput: _changesRequiredOutput,
  );

  if (exitCode != 0) return;

  exitCode = runInteractiveCodemodSequence(
    query,
    [
      CommentRemover(react16CommentsToRemove),
    ],
    args: args,
    defaultYes: true,
    changesRequiredOutput: _changesRequiredOutput,
  );
}

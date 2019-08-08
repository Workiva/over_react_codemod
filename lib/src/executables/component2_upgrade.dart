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
import 'package:over_react_codemod/src/component2_suggestors/class_name_and_annotation_migrator.dart';
import 'package:over_react_codemod/src/component2_suggestors/componentdidupdate_migrator.dart';
import 'package:over_react_codemod/src/component2_suggestors/componentwillmount_migrator.dart';

const _changesRequiredOutput = """
To update your code, switch to Dart 2.1.0 and run the following commands:
  pub global activate over_react_codemod ^1.1.0
  pub global run over_react_codemod:component2_upgrade
Then, review the the changes, address any FIXMEs, and commit.
""";

void main(List<String> args) {
  final query = FileQuery.dir(
    pathFilter: isDartFile,
    recursive: true,
  );
  exitCode = runInteractiveCodemodSequence(
    query,
    [
      ClassNameAndAnnotationMigrator(),
      ComponentWillMountMigrator(),
      ComponentDidUpdateMigrator(),
    ],
    args: args,
    defaultYes: true,
    changesRequiredOutput: _changesRequiredOutput,
  );

//  // TODO write tests
//  final logger = Logger('over_react_codemod.fixmes');
//  for (var dartFile in query.generateFilePaths()) {
//    final dartSource = File(dartFile).readAsStringSync();
//    if (dartSource.contains(fixmePrefix)) {
//      logger.severe('Unaddressed over_react_codemod FIXME within $dartSource');
//      exitCode = 1;
//    }
//  }
}

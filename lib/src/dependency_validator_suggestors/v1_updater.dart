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

class V1DepdendencyValidatorUpdater {
  Stream<Patch> call(FileContext context) async* {
    // print('searching ${context.path}');
    final fileContent = context.sourceText;
    final dependencyValidatorRunCommand =
        // RegExp('(pub run dependency_validator)(.*)((-i|--ignore) (([a-z\_])+[,]{0,1})+){0,1}');
    RegExp('(pub run dependency_validator)(.*)?((-i|--ignore) (([a-z\_])+[,]{0,1})+){0,1}');

    if (dependencyValidatorRunCommand.hasMatch(fileContent)) {
      final matches = dependencyValidatorRunCommand.allMatches(fileContent);
      // final command

      // print(matches?.group(0));
      matches.forEach((element) {
        print(element.groupCount);
        print(element.group(0));
        print(element.group(1));
        print(element.group(2));
        print(element.group(3));
        print(element.group(5));

        // print(element.groupNames);
        // print(element.namedGroup(element.groupNames.first));
      });

      return;
    }
  }
}

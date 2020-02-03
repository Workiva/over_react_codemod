// Copyright 2020 Workiva Inc.
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

import 'package:over_react_codemod/src/boilerplate_suggestors/props_and_state_classes_simple_migrator.dart';
import 'package:test/test.dart';

import '../util.dart';

void main() {
  group('PropsAndStateClassesSimpleMigrator', () {
    final testSuggestor =
        getSuggestorTester(PropsAndStateClassesSimpleMigrator());

    test('empty file', () {
      testSuggestor(expectedPatchCount: 0, input: '');
    });

    test('no matches', () {
      testSuggestor(
        expectedPatchCount: 0,
        input: '''
        library foo;
        var a = 'b';
        class Foo {}
      ''',
      );
    });
  });
}
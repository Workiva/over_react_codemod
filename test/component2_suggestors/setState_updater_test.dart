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

import 'package:over_react_codemod/src/component2_suggestors/setstate_updater.dart';
import 'package:test/test.dart';

import '../util.dart';

main() {
  group('SetStateUpdater updates correctly when there', () {
    final testSuggestor = getSuggestorTester(SetStateUpdater());

    test('is an empty file', () {
      testSuggestor(expectedPatchCount: 0, input: '');
    });

    test('are no matches', () {
      testSuggestor(
        expectedPatchCount: 0,
        input: '''
          library foo;
          var a = 'b';
          class Foo {}
        ''',
      );
    });

    group('is a function expression', () {
      test('', () {
        testSuggestor(expectedPatchCount: 1, input: '''
          main() {
            setState((prevState, props) {
              // return ...;
            });
          }
        ''', expectedOutput: '''
          main() {
            setStateWithUpdater((prevState, props) {
              // return ...;
            });
          }
        ''');
      });

      test('using arrow notation', () {
        testSuggestor(expectedPatchCount: 1, input: '''
          main() {
            setState((prevState, props) => newState());
          }
        ''', expectedOutput: '''
          main() {
            setStateWithUpdater((prevState, props) => newState());
          }
        ''');
      });
    });
  });
}
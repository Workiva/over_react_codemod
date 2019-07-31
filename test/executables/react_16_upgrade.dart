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

@TestOn('vm')

import 'dart:io';
import 'package:test/test.dart';

ProcessResult runUpgrade({String onDirectory}) {
  Process.runSync('pub', ['get'], workingDirectory: onDirectory);

  return Process.runSync('pub', ['run', 'over_react_codemod:react16_upgrade'],
      workingDirectory: onDirectory);
}

main() {
  group('React_16_upgrade', () {
    test('exits with a status of 1 when there is a comment', () {
      final result = runUpgrade(
          onDirectory: 'test/executables/test_components/file_with_comment');

      expect(result.exitCode, equals(1));
    });

    group('exits with a status of 0 when', () {
      test('there is no comment', () {
        final result = runUpgrade(
            onDirectory: 'test/executables/test_component'
                's/file_with_no_comment');

        expect(result.exitCode, equals(0));
      });

      test('there is a validated comment', () {
        final result = runUpgrade(
            onDirectory: 'test/executables/test_component'
                's/file_with_validated_comment');

        expect(result.exitCode, equals(0));
      });
    });
  });
}

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
  // This command is equivalent to `pub run over_react_codemod:react16_upgrade`
  // but allows us to not need to run pub get on each of these fake packages because over_react/react.dart have not been
  // released yet these tests will fail a pub get
  return Process.runSync(
      'dart', ['--enable-asserts', '../../../../bin/react16_upgrade.dart'],
      workingDirectory: onDirectory);
}

main() {
  group('React16_upgrade', () {
    group('exits with a status of 1 when', () {
      test('there is a comment', () {
        final result = runUpgrade(
            onDirectory: 'test/executables/test_components/file_with_comment');

        expect(result.exitCode, equals(1));
      });
    });

    group('exits with a status of 0 when', () {
      test('there is no comment', () {
        final result = runUpgrade(
            onDirectory:
                'test/executables/test_components/file_with_no_comment');

        expect(result.exitCode, equals(0));
      });

      test('there is a validated comment', () {
        final result = runUpgrade(
            onDirectory:
                'test/executables/test_components/file_with_validated_comment');

        expect(result.exitCode, equals(0));
      });

      test('the version is not in transition', () {
        final result = runUpgrade(
            onDirectory:
                'test/executables/test_components/package_without_match');

        expect(result.exitCode, equals(0));
      });

      test('a version of react is in transition', () {
        final result = runUpgrade(
            onDirectory:
                'test/executables/test_components/package_with_react_match');

        expect(result.exitCode, equals(0));
      });

      test('a version of over_react is in transition', () {
        final result = runUpgrade(
            onDirectory:
                'test/executables/test_components/package_with_over_react_match');

        expect(result.exitCode, equals(0));
      });

      test('pubspec.yaml has neither react or over_react deps', () {
        final result = runUpgrade(
            onDirectory:
                'test/executables/test_components/package_without_either_package');

        expect(result.exitCode, equals(0));
      });

      test('a package does not have a pubspec.yaml', () {
        final result = runUpgrade(
            onDirectory:
                'test/executables/test_components/package_without_pubspec');

        expect(result.exitCode, equals(0));
      });
    });
  });
}

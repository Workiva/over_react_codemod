// Copyright 2024 Workiva Inc.
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

import 'package:over_react_codemod/src/util/args.dart';
import 'package:test/test.dart';

void main() {
  group('argument utilties', () {
    void sharedTest({
      required List<String> getArgsToRemove(),
      required List<String> removeArgs(List<String> args),
    }) {
      final args = [
        '--other-option-1=1',
        '--other-option-2',
        '2',
        '--other-flag',
        ...getArgsToRemove(),
        'positional'
      ];
      final expectedArgs = [
        '--other-option-1=1',
        '--other-option-2',
        '2',
        '--other-flag',
        'positional'
      ];
      expect(removeArgs(args), expectedArgs);
    }

    group('removeOptionArgs', () {
      group('removes options that match the given names', () {
        group('when the args use', () {
          test('= syntax', () {
            sharedTest(
              getArgsToRemove: () => ['--test-option=value'],
              removeArgs: (args) => removeOptionArgs(args, ['test-option']),
            );
          });

          test('multi-argument syntax', () {
            sharedTest(
              getArgsToRemove: () => ['--test-option', 'value'],
              removeArgs: (args) => removeOptionArgs(args, ['test-option']),
            );
          });
        });

        test('when there are multiple matching options of the same name', () {
          sharedTest(
            getArgsToRemove: () =>
                ['--test-option', 'value1', '--test-option', 'value2'],
            removeArgs: (args) => removeOptionArgs(args, ['test-option']),
          );
        });

        test('when multiple names are specified', () {
          sharedTest(
            getArgsToRemove: () =>
                ['--test-option-1', 'value', '--test-option-2', 'value'],
            removeArgs: (args) =>
                removeOptionArgs(args, ['test-option-1', 'test-option-2']),
          );
        });
      });
    });

    group('removeFlagArgs', () {
      group('removes flags that match the given names', () {
        test('', () {
          sharedTest(
            getArgsToRemove: () => ['--test-flag'],
            removeArgs: (args) => removeFlagArgs(args, ['test-flag']),
          );
        });

        test('when the flags are inverted', () {
          sharedTest(
            getArgsToRemove: () => ['--no-test-flag'],
            removeArgs: (args) => removeFlagArgs(args, ['test-flag']),
          );
        });

        test('when there are multiple matching flags of the same name', () {
          sharedTest(
            getArgsToRemove: () => ['--test-flag', '--test-flag'],
            removeArgs: (args) => removeFlagArgs(args, ['test-flag']),
          );
        });

        test('when multiple names are specified', () {
          sharedTest(
            getArgsToRemove: () => ['--test-flag-1', '--test-flag-2'],
            removeArgs: (args) =>
                removeFlagArgs(args, ['test-flag-1', 'test-flag-2']),
          );
        });
      });
    });
  });
}

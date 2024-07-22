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

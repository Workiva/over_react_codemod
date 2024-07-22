import 'package:args/args.dart';

/// Removes arguments corresponding to options with names [optionArgNames] from args.
///
/// Supports multiple arguments of the same name, and both `=` syntax
/// and value-as-a-separate-argument syntax.
///
/// For example:
/// ```
/// final originalArgs = [
///   // Unrelated arguments
///   '--baz=baz',
///   // Multiple arguments of the same name
///   '--foo=1',
///   '--foo=2',
///   // Value as a separate argument
///   '--bar',
///   'bar',
///   'positionalArg',
/// ];
/// final updatedArgs = removeOptionArgs(originalArgs, ['foo', 'bar']);
/// print(updatedArgs); // ['--baz=baz', positionalArg]
/// ```
List<String> removeOptionArgs(
    List<String> args, Iterable<String> optionArgNames) {
  final updatedArgs = [...args];

  for (final argName in optionArgNames) {
    final argPattern = RegExp(r'^' + RegExp.escape('--$argName') + r'(=|$)');

    int argIndex;
    while ((argIndex = updatedArgs.indexWhere(argPattern.hasMatch)) != -1) {
      final matchingArg = updatedArgs[argIndex];
      if (matchingArg.endsWith('=') && argIndex != updatedArgs.length - 1) {
        updatedArgs.removeRange(argIndex, argIndex + 2);
      } else {
        updatedArgs.removeAt(argIndex);
      }
    }
  }
  return updatedArgs;
}

/// Returns a new ArgParser that redefines arguments supported in codemod's ArgParser,
/// so that they can be forwarded along without consumers needing to use `--`.
///
/// Args are hidden them since codemod will show them in its help content.
ArgParser argParserWithCodemodArgs() => ArgParser()
  ..addFlag('help', abbr: 'h', negatable: false, hide: true)
  ..addFlag('verbose', abbr: 'v', negatable: false, hide: true)
  ..addFlag('yes-to-all', negatable: false, hide: true)
  ..addFlag('fail-on-changes', negatable: false, hide: true)
  ..addFlag('stderr-assume-tty', negatable: false, hide: true);

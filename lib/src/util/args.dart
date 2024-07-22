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

import 'package:args/args.dart';

/// Removes arguments corresponding to options ('--'-prefixed arguments with values)
/// with names [optionArgNames] from args.
///
/// Supports multiple arguments of the same name, and both `=` syntax
/// and value-as-a-separate-argument syntax.
///
/// For example:
/// ```
/// final originalArgs = [
///   // Unrelated options
///   '--baz=baz',
///   // Multiple options of the same name
///   '--foo=1',
///   '--foo=2',
///   // Value as a separate argument
///   '--bar',
///   'bar',
///   'positionalArg',
/// ];
/// final updatedArgs = removeOptionArgs(originalArgs, ['foo', 'bar']);
/// print(updatedArgs); // ['--baz=baz', 'positionalArg']
/// ```
List<String> removeOptionArgs(
    List<String> args, Iterable<String> optionArgNames) {
  return optionArgNames.fold(args, (updatedArgs, argName) {
    return _removeOptionOrFlagArgs(updatedArgs, argName, isOption: true);
  });
}

/// Removes arguments corresponding to flags ('--'-prefixed arguments without values)
/// with names [flagArgNames] from args.
///
/// Supports multiple flags of the same name, and negatable flags (prefixed by 'no-').
///
/// For example:
/// ```
/// final originalArgs = [
///   // Unrelated arguments
///   '--flag-to-keep',
///   // Multiple flags of the same name
///   '--flag-to-remove-1',
///   '--flag-to-remove-1',
///   // Inverted flag the same name
///   '--no-flag-to-remove-2',
///   'positionalArg',
/// ];
/// final updatedArgs = removeOptionArgs(originalArgs, ['flag-to-remove-1', 'flag-to-remove-2']);
/// print(updatedArgs); // ['--flag-to-keep', 'positionalArg']
/// ```
List<String> removeFlagArgs(List<String> args, Iterable<String> flagArgNames) {
  return flagArgNames.fold(args, (updatedArgs, argName) {
    return _removeOptionOrFlagArgs(updatedArgs, argName, isOption: false);
  });
}

List<String> _removeOptionOrFlagArgs(List<String> args, String argName,
    {required bool isOption}) {
  final updatedArgs = [...args];

  final argPattern = isOption
      ? RegExp(r'^--' + RegExp.escape(argName) + r'(=|$)')
      : RegExp(r'^--(?:no-)?' + RegExp.escape(argName) + r'$');

  int argIndex;
  while ((argIndex = updatedArgs.indexWhere(argPattern.hasMatch)) != -1) {
    final matchingArg = updatedArgs[argIndex];
    bool isOptionWithMultiArgSyntax() {
      if (isOption) return false;
      final equalsOrEndGroup = argPattern.firstMatch(matchingArg)![1]!;
      return equalsOrEndGroup != '=';
    }

    if (isOptionWithMultiArgSyntax() && argIndex != updatedArgs.length - 1) {
      updatedArgs.removeRange(argIndex, argIndex + 2);
    } else {
      updatedArgs.removeAt(argIndex);
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

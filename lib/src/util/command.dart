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

import 'dart:io';

Future<String> runCommandAndThrowIfFailed(String command, List<String> args,
    {String? workingDirectory, bool returnErr = false}) async {
  final result =
      await Process.run(command, args, workingDirectory: workingDirectory);

  if (result.exitCode != 0) {
    throw ProcessException(
        command, args, '${result.stdout}${result.stderr}', result.exitCode);
  }

  return ((returnErr ? result.stderr : result.stdout) as String).trim();
}

Future<void> runCommandAndThrowIfFailedInheritIo(
    String command, List<String> args,
    {String? workingDirectory}) async {
  final process = await Process.start(command, args,
      workingDirectory: workingDirectory, mode: ProcessStartMode.inheritStdio);

  final exitCode = await process.exitCode;

  if (exitCode != 0) {
    throw ProcessException(command, args, '', exitCode);
  }
}

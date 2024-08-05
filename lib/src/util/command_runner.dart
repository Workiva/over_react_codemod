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

import 'package:args/command_runner.dart';

extension CommandExtension on Command {
  // Adapted from https://github.com/dart-lang/args/blob/1a24d614423e7861ae2e341bfb19050959cef0cd/lib/command_runner.dart#L283
  //
  // Copyright 2013, the Dart project authors.
  //
  // Redistribution and use in source and binary forms, with or without
  // modification, are permitted provided that the following conditions are
  // met:
  //
  //     * Redistributions of source code must retain the above copyright
  //       notice, this list of conditions and the following disclaimer.
  //     * Redistributions in binary form must reproduce the above
  //       copyright notice, this list of conditions and the following
  //       disclaimer in the documentation and/or other materials provided
  //       with the distribution.
  //     * Neither the name of Google LLC nor the names of its
  //       contributors may be used to endorse or promote products derived
  //       from this software without specific prior written permission.
  //
  // THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
  // "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
  // LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
  // A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
  // OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
  // SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
  // LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
  // DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
  // THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
  // (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
  // OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

  /// Returns the first part of the default string returned by [Command.invocation],
  /// containing the string of nested executables/commands needed to run this command,
  /// without the `<subcommand>` or `arguments` portion.
  String get invocationPrefix => [parentInvocationPrefix, name].join(' ');

  /// Same as [invocationPrefix], but doesn't include the current command.
  String get parentInvocationPrefix => <String>[
        ...parentCommands.map((p) => p.name),
        runner!.executableName,
      ].reversed.join(' ');

  Iterable<Command> get parentCommands sync* {
    final parent = this.parent;
    if (parent == null) return;

    yield parent;
    yield* parent.parentCommands;
  }
}

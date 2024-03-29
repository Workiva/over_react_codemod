// Copyright 2021 Workiva Inc.
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

// Adapted from analyzer 1.7.2's package:analyzer/src/ignore_comments/ignore_info.dart
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

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';

/// Information about analysis `//orcm_ignore:` and `//orcm_ignore_for_file` comments
/// within a source file.
class OrcmIgnoreInfo {
  /// A table mapping line numbers to the ignores for that line.
  final Map<int, List<_Ignore>> _ignoredOnLine = {};

  /// A list containing all of the ignores for the whole file.
  final List<_Ignore> _ignoredForFile = [];

  @override
  String toString() => 'OrcmIgnoreInfo ${{
        '_ignoredOnLine': _ignoredOnLine,
        '_ignoredForFile': _ignoredForFile,
      }}';

  /// Initialize a newly created instance of this class to represent the ignore
  /// comments in the given compilation [unit].
  OrcmIgnoreInfo.forDart(CompilationUnit unit, String content) {
    var lineInfo = unit.lineInfo;
    for (var ignoreComment in unit.ignoreComments) {
      if (ignoreComment.isForFile) {
        _ignoredForFile.addAll(ignoreComment.ignores);
      } else {
        final location = lineInfo.getLocation(ignoreComment.comment.offset);
        var lineNumber = location.lineNumber;
        final beforeMatch = content.substring(
            lineInfo.getOffsetOfLine(lineNumber - 1),
            lineInfo.getOffsetOfLine(lineNumber - 1) +
                location.columnNumber -
                1);
        if (beforeMatch.trim().isEmpty) {
          // The comment is on its own line, so it refers to the next line.
          lineNumber++;
        }
        _ignoredOnLine
            .putIfAbsent(lineNumber, () => [])
            .addAll(ignoreComment.ignores);
      }
    }
  }

  Iterable<_Ignore> _ignoresForLine(int line) sync* {
    yield* _ignoredForFile;
    yield* _ignoredOnLine[line] ?? const [];
  }

  /// Whether the [code] is ignored at the given [line].
  bool ignoredAt(String code, int line) =>
      _ignoresForLine(line).any((ignore) => ignore.ignoresCode(code));

  /// Whether all codes is ignored at the given [line].
  bool allCodesIgnoredAt(int line) =>
      _ignoresForLine(line).any((ignore) => ignore.ignoresAllCodes);
}

/// An ignore for either a single code or for all codes.
abstract class _Ignore {
  /// Whether this ignore applies for the given [code].
  bool ignoresCode(String code);

  /// Whether this ignore everything.
  bool get ignoresAllCodes;

  factory _Ignore.forCode(String code) = _IgnoreForCode;

  factory _Ignore.all() = _IgnoreForAll;
}

class _IgnoreForCode implements _Ignore {
  final String code;

  _IgnoreForCode(this.code);

  @override
  bool ignoresCode(String code) => code == this.code;

  @override
  bool get ignoresAllCodes => false;
}

class _IgnoreForAll implements _Ignore {
  @override
  bool ignoresCode(_) => true;

  @override
  bool get ignoresAllCodes => true;
}

class IgnoreComment {
  final Token comment;
  final List<_Ignore> ignores;
  final bool isForFile;

  IgnoreComment(this.comment, this.ignores) : this.isForFile = false;

  IgnoreComment.forFile(this.comment, this.ignores) : this.isForFile = true;
}

extension on CompilationUnit {
  /// A regular expression for matching 'ignore' comments.  Produces matches
  /// containing 2 groups.  For example:
  ///
  ///     * ['// orcm_ignore: code', 'code']
  ///
  /// Resulting codes may be in a list ('code_1,code2').
  static final RegExp _IGNORE_MATCHER =
      RegExp(r'//+[ ]*orcm_ignore(:(.*))?\s*$', multiLine: true);

  /// A regular expression for matching 'ignore_for_file' comments.  Produces
  /// matches containing 2 groups.  For example:
  ///
  ///     * ['// orcm_ignore_for_file: code', 'code']
  ///
  /// Resulting codes may be in a list ('code_1,code2').
  static final RegExp _IGNORE_FOR_FILE_MATCHER =
      RegExp(r'//[ ]*orcm_ignore_for_file(:(.*))?\s*$', multiLine: true);

  static List<_Ignore> _getIgnoresForMatch(Match match) {
    if (match.group(1) == null) return [_Ignore.all()];

    return match
        .group(2)!
        .split(',')
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .map((name) => _Ignore.forCode(name))
        .toList();
  }

  static Iterable<IgnoreComment> _processPrecedingComments(
      Token currentToken) sync* {
    for (Token? comment = currentToken.precedingComments;
        comment != null;
        comment = comment.next) {
      final lexeme = comment.lexeme;
      var match = _IGNORE_MATCHER.matchAsPrefix(lexeme);
      if (match != null) {
        yield IgnoreComment(comment, _getIgnoresForMatch(match));
      } else {
        match = _IGNORE_FOR_FILE_MATCHER.matchAsPrefix(lexeme);
        if (match != null) {
          yield IgnoreComment.forFile(comment, _getIgnoresForMatch(match));
        }
      }
    }
  }

  /// Return all of the ignore comments in this compilation unit.
  Iterable<IgnoreComment> get ignoreComments sync* {
    var currentToken = beginToken;
    while (currentToken != currentToken.next) {
      yield* _processPrecedingComments(currentToken);
      currentToken = currentToken.next!;
    }
    yield* _processPrecedingComments(currentToken);
  }
}

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

import 'package:codemod/codemod.dart';
import 'package:over_react_codemod/src/util.dart' show IterableGroupBy;

/// Mixin that implements the [Suggestor] interface and makes it easier to write
/// class-based suggestors.
///
/// Similar to [AstVisitingSuggestor], except it:
///
/// - does not necessarily operate on AST
/// - does not get AST for a file by default
/// - allows duplicate patches
mixin ClassSuggestor {
  // This should be a List and not a Set to avoid patches in the same location getting mysteriously dropped.
  final _patches = <Patch>[];

  /// The context helper for the file currently being visited.
  FileContext get context {
    if (_context != null) return _context!;
    throw StateError('context accessed outside of a visiting context. '
        'Ensure that your suggestor only accesses `this.context` inside an AST visitor method.');
  }

  FileContext? _context;

  Stream<Patch> call(FileContext context) async* {
    if (shouldSkip(context)) return;

    _patches.clear();
    _context = context;

    await generatePatches();

    // Force the copying of this list, otherwise it would be a lazy iterable
    // mapped to the field on this class that will change on the next call.
    var patches = _patches.toList();
    _context = null;

    if (sortParenInsertionPatches) {
      patches = patches
          // group keys:
          // - int: insertion patches at that offset
          // - null: all other patches
          .groupBy((patch) => patch.isInsertionPatch ? patch.startOffset : null)
          .entries
          .expand((entry) {
        final isInsertionPatchGroup = entry.key != null;
        if (!isInsertionPatchGroup) return entry.value;

        return entry.value.toList()
          ..sort((a, b) {
            if (a.updatedText == '(' && b.updatedText == '(') return 0;
            if (a.updatedText == '(') return -1000;
            if (b.updatedText == '(') return 1000;

            if (a.updatedText == ')' && b.updatedText == ')') return 0;
            if (a.updatedText == ')') return 1000;
            if (b.updatedText == ')') return -1000;

            return entry.value.indexOf(a).compareTo(entry.value.indexOf(b));
          });
      }).toList();
    }

    yield* Stream.fromIterable(patches);
  }

  /// Whether to sort insertion patches at the same locations such that
  /// opening parentheses get applied first and closing parentheses are applied
  /// last.
  ///
  /// For instance,
  ///     [
  ///       Patch('(', 0, 0),
  ///       Patch('..bar', 3, 3),
  ///       Patch(')', 3, 3),
  ///       Patch('(', 0, 0),
  ///       Patch('..baz', 3, 3),
  ///       Patch(')', 3, 3),
  ///     ]
  /// on the string `foo()`
  /// would normally yield
  ///     ((foo..bar)..baz)()
  /// but with this `true`, yields
  ///     ((foo..bar..baz))()
  ///
  bool get sortParenInsertionPatches => true;

  /// Override with custom patch generation logic.
  Future<void> generatePatches();

  /// Whether the file represented by [context] should be parsed and visited.
  ///
  /// Subclasses can override this to skip all work for a file based on its
  /// contents if needed.
  bool shouldSkip(FileContext context) => false;

  void yieldPatch(String updatedText, int startOffset, [int? endOffset]) {
    _patches.add(Patch(updatedText, startOffset, endOffset));
  }

  void yieldInsertionPatch(String updatedText, int offset) {
    _patches.add(Patch(updatedText, offset, offset));
  }
}

extension InsertionPatchHelper on Patch {
  bool get isInsertionPatch => startOffset == endOffset;
}

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

@TestOn('vm')
library codemod.test.ast_visiting_suggestor_test;

import 'package:codemod/codemod.dart';
import 'package:codemod/test.dart';
import 'package:over_react_codemod/src/util/class_suggestor.dart';
import 'package:test/test.dart';

class Simple with ClassSuggestor {
  @override
  Future<void> generatePatches() async {
    yieldPatch('foo1', 0, 1);
    yieldPatch('foo1', 0, 1);
    yieldInsertionPatch('foo2', 1);
  }
}

class LibNameDoubler with ClassSuggestor {
  @override
  Future<void> generatePatches() async {
    final library = await context.getResolvedLibrary();
    final libraryName = library?.element?.name;
    if (libraryName == null) return;
    yieldPatch(libraryName * 2, 0, 1);
  }
}

class SortParens with ClassSuggestor {
  SortParens(this._shouldSortParens);

  final bool _shouldSortParens;

  @override
  bool get sortParenInsertionPatches => _shouldSortParens;

  @override
  Future<void> generatePatches() async {
    yieldPatch('(', 0, 0);
    yieldPatch('..bar', 3, 3);
    yieldPatch(')', 3, 3);
    yieldInsertionPatch('(', 0);
    yieldInsertionPatch('..baz', 3);
    yieldInsertionPatch(')', 3);
  }
}

void main() {
  group('ClassSuggestor', () {
    test('should yield patches', () async {
      final suggestor = Simple();
      final context = await fileContextForTest('lib.dart', 'library lib;');
      expect(
          suggestor(context),
          emitsInOrder([
            isA<Patch>()
                .having((p) => p.startOffset, 'startOffset', 0)
                .having((p) => p.endOffset, 'endOffset', 1)
                .having((p) => p.updatedText, 'updatedText', 'foo1')
                .having((p) => p.isInsertionPatch, 'isInsertionPatch', isFalse),
            equals(Patch('foo1', 0, 1)),
            isA<Patch>()
                .having((p) => p.startOffset, 'startOffset', 1)
                .having((p) => p.endOffset, 'endOffset', 1)
                .having((p) => p.updatedText, 'updatedText', 'foo2')
                .having((p) => p.isInsertionPatch, 'isInsertionPatch', isTrue),
            emitsDone,
          ]));
    });

    test('should be able to be run multiple times', () async {
      final suggestor = Simple();
      final expectedPatches = [
        Patch('foo1', 0, 1),
        Patch('foo1', 0, 1),
        Patch('foo2', 1, 1)
      ];

      final contextA = await fileContextForTest('a.dart', 'library a;');
      final patchesA = await suggestor(contextA).toList();
      expect(patchesA, expectedPatches);

      final contextB = await fileContextForTest('b.dart', 'library b;');
      final patchesB = await suggestor(contextB).toList();
      expect(patchesB, expectedPatches);
    });

    test(
        'should scope patch generation such that it is not broken by '
        'listening to streams out-of-order', () async {
      final suggestor = LibNameDoubler();

      final contextA = await fileContextForTest('a.dart', 'library a;');
      final patchesA = suggestor(contextA);

      final contextB = await fileContextForTest('b.dart', 'library b;');
      final patchesB = suggestor(contextB);

      final contextC = await fileContextForTest('c.dart', 'library c;');
      final patchesC = suggestor(contextC);

      expect(await patchesB.toList(), [Patch('bb', 0, 1)]);
      expect(await patchesA.toList(), [Patch('aa', 0, 1)]);
      expect(await patchesC.toList(), [Patch('cc', 0, 1)]);
    });

    test('should sort insertion patches when sortParenInsertionPatches is true',
        () async {
      final suggestor = SortParens(true);
      final context = await fileContextForTest('lib.dart', 'foo()');
      expect(
          suggestor(context),
          emitsInOrder([
            Patch('(', 0, 0),
            Patch('(', 0, 0),
            Patch('..bar', 3, 3),
            Patch('..baz', 3, 3),
            Patch(')', 3, 3),
            Patch(')', 3, 3),
            emitsDone,
          ]));
    });

    test(
        'should not sort insertion patches when sortParenInsertionPatches is false',
        () async {
      final suggestor = SortParens(false);
      final context = await fileContextForTest('lib.dart', 'foo()');
      expect(
          suggestor(context),
          emitsInOrder([
            Patch('(', 0, 0),
            Patch('..bar', 3, 3),
            Patch(')', 3, 3),
            Patch('(', 0, 0),
            Patch('..baz', 3, 3),
            Patch(')', 3, 3),
            emitsDone,
          ]));
    });
  });
}

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
import 'package:codemod/test.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

import 'package:over_react_codemod/src/dart2_suggestors/needs_over_react_library_collector.dart';

void main() {
  group('NeedsOverReactLibraryCollector', () {
    NeedsOverReactLibraryCollector collector;

    setUp(() {
      collector = NeedsOverReactLibraryCollector();
    });

    test('library that does not use over_react', () async {
      final context = await fileContextForTest(
          'foo.dart', 'library foo;\nvar bar = false;');
      expect(await collector(context).toList(), isEmpty);
      expect(collector.byName, isEmpty);
      expect(collector.byPath, isEmpty);
    });

    test('library without a name', () async {
      final path = './lib/foo.dart';
      final context = await fileContextForTest(path, '@Props() class Foo {}');
      expect(await collector(context).toList(), isEmpty);
      expect(collector.byName, isEmpty);
      expect(collector.byPath, [context.path]);
    });

    test('library with a name', () async {
      final path = './lib/foo.dart';
      final context = await fileContextForTest(path, '''library foo;
@Props() class Foo {}''');
      expect(await collector(context).toList(), isEmpty);
      expect(collector.byName, ['foo']);
      expect(collector.byPath, [context.path]);
    });

    test('part library with a parent referenced by path', () async {
      final path = './lib/foo.dart';
      final parentPath = './lib/parent.dart';
      final context = await fileContextForTest(path, '''part of 'parent.dart';
@Props() class Foo {}''');
      expect(await collector(context).toList(), isEmpty);
      expect(collector.byName, isEmpty);
      expect(collector.byPath, [p.canonicalize(p.join(d.sandbox, parentPath))]);
    });

    test('part library with a parent referenced by name', () async {
      final path = './lib/foo.dart';
      final context = await fileContextForTest(path, '''part of parent;
@Props() class Foo {}''');
      expect(await collector(context).toList(), isEmpty);
      expect(collector.byName, ['parent']);
      expect(collector.byPath, isEmpty);
    });

    test('collects multiple libraries', () async {
      // Standalone library that uses over_react.
      final standaloneLib = './lib/standalone.dart';
      final standaloneContext =
          await fileContextForTest(standaloneLib, '''library standalone;
@Props() class Foo {}''');

      // Part library that uses over_react.
      final partLib = './lib/part.dart';
      final parentLib = './lib/parent.dart';
      final partContext =
          await fileContextForTest(partLib, '''part of 'parent.dart';
@Props() class Foo {}''');

      // Library that does not use over_react.
      final nonOverReactLib = './lib/non_over_react.dart';
      final nonOverReactContext =
          await fileContextForTest(nonOverReactLib, '''library non_over_react;
var bar = false;''');

      expect(await collector(standaloneContext).toList(), isEmpty);
      expect(await collector(partContext).toList(), isEmpty);
      expect(await collector(nonOverReactContext).toList(), isEmpty);

      expect(collector.byName, ['standalone']);
      expect(collector.byPath, [
        standaloneContext.path,
        p.canonicalize(p.join(d.sandbox, parentLib)),
      ]);
    });
  });
}

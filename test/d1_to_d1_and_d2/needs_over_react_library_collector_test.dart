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
import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';
import 'package:test/test.dart';

import 'package:over_react_codemod/src/d1_to_d1_and_d2/suggestors/needs_over_react_library_collector.dart';

void main() {
  group('NeedsOverReactLibraryCollector', () {
    NeedsOverReactLibraryCollector collector;

    setUp(() {
      collector = NeedsOverReactLibraryCollector();
    });

    test('library that does not use over_react', () {
      final sourceFile =
          SourceFile.fromString('library foo;\nvar bar = false;');
      expect(collector.generatePatches(sourceFile), isEmpty);
      expect(collector.byName, isEmpty);
      expect(collector.byPath, isEmpty);
    });

    test('library without a name', () {
      final path = './lib/foo.dart';
      final sourceFile =
          SourceFile.fromString('@Props() class Foo {}', url: path);
      expect(collector.generatePatches(sourceFile), isEmpty);
      expect(collector.byName, isEmpty);
      expect(collector.byPath, [p.canonicalize(path)]);
    });

    test('library with a name', () {
      final path = './lib/foo.dart';
      final sourceFile = SourceFile.fromString('''library foo;
@Props() class Foo {}''', url: path);
      expect(collector.generatePatches(sourceFile), isEmpty);
      expect(collector.byName, ['foo']);
      expect(collector.byPath, [p.canonicalize(path)]);
    });

    test('part library with a parent referenced by path', () {
      final path = './lib/foo.dart';
      final parentPath = './lib/parent.dart';
      final sourceFile = SourceFile.fromString('''part of 'parent.dart';
@Props() class Foo {}''', url: path);
      expect(collector.generatePatches(sourceFile), isEmpty);
      expect(collector.byName, isEmpty);
      expect(collector.byPath, [p.canonicalize(parentPath)]);
    });

    test('part library with a parent referenced by name', () {
      final path = './lib/foo.dart';
      final sourceFile = SourceFile.fromString('''part of parent;
@Props() class Foo {}''', url: path);
      expect(collector.generatePatches(sourceFile), isEmpty);
      expect(collector.byName, ['parent']);
      expect(collector.byPath, isEmpty);
    });

    test('collects multiple libraries', () {
      // Standalone library that uses over_react.
      final standaloneLib = './lib/standalone.dart';
      final standaloneSourceFile = SourceFile.fromString('''library standalone;
@Props() class Foo {}''', url: standaloneLib);

      // Part library that uses over_react.
      final partLib = './lib/part.dart';
      final parentLib = './lib/parent.dart';
      final partSourceFile = SourceFile.fromString('''part of 'parent.dart';
@Props() class Foo {}''', url: partLib);

      // Library that does not use over_react.
      final nonOverReactLib = './lib/non_over_react.dart';
      final nonOverReactSourceFile =
          SourceFile.fromString('''library non_over_react;
var bar = false;''', url: nonOverReactLib);

      expect(collector.generatePatches(standaloneSourceFile), isEmpty);
      expect(collector.generatePatches(partSourceFile), isEmpty);
      expect(collector.generatePatches(nonOverReactSourceFile), isEmpty);

      expect(collector.byName, ['standalone']);
      expect(collector.byPath, [
        p.canonicalize(standaloneLib),
        p.canonicalize(parentLib),
      ]);
    });
  });
}

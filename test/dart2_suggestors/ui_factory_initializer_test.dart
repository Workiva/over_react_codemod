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

import 'package:codemod/test.dart';
@TestOn('vm')
import 'package:test/test.dart';

import 'package:over_react_codemod/src/dart2_suggestors/ui_factory_initializer.dart';

void main() {
  group('UiFactoryInitializer', () {
    group('shouldSkip()', () {
      test('returns false when @Factory() annotation found', () async {
        final context = await fileContextForTest('foo.dart', '''library foo;
import 'package:over_react/over_react.dart';
@Factory()
UiFactory<FooProps> Foo;
class FooProps {}''');
        expect(UiFactoryInitializer().shouldSkip(context), isFalse);
      });

      test('returns true when no @Factory() annotation found', () async {
        final context = await fileContextForTest('foo.dart', '''library foo;
import 'package:over_react/over_react.dart';
UiFactory<FooProps> Foo;
class FooProps {}''');
        expect(UiFactoryInitializer().shouldSkip(context), isTrue);
      });

      test('returns true when @Factory() annotation is commented out',
          () async {
        final context = await fileContextForTest('foo.dart', '''library foo;
import 'package:over_react/over_react.dart';
// @Factory()
UiFactory<FooProps> Foo;
class FooProps {}''');
        expect(UiFactoryInitializer().shouldSkip(context), isTrue);
      });
    });
  });
}

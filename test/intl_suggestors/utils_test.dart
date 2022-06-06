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

import 'package:over_react_codemod/src/intl_suggestors/utils.dart';
import 'package:test/test.dart';

void main() {
  group('IntlUtils', ()
  {
    group('removeInterpolationSyntax', () {
      test('\$a', () async {
        var inputString = '\$a';
        var result = removeInterpolationSyntax(inputString);
        expect(result, 'a');
      });

      test('\${a}', () async {
        var inputString = '\${a}';
        var result = removeInterpolationSyntax(inputString);
        expect(result, 'a');
      });

      test('\${a.b}', () async {
        var inputString = '\${a.b}';
        var result = removeInterpolationSyntax(inputString);
        expect(result, 'a.b');
      });

      test('\${a.b.c}', () async {
        var inputString = '\${a.b.c}';
        var result = removeInterpolationSyntax(inputString);
        expect(result, 'a.b.c');
      });

      test('\${a.b.c ?? d}', () async {
        var inputString = '\${a.b.c ?? d}';
        var result = removeInterpolationSyntax(inputString);
        expect(result, 'a.b.c');
      });
    });
    group('Apostrophe escaping', () {
      test('unescaped apos', () {
        final testString = "Foo's Bar";
        final result = escapeApos(testString);
        expect(result, 'Foo\\\'s Bar');
      });
      test('escaped apos', () {
        final testString = "Foo\'s Bar";
        final result = escapeApos(testString);
        expect(result, 'Foo\\\'s Bar');
      });
      test('home example', () {
        final fileStr = 'test1';
        final refStr = 'test2';
        final result = escapeApos('Now that you\'ve transitioned your $fileStr, you\'ll want to freeze $refStr or update permissions to prevent others from using $refStr.');
        expect(result, 'Now that you\\\'ve transitioned your $fileStr, you\\\'ll want to freeze $refStr or update permissions to prevent others from using $refStr.');
      });
    });

    group('toClassName', () {
      test('one', () {
        expect(toClassName('one'), 'OneIntl');
      });
      test('one_two', () {
        expect(toClassName('one_two'), 'OneTwoIntl');
      });
      test('one_two_three', () {
        expect(toClassName('one_two_three'), 'OneTwoThreeIntl');
      });
    });

    group('toVariableName', () {
      test('001 test Var', () {
        expect(toVariableName('001 test Var'), 'testVar');
      });
      test('Test This string', () {
        expect(toVariableName('Test This string'), 'testThisString');
      });
      test("Test's test'1", () {
        expect(toVariableName("Test's test'1"), 'testsTest1');
      });
    });
  });
}

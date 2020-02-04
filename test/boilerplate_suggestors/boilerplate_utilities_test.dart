// Copyright 2020 Workiva Inc.
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

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:over_react_codemod/src/boilerplate_suggestors/boilerplate_utilities.dart';
import 'package:test/test.dart';

void main() {
  group('Boilerplate Utilities:', () {
    group('getPublicExportLocations()', () {
      SemverHelper helper;

      group('returns null', () {
        test('if there is no exports list', () {
          helper = SemverHelper({'someOtherInfo': 'abc'});

          getPublicExportLocationsTestHelper(
            helper,
            input: '''
              @Props()
              class _\$FooProps extends UiProps{
                String foo;
                int bar;
              }
            ''',
            expectedResult: null,
          );
        });

        test('if props class is not in export list', () {
          helper = SemverHelper({
            'exports': {
              'lib/web_skin_dart.dart/ButtonProps': {
                'type': 'class',
                'grammar': {
                  'name': 'ButtonProps',
                  'meta': ['@Props()']
                }
              }
            }
          });

          getPublicExportLocationsTestHelper(
            helper,
            input: '''
              @Props()
              class _\$FooProps extends UiProps{
                String foo;
                int bar;
              }
            ''',
            expectedResult: null,
          );
        });
      });

      test('returns correct information if props class is in export list', () {
        helper = SemverHelper({
          "exports": {
            "lib/web_skin_dart.dart/ButtonProps": {
              "type": "class",
              "grammar": {
                "name": "ButtonProps",
                "meta": ["@Props()"]
              }
            },
            "lib/web_skin_dart.dart/FooProps": {
              "type": "class",
              "grammar": {
                "name": "FooProps",
                "meta": ["@Props()"]
              }
            },
            "lib/web_skin_dart.dart/BarProps": {
              "type": "class",
              "grammar": {
                "name": "BarProps",
                "meta": ["@Props()"]
              }
            },
            "lib/web_skin_dart.dart/DropdownSelectProps": {
              "type": "class",
              "grammar": {
                "name": "DropdownSelectProps",
                "meta": ["@Props()"]
              }
            }
          }
        });

        getPublicExportLocationsTestHelper(
          helper,
          input: '''
            @Props()
            class DropdownSelectProps extends UiProps{
              String foo;
              int bar;
            }
          ''',
          expectedResult: {
            "type": "class",
            "grammar": {
              "name": "DropdownSelectProps",
              "meta": ["@Props()"]
            }
          },
        );
      });
    });
  });
}

void getPublicExportLocationsTestHelper(SemverHelper helper,
    {String input, Map expectedResult}) {
  CompilationUnit unit = parseString(content: input).unit;
  expect(unit.declarations.whereType<ClassDeclaration>().length, 1);

  unit.declarations.whereType<ClassDeclaration>().forEach((classNode) {
    expect(helper.getPublicExportLocations(classNode), expectedResult);
  });
}

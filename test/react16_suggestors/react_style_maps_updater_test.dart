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

import 'package:over_react_codemod/src/react16_suggestors/constants.dart';
import 'package:over_react_codemod/src/react16_suggestors/react_style_maps_updater.dart';
import 'package:test/test.dart';

import '../util.dart';

main() {
  group('ReactStyleMapUpdater', () {
    final testSuggestor = getSuggestorTester(ReactStyleMapsUpdater());

    group('updates correctly when there', () {
      test('is an empty file', () async {
        await testSuggestor(expectedPatchCount: 0, input: '');
      });

      test('are no matches', () async {
        await testSuggestor(
          expectedPatchCount: 0,
          input: '''
            main() {
              Foo()
              ..id = 'number1'
              ..style = {
                'width': 40
              };
            }
          ''',
        );
      });

      test('is a single value within a style map', () async {
        await testSuggestor(
          expectedPatchCount: 1,
          input: '''
            main() {
              Foo()
              ..id = 'number1'
              ..style = {
                'width': '40'
              };
            }
          ''',
          expectedOutput: '''
            main() {
              Foo()
              ..id = 'number1'
              ..style = {
                'width': 40,
              };
            }
          ''',
        );
      });

      test('is a single value within a style map using double quotes',
          () async {
        await testSuggestor(
          expectedPatchCount: 1,
          input: '''
            main() {
              Foo()
              ..id = 'number1'
              ..style = {
                "width": "40"
              };
            }
          ''',
          expectedOutput: '''
            main() {
              Foo()
              ..id = 'number1'
              ..style = {
                "width": 40,
              };
            }
          ''',
        );
      });

      test('is a single value within an inline style map', () async {
        await testSuggestor(
          expectedPatchCount: 1,
          input: '''
            main() {
              Foo()..style = {"width": "40"};
            }
          ''',
          expectedOutput: '''
            main() {
              Foo()
              ..style = {"width": 40,};
            }
          ''',
        );
      });

      test('are multiple values within a style map', () async {
        await testSuggestor(
          expectedPatchCount: 3,
          input: '''
            main() {
              Foo()
              ..id = 'number1'
              ..style = {
                'width': '40',
                'height': '40%',
                'fontSize': '12',
                'margin': '25',
              };
            }
          ''',
          expectedOutput: '''
            main() {
              Foo()
              ..id = 'number1'
              ..style = {
                'width': 40,
                'height': '40%',
                'fontSize': 12,
                'margin': 25,
              };
            }
          ''',
        );
      });

      test('is a ternary expression', () async {
        await testSuggestor(
          expectedPatchCount: 4,
          input: '''
            main() {
              Foo()
              ..style = {
                'width': isWide ? '40' : '20',
                'height': '40%',
                'fontSize': '12',
                'margin': '25',
              };
            }
          ''',
          expectedOutput: '''
            main() {
              Foo()
              ..style = {
                'width': isWide ? 40 : 20,
                'height': '40%',
                'fontSize': 12,
                'margin': 25,
              };
            }
          ''',
        );
      });

      test('is a null check', () async {
        await testSuggestor(
          expectedPatchCount: 4,
          input: '''
            main() {
              Foo()
              ..style = {
                'width': isWide ?? '40',
                'height': '40%',
                'fontSize': '12',
                'margin': '25',
              };
            }
          ''',
          expectedOutput: '''
            main() {
              Foo()
              ${manualVariableCheckComment(keysOfModdedValues: ['width'])}
              ..style = {
                'width': isWide ?? 40,
                'height': '40%',
                'fontSize': 12,
                'margin': 25,
              };
            }
          ''',
        );
      });

      test('is a null check with two variables', () async {
        await testSuggestor(
          expectedPatchCount: 3,
          input: '''
            main() {
              Foo()
              ..style = {
                'width': isWide ?? isNotWide,
                'height': '40%',
                'fontSize': '12',
                'margin': '25',
              };
            }
          ''',
          expectedOutput: '''
            main() {
              Foo()
              ${manualVariableCheckComment(keysOfModdedValues: [
            'width',
          ])}
              ..style = {
                'width': isWide ?? isNotWide,
                'height': '40%',
                'fontSize': 12,
                'margin': 25,
              };
            }
          ''',
        );
      });

      test('is a mathmatical expression', () async {
        await testSuggestor(
          expectedPatchCount: 3,
          input: '''
            main() {
              Foo()
              ..style = {
                'width': width / 10,
                'height': '40%',
                'fontSize': '12',
                'margin': '25',
              };
            }
          ''',
          expectedOutput: '''
            main() {
              Foo()
              ${manualVariableCheckComment(keysOfModdedValues: [
            'width',
          ])}
              ..style = {
                'width': width / 10,
                'height': '40%',
                'fontSize': 12,
                'margin': 25,
              };
            }
          ''',
        );
      });

      test('is on a unitless or non-number property', () async {
        await testSuggestor(
          expectedPatchCount: 0,
          input: '''
            main() {
              Foo()
              ..style = {
                'zIndex': '5',
                'position': 'absolute',
              };
            }
          ''',
        );
      });

      test('is on a custom property', () async {
        await testSuggestor(
          expectedPatchCount: 1,
          input: '''
            main() {
              Foo()
              ..style = {
                '--foo': '5',
              };
            }
          ''',
          expectedOutput: '''
            main() {
              Foo()
              ..style = {
                '--foo': 5,
              };
            }
          ''',
        );
      });

      test('is a toRem/toPx call', () async {
        await testSuggestor(
          expectedPatchCount: 0,
          input: '''
            main() {
              Foo()
              ..style = {
                'width': toRem(width),
                'height': toPx(height),
              };
            }
          ''',
        );
      });

      test('is a toRem/toPx call with a toString at the end', () async {
        await testSuggestor(
          expectedPatchCount: 0,
          input: '''
            main() {
              Foo()
              ..style = {
                'fontSize': toRem('12').toString(),
                'margin': toPx('25').toString(),
              };
            }
          ''',
        );
      });

      test('is an interpolated string ending in a known CSS unit', () async {
        await testSuggestor(
          expectedPatchCount: 0,
          input: r'''
            main() {
              Foo()
                ..style = {
                  'width': '${width}rem',
                  'width': '${getHeight()}px',
                };
            }
          ''',
        );
      });

      test('is an interpolated string not ending in a known CSS unit',
          () async {
        await testSuggestor(
          expectedPatchCount: 0,
          input: '''
            main() {
              Foo()
                ${getCheckboxComment(keysOfModdedValues: [
            'width',
            'height',
            'fontSize'
          ])}
                ..style = {
                  'width': '\$width',
                  'height': '\${getHeight()}foo',
                  'fontSize': '\${getFontSize()}notpx',
                };
            }
          ''',
        );
      });

      test('is on an instance creation expression', () async {
        await testSuggestor(
          expectedPatchCount: 0,
          input: '''
            main() {
              new NotAPropsClass()
                ..style = something
                ..style = getSomething()
                ..style = {
                  'width': '40',
                };
            }
          ''',
        );
      });

      test('is an expression that has already been updated', () async {
        await testSuggestor(
          expectedPatchCount: 0,
          input: '''
            main() {
              Foo()
              ${getCheckboxComment(keysOfModdedValues: [
            'width',
            'fontSize',
            'margin'
          ])}
              ..style = {
                'width': isWide ? 40 : 20,
                'height': '40%',
                'fontSize': 12,
                'margin': 25,
              };
            }
          ''',
          expectedOutput: '''
            main() {
              Foo()
              ${getCheckboxComment(keysOfModdedValues: [
            'width',
            'fontSize',
            'margin'
          ])}
              ..style = {
                'width': isWide ? 40 : 20,
                'height': '40%',
                'fontSize': 12,
                'margin': 25,
              };
            }
          ''',
        );
      });

      test('is a function call', () async {
        await testSuggestor(
          expectedPatchCount: 1,
          input: '''
            main() {
              Map getStyleMap() {
                return {
                  'width': '40px',
                };
              }

              Foo()
              ..style = getStyleMap();
            }
          ''',
          expectedOutput: '''
            main() {
              Map getStyleMap() {
                return {
                  'width': '40px',
                };
              }

              Foo()
              ${getFunctionComment()}
              ..style = getStyleMap();
            }
          ''',
        );
      });

      test('is a component as prop value', () async {
        await testSuggestor(
          expectedPatchCount: 2,
          input: '''
            main() {
              Foo()
              ..style = {
                'width': '400'
              }
              ..bar = Bar()
                ..style = {
                'height': '200'
              };
            }
          ''',
          expectedOutput: '''
            main() {
              Foo()
              ..style = {
                'width': 400,
              }
              ..bar = Bar()
                ..style = {
                  'height': 200,
                };
            }
          ''',
        );
      });

      test('are variadic children', () async {
        await testSuggestor(
          expectedPatchCount: 2,
          input: '''
            main() {
              (Foo()
              ..id = 'number1'
              ..style = {'width': '40',}
              )(
                (Bar()
                ..style = {'width': '60',}
                )(),
              );
            }
          ''',
          expectedOutput: '''
            main() {
              (Foo()
              ..id = 'number1'
              ..style = {'width': 40,})(
                (Bar()
                  ..style = {
                    'width': 60,
                  })(),
              );
            }
          ''',
        );
      });

      test('is an unexpected property value', () async {
        await testSuggestor(
          expectedPatchCount: 1,
          input: '''
            main() {
              Foo()
              ..style = {
                'width': foo.bar,
              };
            }
          ''',
          expectedOutput: '''
            main() {
              Foo()
              ${manualVariableCheckComment(keysOfModdedValues: ['width'])}
              ..style = {
                'width': foo.bar,
              };
            }
        ''',
        );
      });

      test('is an unexpected style prop value', () async {
        await testSuggestor(
          expectedPatchCount: 1,
          input: '''
            main() {
              Foo()
              ..style = foo.bar;
            }
          ''',
          expectedOutput: '''
            main() {
              Foo()
              ${manualVariableCheckComment()}
              ..style = foo.bar;
            }
        ''',
        );
      });
    });

    test('adds a validate variable comment when the map value is a variable',
        () async {
      await testSuggestor(
        expectedPatchCount: 1,
        input: '''
            main() {
              var bar = {'width': '40'};
              Foo()
              ..style = bar;
            }
        ''',
        expectedOutput: '''
          main() {
            var bar = {'width': '40'};
            Foo()
            ${manualVariableCheckComment()}
            ..style = bar;
          }
        ''',
      );
    });

    test('adds a validate variable comment when the key value is a variable',
        () async {
      await testSuggestor(
        expectedPatchCount: 1,
        input: '''
            main() {
              Foo()
              ..style = {
                'width': bar,
              };
            }
        ''',
        expectedOutput: '''
          main() {
            Foo()
            ${manualVariableCheckComment(keysOfModdedValues: ['width'])}
            ..style = {
              'width': bar,
            };
          }
        ''',
      );
    });

    test('does not add a second validate comment when unchecked', () async {
      await testSuggestor(
        expectedPatchCount: 0,
        input: '''
            main() {
              Foo()
              ${getCheckboxComment(keysOfModdedValues: ['width'])}
              ..style = {
                'width': '40px',
              };
            }
        ''',
      );
    });

    test('does not add a second validate comment when checked', () async {
      await testSuggestor(
        expectedPatchCount: 0,
        input: '''
            main() {
              Foo()
              ${getCheckboxComment(keysOfModdedValues: [
          'width'
        ], checked: true)}
              ..style = {
                'width': '40px',
              };
            }
        ''',
      );
    });

    test('does not override comments', () async {
      await testSuggestor(
        expectedPatchCount: 3,
        input: '''
            main() {
              Foo()
              ..style = {
                'width': '40',
                // Test Comment
                'height': '40%',
                'fontSize': '12',
                'margin': '25',
              };
            }
          ''',
        expectedOutput: '''
            main() {
              Foo()
              ..style = {
                'width': 40,
                // Test Comment
                'height': '40%',
                'fontSize': 12,
                'margin': 25,
              };
            }
          ''',
      );
    });

    test('does not run on DOM style setProperty', () async {
      await testSuggestor(
        expectedPatchCount: 0,
        input: '''
            main() {
              DivElement()..style.setProperty('width', '400');
            }
          ''',
      );
    });

    test('does not run on DOM style property assignments in various forms',
        () async {
      await testSuggestor(
        expectedPatchCount: 0,
        input: '''
            main() {
              style.width = '400';
              style..width = '400';
              DivElement().style.width = '400';
              DivElement()..style.width = '400';
              DivElement().style..width = '400';
            }
          ''',
      );
    });

    test('works for custom props maps containing styles', () async {
      await testSuggestor(
        expectedPatchCount: 1,
        input: '''
            main() {
              Foo()
              ..datePickerProps = (domProps()
                ..style = {
                  'width': '40',
                }
              );
            }
          ''',
        expectedOutput: '''
            main() {
              Foo()
              ..datePickerProps = (domProps()
                ..style = {
                  'width': 40,
                }
              );
            }
          ''',
      );
    });

    test('does not run twice', () async {
      await testSuggestor(
        expectedPatchCount: 0,
        input: '''
            main() {
              Foo()
              ${manualVariableCheckComment(keysOfModdedValues: [
          'width'
        ], isChecked: true)}
              ..style = {
                'width': isWide ?? 40,
                'height': '40%',
                'fontSize': 12,
                'margin': 25,
              };
            }
          ''',
        expectedOutput: '''
            main() {
              Foo()
              ${manualVariableCheckComment(keysOfModdedValues: [
          'width'
        ], isChecked: true)}
              ..style = {
                'width': isWide ?? 40,
                'height': '40%',
                'fontSize': 12,
                'margin': 25,
              };
            }
          ''',
      );
    });
  });
}

String getCheckboxComment({
  bool checked = false,
  List<String> keysOfModdedValues = const [],
}) =>
    '''// ${checked ? '[x]' : '[ ]'} Check this box upon manual validation that this style map uses a valid value ${keysOfModdedValues.isNotEmpty ? 'for the following keys: ${keysOfModdedValues.join(', ')}.' : 'for the keys that are numbers.'}
    $styleMapComment
    //$willBeRemovedCommentSuffix''';

String manualVariableCheckComment(
        {List<String> keysOfModdedValues = const [], isChecked = false}) =>
    '''// ${isChecked ? '[x]' : '[ ]'} Check this box upon manual validation that this style map is receiving a value that is valid ${keysOfModdedValues.isNotEmpty ? 'for the following keys: ${keysOfModdedValues.join(', ')}.' : 'for the keys that are simple string variables.'}
    $styleMapComment
    //$willBeRemovedCommentSuffix''';

String getFunctionComment() =>
    '''// [ ] Check this box upon manual validation that the method called to set the style prop does not return any simple, unitless strings instead of nums.
  $styleMapComment
  //$willBeRemovedCommentSuffix''';

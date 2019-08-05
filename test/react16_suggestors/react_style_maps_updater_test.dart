import 'package:over_react_codemod/src/react16_suggestors/constants.dart';
import 'package:over_react_codemod/src/react16_suggestors/react_style_maps_updater.dart';
import 'package:test/test.dart';

import '../util.dart';

main() {
  group('ReactStyleMapUpdater', () {
    final testSuggestor = getSuggestorTester(ReactStyleMapsUpdater());

    group('updates correctly when there', () {
      test('is an empty file', () {
        testSuggestor(expectedPatchCount: 0, input: '');
      });

      test('are no matches', () {
        testSuggestor(
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

      test('is a single value within a style map', () {
        testSuggestor(
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

      test('is a single value within a style map using double quotes', () {
        testSuggestor(
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

      test('is a single value within an inline style map', () {
        testSuggestor(
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

      test('are multiple values within a style map', () {
        testSuggestor(
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

      test('is a ternary expression', () {
        testSuggestor(
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

      test('is a null check', () {
        testSuggestor(
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

      test('is a null check with two variables', () {
        testSuggestor(
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

      test('is an expression that has already been updated', () {
        testSuggestor(
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

      test('is a function call', () {
        testSuggestor(
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

      test('is a component as prop value', () {
        testSuggestor(
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

      test('are variadic children', () {
        testSuggestor(
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

      test('is an unexpected property value', () {
        testSuggestor(
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
              ${manualVariableCheckComment()}
              ..style = {
                'width': foo.bar,
              };
            }
        ''',
        );
      });

      test('is an unexpected style prop value', () {
        testSuggestor(
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
        () {
      testSuggestor(
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
        () {
      testSuggestor(
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

    test('does not add a second validate comment when unchecked', () {
      testSuggestor(
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

    test('does not add a second validate comment when checked', () {
      testSuggestor(
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

    test('does not override comments', () {
      testSuggestor(
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

    test('does not run on setProperty', () {
      testSuggestor(
        expectedPatchCount: 0,
        input: '''
            main() {
              DivElement()..style.setProperty('width', '400');
            }
          ''',
        expectedOutput: '''
            main() {
              DivElement()..style.setProperty('width', '400');
            }
          ''',
      );
    });

    test('adds a comment for custom props', () {
      testSuggestor(
        expectedPatchCount: 1,
        input: '''
            main() {
              Foo()
              ..datePickerProps = {
                'style': {
                  'width': '40',
                }
              };
            }
          ''',
        expectedOutput: '''
            main() {
              Foo()
              ${manualVariableCheckComment()}
              ..datePickerProps = {
                'style': {
                  'width': '40',
                }
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
    $styleMapExample   
    //$willBeRemovedCommentSuffix''';

String manualVariableCheckComment(
        {List<String> keysOfModdedValues = const []}) =>
    '''// [ ] Check this box upon manual validation that this style map is receiving a value that is valid ${keysOfModdedValues.isNotEmpty ? 'for the following keys: ${keysOfModdedValues.join(', ')}.' : 'for the keys that are simple string variables.'} 
    $styleMapExample
    //$willBeRemovedCommentSuffix''';

String getFunctionComment() =>
    '''// [ ] Check this box upon manual validation that the method called to set the style prop does not return any simple, unitless strings instead of nums.
  $styleMapExample
  //$willBeRemovedCommentSuffix''';

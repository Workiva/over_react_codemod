import 'package:over_react_codemod/src/react16_suggestors/constants.dart';
import 'package:over_react_codemod/src/react16_suggestors/react_style_maps_updater.dart';
import 'package:test/test.dart';

import '../util.dart';

main() {
  group('ReactStyleMapUpdater', () {
    final testSuggestor = getSuggestorTester(ReactStyleMapsUpdater());

    group('updates', () {
      test('an empty file correctly when there', () {
        testSuggestor(expectedPatchCount: 0, input: '');
      });

      test('are no matches', () {
        testSuggestor(
          expectedPatchCount: 0,
          input: '''
            $classSetupBoilerPlate
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
          expectedPatchCount: 2,
          input: '''
            $classSetupBoilerPlate
            main() {
              Foo()
              ..id = 'number1'
              ..style = {
                'width': '40'
              };
            }
          ''',
          expectedOutput: '''
            $classSetupBoilerPlate
            main() {
              Foo()
              ..id = 'number1'
              ${getCheckboxComment(keysOfModdedValues: ['width'])}
              ..style = {
                'width': 40,
              };
            }
          ''',
        );
      });

      test('is a single value within a style map using double quotes', () {
        testSuggestor(
          expectedPatchCount: 2,
          input: '''
            $classSetupBoilerPlate
            main() {
              Foo()
              ..id = 'number1'
              ..style = {
                "width": "40"
              };
            }
          ''',
          expectedOutput: '''
            $classSetupBoilerPlate
            main() {
              Foo()
              ..id = 'number1'
              ${getCheckboxComment(keysOfModdedValues: ['width'])}
              ..style = {
                "width": 40,
              };
            }
          ''',
        );
      });

      test('is a single value within an inline style map', () {
        testSuggestor(
          expectedPatchCount: 2,
          input: '''
            $classSetupBoilerPlate
            main() {
              Foo()..style = {"width": "40"};
            }
          ''',
          expectedOutput: '''
            $classSetupBoilerPlate
            main() {
              Foo()
              ${getCheckboxComment(keysOfModdedValues: ['width'])}
              ..style = {"width": 40,};
            }
          ''',
        );
      });

      test('are multiple values within a style map', () {
        testSuggestor(
          expectedPatchCount: 4,
          input: '''
            $classSetupBoilerPlate
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
            $classSetupBoilerPlate
            main() {
              Foo()
              ..id = 'number1'
              ${getCheckboxComment(keysOfModdedValues: ['width', 'fontSize', 'margin'])}
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
            $classSetupBoilerPlate
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
            $classSetupBoilerPlate
            main() {
              Foo()
              ${getCheckboxComment(keysOfModdedValues: ['width', 'fontSize', 'margin'])}
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

      test('a null check', () {
        testSuggestor(
          expectedPatchCount: 4,
          input: '''
            $classSetupBoilerPlate
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
            $classSetupBoilerPlate
            main() {
              Foo()
              ${getCheckboxComment(keysOfModdedValues: ['width', 'fontSize', 'margin'])}
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

      test('a null check with two variables', () {
        testSuggestor(
          expectedPatchCount: 3,
          input: '''
            $classSetupBoilerPlate
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
            $classSetupBoilerPlate
            main() {
              Foo()
              ${manualVariableCheckComment(keysOfModdedValues: ['width', 'fontSize', 'margin'])}
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
            $classSetupBoilerPlate
            main() {
              Foo()
              ${getCheckboxComment(keysOfModdedValues: ['width', 'fontSize', 'margin'])}
              ..style = {
                'width': isWide ? 40 : 20,
                'height': '40%',
                'fontSize': 12,
                'margin': 25,
              };
            }
          ''',
          expectedOutput: '''
            $classSetupBoilerPlate
            main() {
              Foo()
              ${getCheckboxComment(keysOfModdedValues: ['width', 'fontSize', 'margin'])}
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

      test('a function call', () {
        testSuggestor(
          expectedPatchCount: 1,
          input: '''
            $classSetupBoilerPlate
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
            $classSetupBoilerPlate
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

      test('is a nested component', () {
        testSuggestor(
          expectedPatchCount: 4,
          input: '''
            class Foo {
              Map style;
              Bar bar;
            }
            
            class Bar {
              Map style;
            }
            
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
            class Foo {
              Map style;
              Bar bar;
            }
            
            class Bar {
              Map style;
            }
            
            main() {
              Foo()
              ${getCheckboxComment(keysOfModdedValues:['width'])}
              ..style = {
                'width': 400,
              }
              ..bar = Bar()
                ${getCheckboxComment(keysOfModdedValues:['height'])}
                ..style = {
                  'height': 200,
                };
            }
          ''',
        );
      });
    });

    test('adds a validate variable comment when the map value is a variable', () {
      testSuggestor(
        expectedPatchCount: 1,
        input: '''
          $classSetupBoilerPlate
            main() {
              var bar = {'width': '40'};
              Foo()
              ..style = bar;
            }
        ''',
        expectedOutput: '''
          $classSetupBoilerPlate
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
          $classSetupBoilerPlate
            main() {
              var bar = '40';
              Foo()
              ..style = {
                'width': bar,
              };
            }
        ''',
        expectedOutput: '''
          $classSetupBoilerPlate
          main() {
            var bar = '40';
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
          $classSetupBoilerPlate
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
          $classSetupBoilerPlate
            main() {
              Foo()
              ${getCheckboxComment(keysOfModdedValues: ['width'], checked: true)}
              ..style = {
                'width': '40px',
              };
            }
        ''',
      );
    });

    test('does not override comments', () {
      testSuggestor(
        expectedPatchCount: 4,
        input: '''
            $classSetupBoilerPlate
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
            $classSetupBoilerPlate
            main() {
              Foo()
              ${getCheckboxComment(keysOfModdedValues: ['width', 'fontSize', 'margin'])}
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
            $classSetupBoilerPlate
            main() {
              DivElement()..style.setProperty('width', '400');
            }
          ''',
        expectedOutput: '''
            $classSetupBoilerPlate
            main() {
              DivElement()..style.setProperty('width', '400');
            }
          ''',
      );
    });
  });
}

String getCheckboxComment({
  bool checked: false,
  List<String> keysOfModdedValues: const [],
}) =>
    '''// ${checked ? '[x]' : '[ ]'} Check this box upon manual validation that this style map uses a valid value ${keysOfModdedValues.isNotEmpty
            ? 'for the following keys: ${keysOfModdedValues.join(', ')}.'
            : 'for the keys that are numbers.'}
    $styleMapExample   
    //$willBeRemovedCommentSuffix''';

String manualVariableCheckComment({List<String> keysOfModdedValues: const []}) =>
    '''// [ ] Check this box upon manual validation that this style map is receiving a value that is valid ${keysOfModdedValues.isNotEmpty
        ? 'for the following keys: ${keysOfModdedValues.join(', ')}.'
        : 'for the keys that are simple string variables.'} 
    $styleMapExample
    //$willBeRemovedCommentSuffix''';

String getFunctionComment() =>
  '''// [ ] Check this box upon manual validation that the method called to set the style prop does not return any simple, unitless strings instead of nums.
  $styleMapExample
  //$willBeRemovedCommentSuffix''';

final classSetupBoilerPlate = '''
  class Foo {
    Map style;
    String id;
  }
''';

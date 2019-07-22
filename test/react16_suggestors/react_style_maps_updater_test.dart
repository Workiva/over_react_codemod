import 'package:over_react_codemod/src/react16_suggestors/constants.dart';
import 'package:over_react_codemod/src/react16_suggestors/react_style_maps_updater.dart';
import 'package:test/test.dart';

import '../util.dart';

main() {
  group('ReactStyleMapUpdater', () {
    final testSuggestor = getSuggestorTester(ReactStyleMapsUpdater());

    group('updates', () {
      test('an empty file correctly', () {
        testSuggestor(expectedPatchCount: 0, input: '');
      });

      test('no matches correctly', () {
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

      test('a single value within a style map', () {
        testSuggestor(
          expectedPatchCount: 1,
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

      test('a single value within a style map using double quotes', () {
        testSuggestor(
          expectedPatchCount: 1,
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
                'width': 40,
              };
            }
          ''',
        );
      });

      test('multiple values within a style map', () {
        testSuggestor(
          expectedPatchCount: 1,
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

      test('correctly when there is a ternary expression', () {
        testSuggestor(
          expectedPatchCount: 1,
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

      test('correctly when there is a null check', () {
        testSuggestor(
          expectedPatchCount: 1,
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
    });

    test('correctly when there is an expression that has already been updated', () {
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
  });
}

String getCheckboxComment({
  bool checked: false,
  List<String> keysOfModdedValues: const [],
}) =>
    '// ${checked ? '[x]' : '[ ]'}'
        ' Check this box upon manual validation that this style map uses a valid num '
        '${keysOfModdedValues.isNotEmpty
            ? 'for the following keys: ${keysOfModdedValues.join(', ')}.'
            : 'for the keys that are numbers.'}'
        '$willBeRemovedCommentSuffix';

String manualVariableCheckComment({List<String> keysOfModdedValues: const []}) =>
    '// [ ] Check this box upon manual validation that '
        'the style map is receiving a value that is a num '
        '${keysOfModdedValues.isNotEmpty
        ? 'for the following keys: ${keysOfModdedValues.join(', ')}.'
        : 'for the keys that are simple string variables. For example, \'width\': \'40\'.'}'
        '$willBeRemovedCommentSuffix';

final checkboxComment = getCheckboxComment();
final classSetupBoilerPlate = '''
  class Foo {
    Map style;
    String id;
  }
''';

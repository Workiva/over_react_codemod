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
              ..style = {
                'width': 40
              }
            }
          ''',
        );
      });

      test('a single value within a style map', () {
        testSuggestor(
          expectedPatchCount: 2,
          input: '''
            $classSetupBoilerPlate
            main() {
              Foo()
              ..style = {
                'width': '40'
              }
            }
          ''',
          expectedOutput: '''
            $classSetupBoilerPlate
            main() {
              Foo()
              ..style = {
                ${getCheckboxComment(keysOfModdedValues: ['width'])}
                'width': 40,
              }
            }
          ''',
        );
      });

      test('multiple value swithin a style map', () {
        testSuggestor(
          expectedPatchCount: 1,
          input: '''
            $classSetupBoilerPlate
            main() {
              Foo()
              ..style = {
                'width': '40',
                'height': '40%',
                'fontSize': '12',
                'margin': '25',
              }
            }
          ''',
          expectedOutput: '''
            $classSetupBoilerPlate
            main() {
              Foo()
              ${getCheckboxComment(keysOfModdedValues: ['width', 'fontSize', 'margin'])}
              ..style = {
                'width': 40
                'height': '40%',
                'fontSize': 12,
                'margin': 25,
              }
            }
          ''',
        );
      });
    });

    test('removes the pixel unit specification', () {
      testSuggestor(
        expectedPatchCount: 2,
        input: '''
          $classSetupBoilerPlate
          main() {
            Foo()
            ..style = {
              'width': '40px',
            }
          }
        ''',
        expectedOutput: '''
          $classSetupBoilerPlate
          main() {
            Foo()
            ${getCheckboxComment(keysOfModdedValues: ['width'])}
            ..style = {
              'width': 40,
            }
          }
        ''',
      );
    });

    test('adds a comment then the map value is a variable', () {
      testSuggestor(
        expectedPatchCount: 2,
        input: '''
          $classSetupBoilerPlate
            main() {
              Foo()
              ..style = {
                'width': '40px',
              }
            }
        ''',
        expectedOutput: '''
          $classSetupBoilerPlate
          main() {
            Foo()
            ${getCheckboxComment(keysOfModdedValues: ['width'])}
            ..style = {
              'width': 40,
            }
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
            ? 'for the keys ${keysOfModdedValues.join(', ')}.'
            : 'for the keys that are numbers.'}'
        '$willBeRemovedCommentSuffix';

String manualVariableCheckComment({List<String> keysOfModdedValues: const []}) =>
    '// [ ] Check this box upon manual validation that '
        'the style map is receiving a value that is a num for the keys '
        '${keysOfModdedValues.isNotEmpty
        ? '${keysOfModdedValues.join(', ')}.'
        : 'that are variables.'}'
        '$willBeRemovedCommentSuffix';



final checkboxComment = getCheckboxComment();
final classSetupBoilerPlate = '''
  class Foo {
    Map style;
  }
''';

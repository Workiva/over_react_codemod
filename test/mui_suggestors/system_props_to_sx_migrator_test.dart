// Copyright 2026 Workiva Inc.
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

import 'dart:convert';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:collection/collection.dart';
import 'package:over_react_codemod/src/mui_suggestors/system_props_to_sx_migrator.dart';
import 'package:test/test.dart';

import '../resolved_file_context.dart';
import '../util.dart';

void main() {
  group('SystemPropsToSxMigrator', () {
    final resolvedContext = SharedAnalysisContext.overReact;

    late String muiUri;

    setUpAll(() async {
      await resolvedContext.warmUpAnalysis();

      // Set up a file with stubbed MUI components with system props, for the
      // test inputs to import and the suggestor to detect.
      final muiFile = await resolvedContext.resolvedFileContextForTest(
        getStubMuiLibrarySource(filenameWithoutExtension: 'mui_components'),
        filename: 'mui_components.dart',
      );
      muiUri = Uri.file(muiFile.path).toString();
    });

    String withImports(String source) => '''
      //@dart=2.19
      import 'package:over_react/over_react.dart';
      import ${jsonEncode(muiUri.toString())};
      $source
    ''';

    const sxPrecedenceFixme =
        '// FIXME(mui_system_props_migration) - Previously, it was possible for forwarded system props to overwrite these migrated styles, but not anymore since sx takes precedence over any system props.'
        '\n //  Double-check that this new behavior is okay.';

    const sxMergeFixme =
        '// FIXME(mui_system_props_migration) - spread in any sx prop forwarded to this component above, if needed (spread should go at the end of this map to preserve behavior)';

    final testSuggestor = getSuggestorTester(
      SystemPropsToSxMigrator(),
      resolvedContext: resolvedContext,
    );

    group('hasSxAndSomeSystemProps returns as expected for test props:', () {
      late ResolvedUnitResult unit;

      setUpAll(() async {
        final file =
            await resolvedContext.resolvedFileContextForTest(withImports(''));
        unit = (await file.getResolvedUnit())!;
      });

      InterfaceElement getProps(String propsName) =>
          getImportedInterfaceElement(unit, propsName);

      test('with system props', () async {
        expect(
          hasSxAndSomeSystemProps(getProps('BoxProps')),
          isTrue,
        );
        expect(hasSxAndSomeSystemProps(getProps('GridProps')), isTrue);
        expect(hasSxAndSomeSystemProps(getProps('StackProps')), isTrue);
        expect(hasSxAndSomeSystemProps(getProps('TypographyProps')), isTrue);
      });

      test('without system props', () async {
        // Test props with sx and a prop named like a system prop.
        expect(hasSxAndSomeSystemProps(getProps('TextFieldProps')), isFalse);
        // Some other props from over_react.
        expect(hasSxAndSomeSystemProps(getProps('DomProps')), isFalse);
      });
    });

    test('migrates single system prop to sx', () async {
      await testSuggestor(
        input: withImports('''
            content() => 
                (Box()..mt = 2)();
        '''),
        expectedOutput: withImports('''
            content() => 
                (Box()..sx = {'mt': 2})();
        '''),
      );
    });

    test('migrates multiple system props', () async {
      await testSuggestor(
        input: withImports('''
            content() => 
                (Box()
                  ..mt = 2
                  ..p = 3
                  ..bgcolor = 'primary.main'
                )();
        '''),
        expectedOutput: withImports('''
            content() => 
                (Box()
                  ..sx = {
                    'mt': 2, 
                    'p': 3, 
                    'bgcolor': 'primary.main',
                  }
                )();
        '''),
      );
    });

    group('merges with existing sx map literal', () {
      test('without trailing commas', () async {
        await testSuggestor(
          input: withImports('''
              content() => 
                  (Box()
                    ..sx = {'border': '1px solid black'}
                    ..mt = 2
                  )();
          '''),
          expectedOutput: withImports('''
              content() => 
                  (Box()
                    ..sx = { 
                      'mt': 2,
                      'border': '1px solid black',
                    }
                  )();
          '''),
        );
      });

      test('with trailing commas', () async {
        await testSuggestor(
          input: withImports('''
              content() => 
                  (Box()
                    ..sx = {
                      'border': '1px solid black',
                    }
                    ..mt = 2
                  )();
          '''),
          expectedOutput: withImports('''
              content() => 
                  (Box()
                    ..sx = { 
                      'mt': 2,
                      'border': '1px solid black',
                    }
                  )();
          '''),
        );
      });

      test('that is empty', () async {
        await testSuggestor(
          input: withImports('''
              content() => 
                  (Box()
                    ..sx = {}
                    ..mt = 2
                  )();
          '''),
          expectedOutput: withImports('''
              content() => 
                  (Box()
                    ..sx = {
                      'mt': 2,
                    }
                  )();
          '''),
        );
      });

      test('with multiple existing entries', () async {
        await testSuggestor(
          input: withImports('''
              content() => 
                  (Box()
                    ..sx = {
                      'backgroundColor': 'white',
                      'color': 'blue',
                    }
                    ..mt = 2
                  )();
          '''),
          expectedOutput: withImports('''
              content() => 
                  (Box()
                    ..sx = { 
                      'mt': 2,
                      'backgroundColor': 'white',
                      'color': 'blue',
                    }
                  )();
          '''),
        );
      });
    });

    group('merges with forwarded sx prop using spread:', () {
      test('nullable', () async {
        await testSuggestor(
          input: withImports('''
              content(BoxProps props) =>
                  (Box()
                    ..sx = getSx()
                    ..mt = 2
                  )();
              Map? getSx() => {'color': 'red'};
          '''),
          expectedOutput: withImports('''
              content(BoxProps props) =>
                  (Box()
                    ..sx = {
                      'mt': 2,
                      ...?getSx(), 
                    }
                  )();
              Map? getSx() => {'color': 'red'};
          '''),
        );
      });

      test('non-nullable', () async {
        await testSuggestor(
          input: withImports('''
              content(BoxProps props) =>
                  (Box()
                    ..sx = getSx()
                    ..mt = 2
                  )();
              Map getSx() => {'color': 'red'};
          '''),
          expectedOutput: withImports('''
              content(BoxProps props) =>
                  (Box()
                    ..sx = {'mt': 2, ...getSx()}
                  )();
              Map getSx() => {'color': 'red'};
          '''),
        );
      });

      test('dynamic', () async {
        await testSuggestor(
          input: withImports('''
              content(BoxProps props) =>
                  (Box()
                    ..sx = getSx()
                    ..mt = 2
                  )();
              dynamic getSx() => {'color': 'red'};
          '''),
          expectedOutput: withImports('''
              content(BoxProps props) =>
                  (Box()
                    ..sx = {
                      'mt': 2,
                      ...?getSx(), 
                    }
                  )();
              dynamic getSx() => {'color': 'red'};
          '''),
        );
      });
    });

    group('merges in sx from forwarded props', () {
      group('forwarded with', () {
        test('addProps', () async {
          await testSuggestor(
            input: withImports('''
                content(BoxProps props) =>
                    (Box()
                      ..addProps(props)
                      ..mt = 2
                    )();
            '''),
            expectedOutput: withImports('''
                content(BoxProps props) =>
                    (Box()
                      ..addProps(props)
                      ..sx = {'mt': 2, ...?props.sx,}
                    )();
            '''),
          );
        });

        test('addAll', () async {
          await testSuggestor(
            input: withImports('''
                content(BoxProps props) =>
                    (Box()
                      ..addAll(props)
                      ..mt = 2
                    )();
            '''),
            expectedOutput: withImports('''
                content(BoxProps props) =>
                    (Box()
                      ..addAll(props)
                      ..sx = {'mt': 2, ...?props.sx,}
                    )();
            '''),
          );
        });

        test('getPropsToForward', () async {
          await testSuggestor(
            input: withImports('''
                content(BoxProps props) =>
                    (Box()
                      ..addProps(props.getPropsToForward())
                      ..mt = 2
                    )();
            '''),
            expectedOutput: withImports('''
                content(BoxProps props) =>
                    (Box()
                      ..addProps(props.getPropsToForward())
                      ..sx = {'mt': 2, ...?props.sx,}
                    )();
            '''),
          );
        });

        test('addPropsToForward', () async {
          await testSuggestor(
            input: withImports('''
                content(BoxProps props) =>
                    (Box()
                      ..modifyProps(props.addPropsToForward())
                      ..mt = 2
                    )();
            '''),
            expectedOutput: withImports('''
                content(BoxProps props) =>
                    (Box()
                      ..modifyProps(props.addPropsToForward())
                      ..sx = {'mt': 2, ...?props.sx,}
                    )();
            '''),
          );
        });
      });

      // Regression test
      test('even when there are other unrelated calls in the cascade',
          () async {
        await testSuggestor(
          input: withImports('''
              content(BoxProps props) =>
                  (Box()
                    ..addProps(props)
                    ..addTestId('test-id')
                    ..mt = 2
                  )();
          '''),
          expectedOutput: withImports('''
              content(BoxProps props) =>
                  (Box()
                    ..addProps(props)
                    ..addTestId('test-id')
                    ..sx = {'mt': 2, ...?props.sx,}
                  )();
          '''),
        );
      });
    });

    group('adds FIXME comment when forwarding is ambiguous:', () {
      test('modifyProps with unknown function', () async {
        await testSuggestor(
          input: withImports('''
              content(BoxProps props) =>
                  (Box()
                    ..modifyProps((_) {})
                    ..mt = 2
                  )();
          '''),
          expectedOutput: withImports('''
              content(BoxProps props) =>
                  (Box()
                    ..modifyProps((_) {})
  
                    $sxMergeFixme
                    ..sx = {
                      'mt': 2
                    }
                  )();
          '''),
        );
      });

      test('copyUnconsumedProps', () async {
        await testSuggestor(
          input: withImports('''
              abstract class FooComponent extends UiComponent2 {
                content(BoxProps props) =>
                    (Box()
                      ..addProps(copyUnconsumedProps())
                      ..mt = 2
                    )();
              }
          '''),
          expectedOutput: withImports('''
              abstract class FooComponent extends UiComponent2 {
                content(BoxProps props) =>
                    (Box()
                      ..addProps(copyUnconsumedProps())
  
                      $sxMergeFixme
                      ..sx = {
                        'mt': 2
                      }
                    )();
              }
          '''),
        );
      });

      group('generic props:', () {
        test('Map', () async {
          await testSuggestor(
            input: withImports('''
                content(Map props) {
                  (Box()
                    ..addAll(props)
                    ..mt = 2
                  )();
                }
            '''),
            expectedOutput: withImports('''
                content(Map props) {
                  (Box()
                    ..addAll(props)

                    $sxMergeFixme
                    ..sx = {
                      'mt': 2
                    }
                  )();
                }
            '''),
          );
        });

        test('UiProps', () async {
          await testSuggestor(
            input: withImports('''
                content(UiProps props) {
                  (Box()
                    ..addAll(props)
                    ..mt = 2
                  )();
                }
            '''),
            expectedOutput: withImports('''
                content(UiProps props) {
                  (Box()
                    ..addAll(props)

                    $sxMergeFixme
                    ..sx = {
                      'mt': 2
                    }
                  )();
                }
            '''),
          );
        });

        test('dynamic', () async {
          await testSuggestor(
            input: withImports('''
                content(dynamic props) {
                  (Box()
                    ..addAll(props)
                    ..mt = 2
                  )();
                }
            '''),
            expectedOutput: withImports('''
                content(dynamic props) {
                  (Box()
                    ..addAll(props)

                    $sxMergeFixme
                    ..sx = {
                      'mt': 2
                    }
                  )();
                }
            '''),
          );
        });
      });

      test('multiple prop forwarding calls', () async {
        await testSuggestor(
          input: withImports('''
              content(BoxProps props, BoxProps props2) {
                (Box()
                  ..addProps(props)
                  ..addProps(props2)
                  ..mt = 2
                )();
              }
          '''),
          expectedOutput: withImports('''
              content(BoxProps props, BoxProps props2) {
                (Box()
                  ..addProps(props)
                  ..addProps(props2)

                  $sxMergeFixme
                  ..sx = {
                    'mt': 2
                  }
                )();
              }
          '''),
        );
      });
    });

    test('handles complex prop values with expressions', () async {
      await testSuggestor(
        input: withImports('''
            content(bool condition) {
              (Box()
                ..mt = condition ? 2 : 4
                ..p = getSpacing()
              )();
            }
            int getSpacing() => 3;
        '''),
        expectedOutput: withImports('''
            content(bool condition) {
              (Box()
                ..sx = {
                  'mt': condition ? 2 : 4, 
                  'p': getSpacing(),
                }
              )();
            }
            int getSpacing() => 3;
        '''),
      );
    });

    test('handles responsive system prop values', () async {
      await testSuggestor(
        input: withImports('''
            content() => 
                (Box()
                  ..mt = {'xs': 1, 'sm': 2, 'md': 3}
                )();
        '''),
        expectedOutput: withImports('''
            content() => 
                (Box()
                  ..sx = {'mt': {'xs': 1, 'sm': 2, 'md': 3}}
                )();
        '''),
      );
    });

    test('preserves non-system props', () async {
      await testSuggestor(
        input: withImports('''
            content() => 
                (Box()
                  ..id = 'test'
                  ..mt = 2
                  ..className = 'custom-class'
                  ..onClick = (_) {}
                )();
        '''),
        expectedOutput: withImports('''
            content() => 
                (Box()
                  ..id = 'test'
                  ..sx = {'mt': 2}
                  ..className = 'custom-class'
                  ..onClick = (_) {}
                )();
        '''),
      );
    });

    test('handles multiple components in the same file', () async {
      await testSuggestor(
        input: withImports('''
            content() {
              (Box()..mt = 2)();
              (Box()..p = 3)();
            }
        '''),
        expectedOutput: withImports('''
            content() { 
              (Box()..sx = {'mt': 2})();
              (Box()..sx = {'p': 3})();
            }
        '''),
      );
    });

    test('respects orcm_ignore comments', () async {
      await testSuggestor(
        input: withImports('''
            // orcm_ignore
            content() => (Box()..mt = 2)();
        '''),
      );
    });

    test('does not migrate components without deprecated system props',
        () async {
      await testSuggestor(
        input: withImports('''
            content() => 
                (Box()
                  ..id = 'test'
                  ..className = 'test-class'
                )();
        '''),
      );
    });

    test('does not migrate deprecated props with the same name as system props',
        () async {
      await testSuggestor(
        input: withImports('''
            content() => (TextField()..color = '')();
        '''),
      );
    });

    test('does not flag unrelated cascades with FIXMEs', () async {
      await testSuggestor(
        input: withImports('''
            content() => 
                (Box()
                  ..addProp('foo', 'bar')
                  ..['bar'] = 'baz'
                  ..ref = (_) {}
                  ..className = 'test-class'
                )();
        '''),
      );
    });

    group('adds a fixme when there are forwarded props after system props and',
        () {
      test('an existing sx map literal', () async {
        await testSuggestor(
          input: withImports('''
              content(BoxProps props) =>
                  (Box()
                    ..mt = 2
                    ..addProps(props)
                    ..sx = {'border': '1px solid black'}
                  )();
          '''),
          expectedOutput: withImports('''
              content(BoxProps props) =>
                  (Box()
                    ..addProps(props)
                    ..sx = {
                       $sxPrecedenceFixme

                      'mt': 2, 'border': '1px solid black', 
                    }
                  )();
          '''),
        );
      });

      test('an existing sx value', () async {
        await testSuggestor(
          input: withImports('''
              content(BoxProps props) =>
                  (Box()
                    ..mt = 2
                    ..addProps(props)
                    ..sx = getSx()
                  )();
              Map getSx() => {'color': 'red'};
          '''),
          expectedOutput: withImports('''
              content(BoxProps props) =>
                  (Box()
                    ..addProps(props)
                    ..sx = {
                      $sxPrecedenceFixme
                     
                      'mt': 2, ...getSx()
                    }
                  )();
              Map getSx() => {'color': 'red'};
          '''),
        );
      });

      test('no existing sx', () async {
        await testSuggestor(
          input: withImports('''
              content(BoxProps props) =>
                  (Box()
                    ..mt = 2
                    ..addProps(props)
                  )();
          '''),
          expectedOutput: withImports('''
              content(BoxProps props) =>
                  (Box()
                    ..addProps(props)
                     $sxPrecedenceFixme
                    ..sx = {
                      'mt': 2, 
                      ...?props.sx,
                    }
                  )();
          '''),
        );
      });
    });

    group('insertion location:', () {
      test('inserts after prop forwarding to avoid being overwritten',
          () async {
        await testSuggestor(
          input: withImports('''
              content(BoxProps props) =>
                  (Box()
                    ..mt = 2
                    ..addProps(props)
                    ..id = 'test'
                  )();
          '''),
          expectedOutput: withImports('''
              content(BoxProps props) =>
                  (Box()
                    ..addProps(props)
                     $sxPrecedenceFixme
                    ..sx = {'mt': 2, ...?props.sx,}
                    ..id = 'test'
                  )();
          '''),
        );
      });

      test('inserts at location of last system prop when no prop forwarding',
          () async {
        await testSuggestor(
          input: withImports('''
              content() => 
                  (Box()
                    ..id = 'first'
                    ..mt = 2
                    ..className = 'middle'
                    ..p = 3
                    ..onClick = (_) {}
                  )();
          '''),
          expectedOutput: withImports('''
              content() => 
                  (Box()
                    ..id = 'first'
                    ..className = 'middle'
                    ..sx = {'mt': 2, 'p': 3}
                    ..onClick = (_) {}
                  )();
          '''),
        );
      });

      test('inserts after latest of (forwarding or last system prop)',
          () async {
        await testSuggestor(
          input: withImports('''
              content(BoxProps props) =>
                  (Box()
                    ..mt = 2
                    ..addProps(props)
                    ..p = 3
                  )();
          '''),
          expectedOutput: withImports('''
              content(BoxProps props) =>
                  (Box()
                    ..addProps(props)
                    
                    $sxPrecedenceFixme
                    ..sx = {'mt': 2, 'p': 3, ...?props.sx,}
                  )();
          '''),
        );
      });

      test('inserts after all forwarding calls when multiple exist', () async {
        await testSuggestor(
          input: withImports('''
              content(BoxProps props1, BoxProps props2) =>
                  (Box()
                    ..addProps(props1)
                    ..mt = 2
                    ..p = 3
                    ..addProps(props2)
                  )();
          '''),
          expectedOutput: withImports('''
              content(BoxProps props1, BoxProps props2) =>
                  (Box()
                    ..addProps(props1)
                    ..addProps(props2)
                    $sxPrecedenceFixme
                    $sxMergeFixme
                    ..sx = {'mt': 2, 'p': 3}
                  )();
          '''),
        );
      });
    });

    group('multiline formatting:', () {
      test('uses single line for short sx maps (< 3 elements)', () async {
        await testSuggestor(
          input: withImports('''
              content() => 
                  (Box()
                    ..mt = 2
                    ..p = 3
                  )();
          '''),
          expectedOutput: withImports('''
              content() => 
                  (Box()
                    ..sx = {'mt': 2, 'p': 3}
                  )();
          '''),
        );
      });

      test('uses multiline for 3+ elements', () async {
        await testSuggestor(
          input: withImports('''
              content() => 
                  (Box()
                    ..mt = 2
                    ..p = 3
                    ..mb = 4
                  )();
          '''),
          expectedOutput: withImports('''
              content() => 
                  (Box()
                    ..sx = {
                      'mt': 2, 
                      'p': 3, 
                      'mb': 4,
                    }
                  )();
          '''),
        );
      });

      test('uses multiline for long content (>= 20 chars with 2+ elements)',
          () async {
        await testSuggestor(
          input: withImports('''
              content() => 
                  (Box()
                    ..mt = 2
                    ..bgcolor = 'verylongcolor.main'
                  )();
          '''),
          expectedOutput: withImports('''
              content() => 
                  (Box()
                    ..sx = {
                      'mt': 2, 
                      'bgcolor': 'verylongcolor.main',
                    }
                  )();
          '''),
        );
      });
    });

    group('preserves comments before system props:', () {
      test('single line comment before single system prop', () async {
        await testSuggestor(
          input: withImports('''
              content() => 
                  (Box()
                    // Add margin
                    ..mt = 2
                  )();
          '''),
          expectedOutput: withImports('''
              content() => 
                  (Box()
                    ..sx = {
                      // Add margin
                      'mt': 2,
                    }
                  )();
          '''),
        );
      });

      test('single line comment before one of multiple system props', () async {
        await testSuggestor(
          input: withImports('''
              content() => 
                  (Box()
                    ..mt = 2
                    // Add padding
                    ..p = 3
                  )();
          '''),
          expectedOutput: withImports('''
              content() => 
                  (Box()
                    ..sx = {
                      'mt': 2, 
                      // Add padding
                      'p': 3,
                    }
                  )();
          '''),
        );
      });

      test('multiple comments before different system props', () async {
        await testSuggestor(
          input: withImports('''
              content() => 
                  (Box()
                    // Top margin
                    ..mt = 2
                    // Horizontal padding
                    ..px = 3
                    // Background color
                    ..bgcolor = 'blue'
                  )();
          '''),
          expectedOutput: withImports('''
              content() => 
                  (Box()
                    ..sx = {
                      // Top margin
                      'mt': 2, 
                      // Horizontal padding
                      'px': 3, 
                      // Background color
                      'bgcolor': 'blue',
                    }
                  )();
          '''),
        );
      });

      test('multi-line comment before system prop', () async {
        await testSuggestor(
          input: withImports('''
              content() => 
                  (Box()
                    /* This is a longer comment
                       explaining the margin */
                    ..mt = 2
                  )();
          '''),
          expectedOutput: withImports('''
              content() => 
                  (Box()
                    ..sx = {
                      /* This is a longer comment
                       explaining the margin */
                      'mt': 2,
                    }
                  )();
          '''),
        );
      });

      test('comment before system prop with existing sx', () async {
        await testSuggestor(
          input: withImports('''
              content() => 
                  (Box()
                    ..sx = {'border': '1px solid black'}
                    // Add margin
                    ..mt = 2
                  )();
          '''),
          // Not sure why dartfmt allows two entries like this with trailing commas
          // on the same line, but it is what it is.
          expectedOutput: withImports('''
              content() => 
                  (Box()
                    ..sx = {
                      // Add margin
                      'mt': 2, 'border': '1px solid black',
                    }
                  )();
          '''),
        );
      });

      test('comments before system props mixed with non-system props',
          () async {
        await testSuggestor(
          input: withImports('''
              content() => 
                  (Box()
                    ..id = 'test'
                    // Spacing
                    ..mt = 2
                    ..className = 'custom'
                    // More spacing
                    ..p = 3
                  )();
          '''),
          expectedOutput: withImports('''
              content() => 
                  (Box()
                    ..id = 'test'
                    ..className = 'custom'
                    ..sx = {
                      // Spacing
                      'mt': 2, 
                      // More spacing
                      'p': 3,
                    }
                  )();
          '''),
        );
      });

      test('comment before system prop with forwarding', () async {
        await testSuggestor(
          input: withImports('''
              content(BoxProps props) => 
                  (Box()
                    ..addProps(props)
                    // Override margin
                    ..mt = 2
                  )();
          '''),
          // Not sure why dartfmt allows two entries like this with trailing commas
          // on the same line, but it is what it is.
          expectedOutput: withImports('''
              content(BoxProps props) => 
                  (Box()
                    ..addProps(props)

                    ..sx = {
                      // Override margin
                      'mt': 2, ...?props.sx, 
                    }
                  )();
          '''),
        );
      });

      test('inline comment on same line as system prop', () async {
        await testSuggestor(
          input: withImports('''
              content() => 
                  (Box()
                    ..mt = 2 // top margin
                    ..p = 3
                  )();
          '''),
          // Inline comment behavior here isn't great, but it's too much effort
          // to deal with in this codemod.
          // Just verify the codemod doesn't break or do anything too outlandish.
          expectedOutput: withImports('''
              content() => 
                  (Box()
                   // top margin
                    ..sx = {'mt': 2, 'p': 3}
                  )();
          '''),
        );
      });

      test('multiple comment types with system props', () async {
        await testSuggestor(
          input: withImports('''
              content() => 
                  (Box()
                    // Line comment
                    ..mt = 2 // inline comment
                    /* Block comment */
                    ..p = 3
                  )();
          '''),
          // Inline comment behavior here isn't great, but it's too much effort
          // to deal with in this codemod.
          // Just verify the codemod doesn't break or do anything too outlandish.
          expectedOutput: withImports('''
              content() => 
                  (Box()
                   // inline comment
                    ..sx = {
                      // Line comment
                      'mt': 2,
                      /* Block comment */
                      'p': 3,
                    }
                  )();
          '''),
        );
      });
    });

    group('handles different component types with system props:', () {
      test('Box', () async {
        await testSuggestor(
          input: withImports('''
              content() => (Box()..mt = 2)();
          '''),
          expectedOutput: withImports('''
              content() => (Box()..sx = {'mt': 2})();
          '''),
        );
      });

      test('Grid', () async {
        await testSuggestor(
          input: withImports('''
              content() => (Grid()..mt = 2)();
          '''),
          expectedOutput: withImports('''
              content() => (Grid()..sx = {'mt': 2})();
          '''),
        );
      });

      test('Stack', () async {
        await testSuggestor(
          input: withImports('''
              content() => (Stack()..mt = 2)();
          '''),
          expectedOutput: withImports('''
              content() => (Stack()..sx = {'mt': 2})();
          '''),
        );
      });

      test('Typography', () async {
        await testSuggestor(
          input: withImports('''
              content() => (Typography()..mt = 2)();
          '''),
          expectedOutput: withImports('''
              content() => (Typography()..sx = {'mt': 2})();
          '''),
        );
      });
    });
  });
}

String getStubMuiLibrarySource({required String filenameWithoutExtension}) {
  final systemPropComponentsSource = [
    'Box',
    'Grid',
    'Stack',
    'Typography',
  ].map((componentName) {
    return '''
      UiFactory<${componentName}Props> $componentName = uiFunction((_) {}, _\$${componentName}Config);
      
      @Props(keyNamespace: '')
      mixin ${componentName}Props on UiProps {
        @convertJsMapProp
        Map? sx;
      
        ${systemPropNames.map((propName) => "  @Deprecated('Use sx.') dynamic ${propName};").join('\n')}
      }
  ''';
  }).join('\n\n');

  return '''
      //@dart=2.19
      import 'package:over_react/over_react.dart';
      import 'package:over_react/js_component.dart';

      // ignore: uri_has_not_been_generated
      part '$filenameWithoutExtension.over_react.g.dart';
      
      $systemPropComponentsSource
      
      UiFactory<TextFieldProps> TextField = uiFunction((_) {}, _\$TextFieldConfig);
      
      @Props(keyNamespace: '')
      mixin TextFieldProps on UiProps {
        @convertJsMapProp
        Map? sx;
      
        @Deprecated('Deprecated, but not the same as the system props color')
        dynamic color;
      }
  ''';
}

// Borrowed from https://github.com/Workiva/over_react/blob/5.6.0/tools/analyzer_plugin/test/unit/util/prop_declaration/util.dart#L73-L78

InterfaceElement getInterfaceElement(ResolvedUnitResult result, String name) =>
    result.libraryElement.topLevelElements
        .whereType<InterfaceElement>()
        .singleWhere((e) => e.name == name);

InterfaceElement getImportedInterfaceElement(
        ResolvedUnitResult result, String name) =>
    result.libraryElement.importedLibraries
        .map((l) => l.exportNamespace.get(name))
        .whereNotNull()
        .single as InterfaceElement;

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

import 'package:over_react_codemod/src/mui_suggestors/system_props_to_sx_migrator.dart';
import 'package:test/test.dart';

import '../resolved_file_context.dart';
import '../util.dart';

void main() {
  group('SystemPropsToSxMigrator', () {
    final resolvedContext = SharedAnalysisContext.wsd;
    setUpAll(resolvedContext.warmUpAnalysis);

    final testSuggestor = getSuggestorTester(
      SystemPropsToSxMigrator(),
      resolvedContext: resolvedContext,
    );

    test('migrates single system prop to sx', () async {
      await testSuggestor(
        input: withHeader(/*language=dart*/ '''
            content() => 
                (Box()..mt = 2)();
        '''),
        expectedOutput: withHeader(/*language=dart*/ '''
            content() => 
                (Box()..sx = {'mt': 2})();
        '''),
      );
    });

    test('migrates multiple system props', () async {
      await testSuggestor(
        input: withHeader(/*language=dart*/ '''
            content() => 
                (Box()
                  ..mt = 2
                  ..p = 3
                  ..bgcolor = 'primary.main'
                )();
        '''),
        expectedOutput: withHeader(/*language=dart*/ '''
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
          input: withHeader(/*language=dart*/ '''
              content() => 
                  (Box()
                    ..sx = {'border': '1px solid black'}
                    ..mt = 2
                  )();
          '''),
          expectedOutput: withHeader(/*language=dart*/ '''
              content() => 
                  (Box()
                    ..sx = {
                      'border': '1px solid black', 
                      'mt': 2,
                    }
                  )();
          '''),
        );
      });

      test('with trailing commas', () async {
        await testSuggestor(
          input: withHeader(/*language=dart*/ '''
              content() => 
                  (Box()
                    ..sx = {
                      'border': '1px solid black',
                    }
                    ..mt = 2
                  )();
          '''),
          expectedOutput: withHeader(/*language=dart*/ '''
              content() => 
                  (Box()
                    ..sx = {
                      'border': '1px solid black', 
                      'mt': 2,
                    }
                  )();
          '''),
        );
      });

      test('that is empty', () async {
        await testSuggestor(
          input: withHeader(/*language=dart*/ '''
              content() => 
                  (Box()
                    ..sx = {}
                    ..mt = 2
                  )();
          '''),
          expectedOutput: withHeader(/*language=dart*/ '''
              content() => 
                  (Box()
                    ..sx = {'mt': 2}
                  )();
          '''),
        );
      });

      test('with multiple existing entries', () async {
        await testSuggestor(
          input: withHeader(/*language=dart*/ '''
              content() => 
                  (Box()
                    ..sx = {
                      'backgroundColor': 'white',
                      'color': 'blue',
                    }
                    ..mt = 2
                  )();
          '''),
          expectedOutput: withHeader(/*language=dart*/ '''
              content() => 
                  (Box()
                    ..sx = {
                      'backgroundColor': 'white',
                      'color': 'blue', 
                      'mt': 2,
                    }
                  )();
          '''),
        );
      });
    });

    group('merges with forwarded sx prop using spread:', () {
      test('nullable', () async {
        await testSuggestor(
          input: withHeader(/*language=dart*/ '''
              content(BoxProps props) =>
                  (Box()
                    ..sx = getSx()
                    ..mt = 2
                  )();
              Map? getSx() => {'color': 'red'};
          '''),
          expectedOutput: withHeader(/*language=dart*/ '''
              content(BoxProps props) =>
                  (Box()
                    ..sx = {...?getSx(), 'mt': 2}
                  )();
              Map? getSx() => {'color': 'red'};
          '''),
        );
      });

      test('non-nullable', () async {
        await testSuggestor(
          input: withHeader(/*language=dart*/ '''
              content(BoxProps props) =>
                  (Box()
                    ..sx = getSx()
                    ..mt = 2
                  )();
              Map getSx() => {'color': 'red'};
          '''),
          expectedOutput: withHeader(/*language=dart*/ '''
              content(BoxProps props) =>
                  (Box()
                    ..sx = {...getSx(), 'mt': 2}
                  )();
              Map getSx() => {'color': 'red'};
          '''),
        );
      });

      test('dynamic', () async {
        await testSuggestor(
          input: withHeader(/*language=dart*/ '''
              content(BoxProps props) =>
                  (Box()
                    ..sx = getSx()
                    ..mt = 2
                  )();
              dynamic getSx() => {'color': 'red'};
          '''),
          expectedOutput: withHeader(/*language=dart*/ '''
              content(BoxProps props) =>
                  (Box()
                    ..sx = {...?getSx(), 'mt': 2}
                  )();
              dynamic getSx() => {'color': 'red'};
          '''),
        );
      });
    });

    test('does not consider forwarding with an existing sx', () async {
      await testSuggestor(
        input: withHeader(/*language=dart*/ '''
            content(BoxProps props) =>
                (Box()
                  ..addProps(props)
                  ..sx = {'border': '1px solid black'}
                  ..mt = 2
                )();
        '''),
        expectedOutput: withHeader(/*language=dart*/ '''
            content(BoxProps props) =>
                (Box()
                  ..addProps(props)
                  ..sx = {
                    'border': '1px solid black', 
                    'mt': 2,
                  }
                )();
        '''),
      );
    });

    group('merges in sx from forwarded props', () {
      group('forwarded with', () {
        test('addProps', () async {
          await testSuggestor(
            input: withHeader(/*language=dart*/ '''
                content(BoxProps props) =>
                    (Box()
                      ..addProps(props)
                      ..mt = 2
                    )();
            '''),
            expectedOutput: withHeader(/*language=dart*/ '''
                content(BoxProps props) =>
                    (Box()
                      ..addProps(props)
                      ..sx = {...?props.sx, 'mt': 2,}
                    )();
            '''),
          );
        });

        test('addAll', () async {
          await testSuggestor(
            input: withHeader(/*language=dart*/ '''
                content(BoxProps props) =>
                    (Box()
                      ..addAll(props)
                      ..mt = 2
                    )();
            '''),
            expectedOutput: withHeader(/*language=dart*/ '''
                content(BoxProps props) =>
                    (Box()
                      ..addAll(props)
                      ..sx = {...?props.sx, 'mt': 2,}
                    )();
            '''),
          );
        });

        test('getPropsToForward', () async {
          await testSuggestor(
            input: withHeader(/*language=dart*/ '''
                content(BoxProps props) =>
                    (Box()
                      ..addProps(props.getPropsToForward())
                      ..mt = 2
                    )();
            '''),
            expectedOutput: withHeader(/*language=dart*/ '''
                content(BoxProps props) =>
                    (Box()
                      ..addProps(props.getPropsToForward())
                      ..sx = {...?props.sx, 'mt': 2,}
                    )();
            '''),
          );
        });

        test('addPropsToForward', () async {
          await testSuggestor(
            input: withHeader(/*language=dart*/ '''
                content(BoxProps props) =>
                    (Box()
                      ..modifyProps(props.addPropsToForward())
                      ..mt = 2
                    )();
            '''),
            expectedOutput: withHeader(/*language=dart*/ '''
                content(BoxProps props) =>
                    (Box()
                      ..modifyProps(props.addPropsToForward())
                      ..sx = {...?props.sx, 'mt': 2,}
                    )();
            '''),
          );
        });
      });

      // Regression test
      test('even when there are other unrelated calls in the cascade',
          () async {
        await testSuggestor(
          input: withHeader(/*language=dart*/ '''
              content(BoxProps props) =>
                  (Box()
                    ..addProps(props)
                    ..addTestId('test-id')
                    ..mt = 2
                  )();
          '''),
          expectedOutput: withHeader(/*language=dart*/ '''
              content(BoxProps props) =>
                  (Box()
                    ..addProps(props)
                    ..addTestId('test-id')
                    ..sx = {...?props.sx, 'mt': 2,}
                  )();
          '''),
        );
      });
    });

    group('adds FIXME comment when forwarding is ambiguous:', () {
      test('modifyProps with unknown function', () async {
        await testSuggestor(
          input: withHeader(/*language=dart*/ '''
              content(BoxProps props) =>
                  (Box()
                    ..modifyProps((_) {})
                    ..mt = 2
                  )();
          '''),
          expectedOutput: withHeader(/*language=dart*/ '''
              content(BoxProps props) =>
                  (Box()
                    ..modifyProps((_) {})
  
                    // FIXME(mui_system_props_migration) - merge in any sx prop forwarded to this component, if needed
                    ..sx = {
                      'mt': 2
                    }
                  )();
          '''),
        );
      });

      test('copyUnconsumedProps', () async {
        await testSuggestor(
          input: withHeader(/*language=dart*/ '''
              abstract class FooComponent extends UiComponent2 {
                content(BoxProps props) =>
                    (Box()
                      ..addProps(copyUnconsumedProps())
                      ..mt = 2
                    )();
              }
          '''),
          expectedOutput: withHeader(/*language=dart*/ '''
              abstract class FooComponent extends UiComponent2 {
                content(BoxProps props) =>
                    (Box()
                      ..addProps(copyUnconsumedProps())
  
                      // FIXME(mui_system_props_migration) - merge in any sx prop forwarded to this component, if needed
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
            input: withHeader(/*language=dart*/ '''
                content(Map props) {
                  (Box()
                    ..addAll(props)
                    ..mt = 2
                  )();
                }
            '''),
            expectedOutput: withHeader(/*language=dart*/ '''
                content(Map props) {
                  (Box()
                    ..addAll(props)
                    
                    // FIXME(mui_system_props_migration) - merge in any sx prop forwarded to this component, if needed
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
            input: withHeader(/*language=dart*/ '''
                content(UiProps props) {
                  (Box()
                    ..addAll(props)
                    ..mt = 2
                  )();
                }
            '''),
            expectedOutput: withHeader(/*language=dart*/ '''
                content(UiProps props) {
                  (Box()
                    ..addAll(props)
                    
                    // FIXME(mui_system_props_migration) - merge in any sx prop forwarded to this component, if needed
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
            input: withHeader(/*language=dart*/ '''
                content(dynamic props) {
                  (Box()
                    ..addAll(props)
                    ..mt = 2
                  )();
                }
            '''),
            expectedOutput: withHeader(/*language=dart*/ '''
                content(dynamic props) {
                  (Box()
                    ..addAll(props)
                    
                    // FIXME(mui_system_props_migration) - merge in any sx prop forwarded to this component, if needed
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
          input: withHeader(/*language=dart*/ '''
              content(BoxProps props, BoxProps props2) {
                (Box()
                  ..addProps(props)
                  ..addProps(props2)
                  ..mt = 2
                )();
              }
          '''),
          expectedOutput: withHeader(/*language=dart*/ '''
              content(BoxProps props, BoxProps props2) {
                (Box()
                  ..addProps(props)
                  ..addProps(props2)

                  // FIXME(mui_system_props_migration) - merge in any sx prop forwarded to this component, if needed
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
        input: withHeader(/*language=dart*/ '''
            content(bool condition) {
              (Box()
                ..mt = condition ? 2 : 4
                ..p = getSpacing()
              )();
            }
            int getSpacing() => 3;
        '''),
        expectedOutput: withHeader(/*language=dart*/ '''
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
        input: withHeader(/*language=dart*/ '''
            content() => 
                (Box()
                  ..mt = {'xs': 1, 'sm': 2, 'md': 3}
                )();
        '''),
        expectedOutput: withHeader(/*language=dart*/ '''
            content() => 
                (Box()
                  ..sx = {'mt': {'xs': 1, 'sm': 2, 'md': 3}}
                )();
        '''),
      );
    });

    test('preserves non-system props', () async {
      await testSuggestor(
        input: withHeader(/*language=dart*/ '''
            content() => 
                (Box()
                  ..id = 'test'
                  ..mt = 2
                  ..className = 'custom-class'
                  ..onClick = (_) {}
                )();
        '''),
        expectedOutput: withHeader(/*language=dart*/ '''
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
        input: withHeader(/*language=dart*/ '''
            content() {
              (Box()..mt = 2)();
              (Box()..p = 3)();
            }
        '''),
        expectedOutput: withHeader(/*language=dart*/ '''
            content() { 
              (Box()..sx = {'mt': 2})();
              (Box()..sx = {'p': 3})();
            }
        '''),
      );
    });

    test('respects orcm_ignore comments', () async {
      await testSuggestor(
        input: withHeader(/*language=dart*/ '''
            // orcm_ignore
            content() => (Box()..mt = 2)();
        '''),
      );
    });

    test('does not migrate components without deprecated system props',
        () async {
      await testSuggestor(
        input: withHeader(/*language=dart*/ '''
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
        input: withHeader(/*language=dart*/ '''
            content() => (TextField()..color = '')();
        '''),
      );
    });

    test('does not flag unrelated cascades with FIXMEs', () async {
      await testSuggestor(
        input: withHeader(/*language=dart*/ '''
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



    group('insertion location:', () {
      test('inserts after prop forwarding to avoid being overwritten, with a comment', () async {
        await testSuggestor(
          input: withHeader(/*language=dart*/ '''
              content(BoxProps props) =>
                  (Box()
                    ..mt = 2
                    ..addProps(props)
                    ..id = 'test'
                  )();
          '''),
          expectedOutput: withHeader(/*language=dart*/ '''
              content(BoxProps props) =>
                  (Box()
                    ..addProps(props)
                     // FIXME(mui_system_props_migration) - Some of these system props used to be able to be overwritten by prop forwarding, but not anymore since sx takes precedence. Double-check that this new behavior is okay.
                    ..sx = {...?props.sx, 'mt': 2,}
                    ..id = 'test'
                  )();
          '''),
        );
      });

      test('inserts at location of last system prop when no prop forwarding', () async {
        await testSuggestor(
          input: withHeader(/*language=dart*/ '''
              content() => 
                  (Box()
                    ..id = 'first'
                    ..mt = 2
                    ..className = 'middle'
                    ..p = 3
                    ..onClick = (_) {}
                  )();
          '''),
          expectedOutput: withHeader(/*language=dart*/ '''
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

      test('inserts after latest of (forwarding or last system prop)', () async {
        await testSuggestor(
          input: withHeader(/*language=dart*/ '''
              content(BoxProps props) =>
                  (Box()
                    ..mt = 2
                    ..addProps(props)
                    ..p = 3
                  )();
          '''),
          expectedOutput: withHeader(/*language=dart*/ '''
              content(BoxProps props) =>
                  (Box()
                    ..addProps(props)
                    
                    // FIXME(mui_system_props_migration) - Some of these system props used to be able to be overwritten by prop forwarding, but not anymore since sx takes precedence. Double-check that this new behavior is okay.
                    ..sx = {...?props.sx, 'mt': 2, 'p': 3,}
                  )();
          '''),
        );
      });

      test('inserts after all forwarding calls when multiple exist', () async {
        await testSuggestor(
          input: withHeader(/*language=dart*/ '''
              content(BoxProps props1, BoxProps props2) =>
                  (Box()
                    ..addProps(props1)
                    ..mt = 2
                    ..p = 3
                    ..addProps(props2)
                  )();
          '''),
          expectedOutput: withHeader(/*language=dart*/ '''
              content(BoxProps props1, BoxProps props2) =>
                  (Box()
                    ..addProps(props1)
                    ..addProps(props2)
                    // FIXME(mui_system_props_migration) - merge in any sx prop forwarded to this component, if needed
                    ..sx = {'mt': 2, 'p': 3}
                  )();
          '''),
        );
      });
    });

    group('multiline formatting:', () {
      test('uses single line for short sx maps (< 3 elements)', () async {
        await testSuggestor(
          input: withHeader(/*language=dart*/ '''
              content() => 
                  (Box()
                    ..mt = 2
                    ..p = 3
                  )();
          '''),
          expectedOutput: withHeader(/*language=dart*/ '''
              content() => 
                  (Box()
                    ..sx = {'mt': 2, 'p': 3}
                  )();
          '''),
        );
      });

      test('uses multiline for 3+ elements', () async {
        await testSuggestor(
          input: withHeader(/*language=dart*/ '''
              content() => 
                  (Box()
                    ..mt = 2
                    ..p = 3
                    ..mb = 4
                  )();
          '''),
          expectedOutput: withHeader(/*language=dart*/ '''
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

      test('uses multiline for long content (>= 20 chars with 2+ elements)', () async {
        await testSuggestor(
          input: withHeader(/*language=dart*/ '''
              content() => 
                  (Box()
                    ..mt = 2
                    ..bgcolor = 'verylongcolor.main'
                  )();
          '''),
          expectedOutput: withHeader(/*language=dart*/ '''
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

    group('handles different component types with system props:', () {
      test('Box', () async {
        await testSuggestor(
          input: withHeader(/*language=dart*/ '''
              content() => (Box()..mt = 2)();
          '''),
          expectedOutput: withHeader(/*language=dart*/ '''
              content() => (Box()..sx = {'mt': 2})();
          '''),
        );
      });

      test('Grid', () async {
        await testSuggestor(
          input: withHeader(/*language=dart*/ '''
              content() => (Grid()..mt = 2)();
          '''),
          expectedOutput: withHeader(/*language=dart*/ '''
              content() => (Grid()..sx = {'mt': 2})();
          '''),
        );
      });

      test('Stack', () async {
        await testSuggestor(
          input: withHeader(/*language=dart*/ '''
              content() => (Stack()..mt = 2)();
          '''),
          expectedOutput: withHeader(/*language=dart*/ '''
              content() => (Stack()..sx = {'mt': 2})();
          '''),
        );
      });

      test('Typography', () async {
        await testSuggestor(
          input: withHeader(/*language=dart*/ '''
              content() => (Typography()..mt = 2)();
          '''),
          expectedOutput: withHeader(/*language=dart*/ '''
              content() => (Typography()..sx = {'mt': 2})();
          '''),
        );
      });
    });
  });
}

String withHeader(String source) => '''
  //@dart=2.19

  import 'package:over_react/over_react.dart';
  import 'package:unify_ui/unify_ui.dart';
  
  $source
''';

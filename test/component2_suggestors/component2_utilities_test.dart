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

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:over_react_codemod/src/component2_suggestors/component2_utilities.dart';
import 'package:test/test.dart';

void main() {
  group('Component2 Utilities:', () {
    group('getImportNamespace()', () {
      test('returns correct import namespace', () {
        final input = '''
          import "package:react/react_dom.dart" as react_dom;
          import "package:react/react.dart" as react show Component;
          
          class FooComponent extends react.Component {
            // class body
          }
        ''';

        CompilationUnit unit = parseString(content: input).unit;
        expect(unit.declarations.whereType<ClassDeclaration>().length, 1);

        unit.declarations.whereType<ClassDeclaration>().forEach((classNode) {
          expect(getImportNamespace(classNode, 'package:react/react_dom.dart'),
              'react_dom');
          expect(getImportNamespace(classNode, 'package:react/react.dart'),
              'react');
        });
      });

      test('returns null when import has no namespace', () {
        final input = '''
          import 'package:react/react_dom.dart';
          import 'package:react/react.dart' show Component;
          
          class FooComponent extends react.Component {
            // class body
          }
        ''';

        CompilationUnit unit = parseString(content: input).unit;
        expect(unit.declarations.whereType<ClassDeclaration>().length, 1);

        unit.declarations.whereType<ClassDeclaration>().forEach((classNode) {
          expect(getImportNamespace(classNode, 'package:react/react_dom.dart'),
              isNull);
          expect(getImportNamespace(classNode, 'package:react/react.dart'),
              isNull);
        });
      });

      test('returns null when import does not exist', () {
        final input = '''          
          class FooComponent extends react.Component {
            // class body
          }
        ''';

        CompilationUnit unit = parseString(content: input).unit;
        expect(unit.declarations.whereType<ClassDeclaration>().length, 1);

        unit.declarations.whereType<ClassDeclaration>().forEach((classNode) {
          expect(getImportNamespace(classNode, 'package:react/react_dom.dart'),
              isNull);
          expect(getImportNamespace(classNode, 'package:react/react.dart'),
              isNull);
        });
      });
    });

    group('extendsComponent2()', () {
      group('(Component2) when a class', () {
        group('extends UiComponent2,', () {
          final input = '''          
            @Component2()
            class FooComponent extends UiComponent2 {
              // class body
            }
          ''';

          testExtendsComponent2(input: input, expectedValue: true);
        });

        group('extends UiStatefulComponent2,', () {
          final input = '''
            @Component2          
            class FooComponent extends UiStatefulComponent2 {
              // class body
            }
          ''';

          testExtendsComponent2(input: input, expectedValue: true);
        });

        group('extends react.Component2,', () {
          final input = '''          
            import 'package:react/react.dart' as react;
            
            class FooComponent extends react.Component2 {
              // class body
            }
          ''';

          testExtendsComponent2(input: input, expectedValue: true);
        });

        group('has the @Component2 annotation,', () {
          final input = '''          
            @Component2
            class FooComponent extends SomeOtherClass {
              // class body
            }
          ''';

          testExtendsComponent2(input: input, expectedValue: true);
        });

        group('has the @AbstractComponent2 annotation,', () {
          final input = '''       
            @AbstractComponent2   
            class AbstractFooComponent extends SomeOtherClass {
              // class body
            }
          ''';

          testExtendsComponent2(input: input, expectedValue: true);
        });
      });

      group('(non-Component2) when a class', () {
        group('extends UiComponent,', () {
          final input = '''          
            @Component()
            class FooComponent extends UiComponent {
              // class body
            }
          ''';

          testExtendsComponent2(input: input, expectedValue: false);
        });

        group('extends UiStatefulComponent,', () {
          final input = '''
            @Component          
            class FooComponent extends UiStatefulComponent {
              // class body
            }
          ''';

          testExtendsComponent2(input: input, expectedValue: false);
        });

        group('extends FluxUiComponent,', () {
          final input = '''
            @Component          
            class FooComponent extends FluxUiComponent {
              // class body
            }
          ''';

          testExtendsComponent2(input: input, expectedValue: false);
        });

        group('extends FluxUiStatefulComponent,', () {
          final input = '''
            @Component          
            class FooComponent extends FluxUiStatefulComponent {
              // class body
            }
          ''';

          testExtendsComponent2(input: input, expectedValue: false);
        });

        group('extends react.Component,', () {
          final input = '''          
            import 'package:react/react.dart' as react;
            
            class FooComponent extends react.Component {
              // class body
            }
          ''';

          testExtendsComponent2(input: input, expectedValue: false);
        });

        group('has the @Component annotation,', () {
          final input = '''          
            @Component
            class FooComponent extends SomeOtherClass {
              // class body
            }
          ''';

          testExtendsComponent2(input: input, expectedValue: false);
        });

        group('has the @AbstractComponent annotation,', () {
          final input = '''       
            @AbstractComponent   
            class AbstractFooComponent extends SomeOtherClass {
              // class body
            }
          ''';

          testExtendsComponent2(input: input, expectedValue: false);
        });

        group('extends nothing', () {
          final input = '''
            class FooComponent {
              // class body
            }
          ''';

          testExtendsComponent2(input: input, expectedValue: false);
        });
      });
    });
  });
}

void testExtendsComponent2({String input, bool expectedValue}) {
  test('returns $expectedValue', () {
    CompilationUnit unit = parseString(content: input).unit;
    expect(unit.declarations.whereType<ClassDeclaration>().length, 1);

    unit.declarations.whereType<ClassDeclaration>().forEach((classNode) {
      if (expectedValue) {
        expect(extendsComponent2(classNode), isTrue);
      } else {
        expect(extendsComponent2(classNode), isFalse);
      }
    });
  });
}

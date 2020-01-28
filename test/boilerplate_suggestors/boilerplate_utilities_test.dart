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
    group('isAssociatedWithComponent2()', () {
      group('returns true', () {
        test('if component extending UiComponent2 is in the same file', () {
          final input = '''
            @Factory()
            UiFactory<FooProps> Foo =
                // ignore: undefined_identifier
                \$Foo;
            
            @Props()
            class _\$FooProps extends UiProps{
              String foo;
              int bar;
            }
            
            @Component2()
            class FooComponent extends UiComponent2<FooProps> {
              @override
              render() {
                return Dom.ul()(
                  Dom.li()('Foo: ', props.foo),
                  Dom.li()('Bar: ', props.bar),
                );
              }
            }
          ''';

          CompilationUnit unit = parseString(content: input).unit;
          expect(unit.declarations.whereType<ClassDeclaration>().length, 2);

          unit.declarations.whereType<ClassDeclaration>().forEach((classNode) {
            expect(isAssociatedWithComponent2(classNode), true);
          });
        });

        test('if Component2 extending a non-base class is in the same file', () {
          final input = '''
            @Factory()
            UiFactory<FooProps> Foo =
                // ignore: undefined_identifier
                \$Foo;
            
            @Props()
            class _\$FooProps extends UiProps{
              String foo;
              int bar;
            }
            
            @Component2()
            class FooComponent extends SomeClassName<FooProps> {
              @override
              render() {
                return Dom.ul()(
                  Dom.li()('Foo: ', props.foo),
                  Dom.li()('Bar: ', props.bar),
                );
              }
            }
          ''';

          CompilationUnit unit = parseString(content: input).unit;
          expect(unit.declarations.whereType<ClassDeclaration>().length, 2);

          unit.declarations.whereType<ClassDeclaration>().forEach((classNode) {
            expect(isAssociatedWithComponent2(classNode), true);
          });
        });
      });

      group('returns false', () {
        test('if component extending UiComponent is in the same file', () {
          final input = '''
            @Factory()
            UiFactory<FooProps> Foo =
                // ignore: undefined_identifier
                \$Foo;
            
            @Props()
            class _\$FooProps extends UiProps{
              String foo;
              int bar;
            }
            
            @Component()
            class FooComponent extends UiComponent<FooProps> {
              @override
              render() {
                return Dom.ul()(
                  Dom.li()('Foo: ', props.foo),
                  Dom.li()('Bar: ', props.bar),
                );
              }
            }
          ''';

          CompilationUnit unit = parseString(content: input).unit;
          expect(unit.declarations.whereType<ClassDeclaration>().length, 2);

          unit.declarations.whereType<ClassDeclaration>().forEach((classNode) {
            expect(isAssociatedWithComponent2(classNode), false);
          });
        });

        test('if Component extending a non-base class is in the same file', () {
          final input = '''
            @Factory()
            UiFactory<FooProps> Foo =
                // ignore: undefined_identifier
                \$Foo;
            
            @Props()
            class _\$FooProps extends UiProps{
              String foo;
              int bar;
            }
            
            @Component()
            class FooComponent extends SomeClassName<FooProps> {
              @override
              render() {
                return Dom.ul()(
                  Dom.li()('Foo: ', props.foo),
                  Dom.li()('Bar: ', props.bar),
                );
              }
            }
          ''';

          CompilationUnit unit = parseString(content: input).unit;
          expect(unit.declarations.whereType<ClassDeclaration>().length, 2);

          unit.declarations.whereType<ClassDeclaration>().forEach((classNode) {
            expect(isAssociatedWithComponent2(classNode), false);
          });
        });

        test('if there is no component class in the same file', () {
          final input = '''
            @Factory()
            UiFactory<FooProps> Foo =
                // ignore: undefined_identifier
                \$Foo;
            
            @Props()
            class _\$FooProps extends UiProps{
              String foo;
              int bar;
            }
          ''';

          CompilationUnit unit = parseString(content: input).unit;
          expect(unit.declarations.whereType<ClassDeclaration>().length, 1);

          unit.declarations.whereType<ClassDeclaration>().forEach((classNode) {
            expect(isAssociatedWithComponent2(classNode), false);
          });
        });
      });
    });
  });
}

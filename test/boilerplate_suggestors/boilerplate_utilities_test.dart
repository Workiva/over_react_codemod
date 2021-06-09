// @dart=2.7
// ^ Do not remove until migrated to null safety. More info at https://wiki.atl.workiva.net/pages/viewpage.action?pageId=189370832
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
  group('Boilerplate Utilities', () {
    group('isPropsUsageSimple', () {
      int assertionCount;

      setUp(() {
        assertionCount = 0;
      });

      test('will throw if not passed a props class', () {
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

        final unit = parseString(content: input).unit;
        final classDeclarations =
            unit.declarations.whereType<ClassDeclaration>();

        expect(classDeclarations.length, 2);

        classDeclarations.forEach((classNode) {
          if (!extendsFromUiPropsOrUiState(classNode)) {
            assertionCount++;
            expect(() => isSimplePropsOrStateClass(classNode),
                throwsA(TypeMatcher<AssertionError>()));
          }
        });

        expect(assertionCount, 1);
      });

      group('returns true if', () {
        test(
            'there are no mixins and the class extends from UiProps or UiState',
            () {
          final input = '''
            @Factory()
            UiFactory<FooProps> Foo =
                // ignore: undefined_identifier
                \$Foo;
            
            @Props()
            class _\$FooProps extends UiProps {
              String foo;
              int bar;
            }
            
            @State()
            class _\$FooState extends UiState {
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

          final unit = parseString(content: input).unit;
          final classDeclarations =
              unit.declarations.whereType<ClassDeclaration>();

          expect(classDeclarations.length, 3);

          classDeclarations.forEach((classNode) {
            if (isAPropsOrStateClass(classNode)) {
              assertionCount++;
              expect(isSimplePropsOrStateClass(classNode), isTrue);
            }
          });

          expect(assertionCount, 2);
        });
      });

      group('returns false if', () {
        test(
            'there are mixins and the class doesn\'t extend from UiProps or UiState',
            () {
          final input = '''
            @Factory()
            UiFactory<FooProps> Foo =
                // ignore: undefined_identifier
                \$Foo;
            
            @Props()
            class _\$FooProps extends ADifferentPropsClass with APropsMixin {
              String foo;
              int bar;
            }
            
            @State()
            class _\$FooState extends ADifferentStateClass with AStateMixin {
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

          final unit = parseString(content: input).unit;
          final classDeclarations =
              unit.declarations.whereType<ClassDeclaration>();

          expect(classDeclarations.length, 3);

          classDeclarations.forEach((classNode) {
            if (isAPropsOrStateClass(classNode)) {
              assertionCount++;
              expect(isSimplePropsOrStateClass(classNode), isFalse);
            }
          });

          expect(assertionCount, 2);
        });

        test('there are mixins but the class extends from UiProps or UiState',
            () {
          final input = '''
            @Factory()
            UiFactory<FooProps> Foo =
                // ignore: undefined_identifier
                \$Foo;
            
            @Props()
            class _\$FooProps extends UiProps with APropsMixin {
              String foo;
              int bar;
            }
            
            @State()
            class _\$FooState extends UiState with AStateMixin {
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

          final unit = parseString(content: input).unit;
          final classDeclarations =
              unit.declarations.whereType<ClassDeclaration>();

          expect(classDeclarations.length, 3);

          classDeclarations.forEach((classNode) {
            if (isAPropsOrStateClass(classNode)) {
              assertionCount++;
              expect(isSimplePropsOrStateClass(classNode), isFalse);
            }
          });

          expect(assertionCount, 2);
        });

        test(
            'there are no mixins but the class doesn\'t extend from UiProps or UiState',
            () {
          final input = '''
            @Factory()
            UiFactory<FooProps> Foo =
                // ignore: undefined_identifier
                \$Foo;
            
            @Props()
            class _\$FooProps extends ADifferentPropsClass {
              String foo;
              int bar;
            }
            
            @State()
            class _\$FooState extends ADifferentStateClass {
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

          final unit = parseString(content: input).unit;
          final classDeclarations =
              unit.declarations.whereType<ClassDeclaration>();

          expect(classDeclarations.length, 3);

          classDeclarations.forEach((classNode) {
            if (isAPropsOrStateClass(classNode)) {
              assertionCount++;
              expect(isSimplePropsOrStateClass(classNode), isFalse);
            }
          });

          expect(assertionCount, 2);
        });
      });
    });

    group('getSemverHelper() with isPublic() and getPublicExportLocations()',
        () {
      group('with --treat-all-components-as-private flag', () {
        semverUtilitiesTestHelper(
          shouldTreatAllComponentsAsPrivate: true,
        );
      });

      group('json file does not exist', () {
        semverUtilitiesTestHelper(
          path: 'test/boilerplate_suggestors/does_not_exist.json',
          isValidFilePath: false,
        );

        group('with --treat-all-components-as-private flag', () {
          semverUtilitiesTestHelper(
            path: 'test/boilerplate_suggestors/does_not_exist.json',
            shouldTreatAllComponentsAsPrivate: true,
            isValidFilePath: false,
          );
        });
      });

      group('json file does exist', () {
        semverUtilitiesTestHelper();
      });
    });
  });
}

void semverUtilitiesTestHelper({
  String path = 'test/boilerplate_suggestors/semver_report.json',
  bool shouldTreatAllComponentsAsPrivate = false,
  bool isValidFilePath = true,
}) {
  SemverHelper semverHelper;

  setUpAll(() {
    semverHelper = getSemverHelper(path,
        shouldTreatAllComponentsAsPrivate: shouldTreatAllComponentsAsPrivate);
  });

  test('correct warning', () {
    expect(
        semverHelper.warning,
        isValidFilePath || shouldTreatAllComponentsAsPrivate
            ? isNull
            : 'Could not find semver_report.json.');
  });

  group('if props class is not in export list', () {
    test('and is found in a file within lib/', () {
      final input = '''
        @Props()
        class _\$FooProps extends UiProps{
          String foo;
          int bar;
        }
      ''';

      final unit = parseString(content: input).unit;
      expect(unit.declarations.whereType<ClassDeclaration>().length, 1);

      unit.declarations.whereType<ClassDeclaration>().forEach((classNode) {
        expect(
            semverHelper.getPublicExportLocations(
                classNode, Uri.parse('lib/src/foo.dart')),
            isValidFilePath || shouldTreatAllComponentsAsPrivate
                ? isEmpty
                : [
                    'Semver report not available; this class is assumed to be public and thus will not be updated.'
                  ]);
        expect(isPublic(classNode, semverHelper, Uri.parse('lib/src/foo.dart')),
            !isValidFilePath && !shouldTreatAllComponentsAsPrivate);
      });
    });

    test('and is found in a file outside of lib/', () {
      final input = '''
        @Props()
        class _\$FooProps extends UiProps{
          String foo;
          int bar;
        }
      ''';

      final unit = parseString(content: input).unit;
      expect(unit.declarations.whereType<ClassDeclaration>().length, 1);

      unit.declarations.whereType<ClassDeclaration>().forEach((classNode) {
        expect(
            semverHelper.getPublicExportLocations(
                classNode, Uri.parse('web/src/foo.dart')),
            isEmpty);
        expect(isPublic(classNode, semverHelper, Uri.parse('web/src/foo.dart')),
            isFalse);
      });
    });
  });

  test('if props class is in export list', () {
    final input = '''
        @Props()
        class BarProps extends UiProps{
          String foo;
          int bar;
        }
      ''';
    final expectedOutput = isValidFilePath
        ? [
            'lib/web_skin_dart.dart/BarProps',
            'lib/another_file.dart/BarProps',
          ]
        : [
            'Semver report not available; this class is assumed to be public and thus will not be updated.'
          ];

    final unit = parseString(content: input).unit;
    expect(unit.declarations.whereType<ClassDeclaration>().length, 1);

    unit.declarations.whereType<ClassDeclaration>().forEach((classNode) {
      expect(
          semverHelper.getPublicExportLocations(
              classNode, Uri.parse('lib/src/foo.dart')),
          shouldTreatAllComponentsAsPrivate ? isEmpty : expectedOutput);
      expect(isPublic(classNode, semverHelper, Uri.parse('lib/src/foo.dart')),
          !shouldTreatAllComponentsAsPrivate);
    });
  });
}

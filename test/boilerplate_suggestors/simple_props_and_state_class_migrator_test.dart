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

import 'package:over_react_codemod/src/boilerplate_suggestors/boilerplate_utilities.dart';
import 'package:over_react_codemod/src/boilerplate_suggestors/simple_props_and_state_class_migrator.dart';
import 'package:test/test.dart';

import '../util.dart';

void main() {
  group('SimplePropsAndStateClassMigrator', () {
    simplePropsAndStateClassMigratorTestHelper();

    group('with --treat-all-components-as-private flag', () {
      simplePropsAndStateClassMigratorTestHelper(
        shouldTreatAllComponentsAsPrivate: true,
      );
    });

    group('with invalid file path', () {
      simplePropsAndStateClassMigratorTestHelper(
        path: 'test/boilerplate_suggestors/does_not_exist.json',
        isValidFilePath: false,
      );
    });
  });
}

void simplePropsAndStateClassMigratorTestHelper({
  String path = 'test/boilerplate_suggestors/semver_report.json',
  bool shouldTreatAllComponentsAsPrivate = false,
  bool isValidFilePath = true,
}) {
  group('', () {
    final converter = ClassToMixinConverter();
    final semverHelper = getSemverHelper(path,
        shouldTreatAllComponentsAsPrivate: shouldTreatAllComponentsAsPrivate);
    final testSuggestor = getSuggestorTester(
        SimplePropsAndStateClassMigrator(converter, semverHelper));

    tearDown(() {
      converter.setVisitedNames({});
    });

    group('does not migrate when', () {
      test('its an empty file', () {
        testSuggestor(expectedPatchCount: 0, input: '');

        expect(converter.visitedNames, isEmpty);
      });

      test('there are no matches', () {
        testSuggestor(
          expectedPatchCount: 0,
          input: '''
        library foo;
        var a = 'b';
        class Foo {}
      ''',
        );

        expect(converter.visitedNames, isEmpty);
      });

      test('the component is not Component2, but does add a FIXME comment', () {
        testSuggestor(
          expectedPatchCount: 1,
          input: r'''
        @Factory()
        UiFactory<FooProps> Foo =
            // ignore: undefined_identifier
            $Foo;

        @Props()
        class _$FooProps extends UiProps {
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
      ''',
          expectedOutput: isValidFilePath
              ? r'''
        @Factory()
        UiFactory<FooProps> Foo =
            // ignore: undefined_identifier
            $Foo;

        // FIXME: `FooProps` could not be auto-migrated to the new over_react boilerplate because `FooComponent` does not extend from `UiComponent2`.
        // For instructions on how to proceed, see: https://github.com/Workiva/over_react_codemod/tree/master/docs/boilerplate_upgrade.md#non-component2
        @Props()
        class _$FooProps extends UiProps {
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
      '''
              : '''
        @Factory()
        UiFactory<FooProps> Foo =
            // ignore: undefined_identifier
            \$Foo;

        ${semverReportUnavailableComment('FooProps')}
        @Props()
        class _\$FooProps extends UiProps {
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
      ''',
        );

        expect(converter.visitedNames, {
          'FooProps': null,
        });
      });

      test('the class is a PropsMixin', () {
        testSuggestor(
          expectedPatchCount: isValidFilePath ? 0 : 1,
          input: r'''
        @Factory()
        UiFactory<FooProps> Foo =
            // ignore: undefined_identifier
            $Foo;
        
        @PropsMixin()
        class FooPropsMixin {
          String foo;
          int bar;
        }

        @Props()
        class _$FooProps extends UiProps with FooPropsMixin {
          String foo;
          int bar;
        }

        @Component2()
        class FooComponent extends UiComponent2<FooProps, FooState> {
          @override
          render() {
            return Dom.ul()(
              Dom.li()('Foo: ', props.foo),
              Dom.li()('Bar: ', props.bar),
            );
          }
        }
      ''',
          expectedOutput: isValidFilePath
              ? r'''
        @Factory()
        UiFactory<FooProps> Foo =
            // ignore: undefined_identifier
            $Foo;
        

        @PropsMixin()
        class FooPropsMixin {
          String foo;
          int bar;
        }

        @Props()
        class _$FooProps extends UiProps with FooPropsMixin {
          String foo;
          int bar;
        }

        @Component2()
        class FooComponent extends UiComponent2<FooProps, FooState> {
          @override
          render() {
            return Dom.ul()(
              Dom.li()('Foo: ', props.foo),
              Dom.li()('Bar: ', props.bar),
            );
          }
        }
      '''
              : '''
        @Factory()
        UiFactory<FooProps> Foo =
            // ignore: undefined_identifier
            \$Foo;
        
        @PropsMixin()
        class FooPropsMixin {
          String foo;
          int bar;
        }

        ${semverReportUnavailableComment('FooProps')}
        @Props()
        class _\$FooProps extends UiProps with FooPropsMixin {
          String foo;
          int bar;
        }

        @Component2()
        class FooComponent extends UiComponent2<FooProps, FooState> {
          @override
          render() {
            return Dom.ul()(
              Dom.li()('Foo: ', props.foo),
              Dom.li()('Bar: ', props.bar),
            );
          }
        }
      ''',
        );

        expect(converter.visitedNames, {
          'FooPropsMixin': null,
          'FooProps': null,
        });
      });

      test('the class is publicly exported, but does add a FIXME comment', () {
        testSuggestor(
          expectedPatchCount: shouldTreatAllComponentsAsPrivate ? 3 : 1,
          input: r'''
          @Factory()
          UiFactory<BarProps> Bar =
              // ignore: undefined_identifier
              $Bar;
  
          @Props()
          class _$BarProps extends UiProps {
            String foo;
            int bar;
          }
  
          @Component2()
          class BarComponent extends UiComponent2<BarProps> {
            @override
            render() {
              return Dom.ul()(
                Dom.li()('Foo: ', props.foo),
                Dom.li()('Bar: ', props.bar),
              );
            }
          }
      ''',
          expectedOutput: shouldTreatAllComponentsAsPrivate
              ? r'''
          @Factory()
          UiFactory<BarProps> Bar =
              // ignore: undefined_identifier
              $Bar;

          @Props()
          mixin BarProps on UiProps {
            String foo;
            int bar;
          }
    
          @Component2()
          class BarComponent extends UiComponent2<BarProps> {
            @override
            render() {
              return Dom.ul()(
                Dom.li()('Foo: ', props.foo),
                Dom.li()('Bar: ', props.bar),
              );
            }
          }
        '''
              : '''
          @Factory()
          UiFactory<BarProps> Bar =
              // ignore: undefined_identifier
              \$Bar;
          ${isValidFilePath ? '''// FIXME: `BarProps` could not be auto-migrated to the new over_react boilerplate because it is exported from the following libraries in this repo:
          // lib/web_skin_dart.dart/BarProps
          // lib/another_file.dart/BarProps
          // Upgrading it would be considered a breaking change since consumer components can no longer extend from it.
          // For instructions on how to proceed, see: https://github.com/Workiva/over_react_codemod/tree/master/docs/boilerplate_upgrade.md#public-api''' : semverReportUnavailableComment('BarProps')}
          @Props()
          class _\$BarProps extends UiProps {
            String foo;
            int bar;
          }
  
          @Component2()
          class BarComponent extends UiComponent2<BarProps> {
            @override
            render() {
              return Dom.ul()(
                Dom.li()('Foo: ', props.foo),
                Dom.li()('Bar: ', props.bar),
              );
            }
          }
      ''',
        );

        expect(converter.visitedNames, {
          'BarProps': shouldTreatAllComponentsAsPrivate ? 'BarProps' : null,
        });
      });

      group('the classes are not simple', () {
        test('and there are both a props and a state class', () {
          testSuggestor(
            expectedPatchCount: isValidFilePath ? 0 : 2,
            input: r'''
        @Factory()
        UiFactory<FooProps> Foo =
            // ignore: undefined_identifier
            $Foo;

        @Props()
        class _$FooProps extends ADifferentPropsClass {
          String foo;
          int bar;
        }

        @State()
        class _$FooState extends ADifferentStateClass {
          String foo;
          int bar;
        }

        @Component2()
        class FooComponent extends UiStatefulComponent2<FooProps, FooState> {
          @override
          render() {
            return Dom.ul()(
              Dom.li()('Foo: ', props.foo),
              Dom.li()('Bar: ', props.bar),
            );
          }
        }
      ''',
            expectedOutput: isValidFilePath
                ? r'''
        @Factory()
        UiFactory<FooProps> Foo =
            // ignore: undefined_identifier
            $Foo;

        @Props()
        class _$FooProps extends ADifferentPropsClass {
          String foo;
          int bar;
        }

        @State()
        class _$FooState extends ADifferentStateClass {
          String foo;
          int bar;
        }

        @Component2()
        class FooComponent extends UiStatefulComponent2<FooProps, FooState> {
          @override
          render() {
            return Dom.ul()(
              Dom.li()('Foo: ', props.foo),
              Dom.li()('Bar: ', props.bar),
            );
          }
        }
      '''
                : '''
        @Factory()
        UiFactory<FooProps> Foo =
            // ignore: undefined_identifier
            \$Foo;

        ${semverReportUnavailableComment('FooProps')}
        @Props()
        class _\$FooProps extends ADifferentPropsClass {
          String foo;
          int bar;
        }

        ${semverReportUnavailableComment('FooState')}
        @State()
        class _\$FooState extends ADifferentStateClass {
          String foo;
          int bar;
        }

        @Component2()
        class FooComponent extends UiStatefulComponent2<FooProps, FooState> {
          @override
          render() {
            return Dom.ul()(
              Dom.li()('Foo: ', props.foo),
              Dom.li()('Bar: ', props.bar),
            );
          }
        }
      ''',
          );

          expect(converter.visitedNames, {
            'FooProps': null,
            'FooState': null,
          });
        });

        test('and there is just a props class', () {
          testSuggestor(
            expectedPatchCount: isValidFilePath ? 0 : 1,
            input: r'''
        @Factory()
        UiFactory<FooProps> Foo =
            // ignore: undefined_identifier
            $Foo;

        @Props()
        class _$FooProps extends ADifferentPropsClass {
          String foo;
          int bar;
        }

        @Component2()
        class FooComponent extends UiComponent2<FooProps, FooState> {
          @override
          render() {
            return Dom.ul()(
              Dom.li()('Foo: ', props.foo),
              Dom.li()('Bar: ', props.bar),
            );
          }
        }
      ''',
            expectedOutput: isValidFilePath
                ? r'''
        @Factory()
        UiFactory<FooProps> Foo =
            // ignore: undefined_identifier
            $Foo;

        @Props()
        class _$FooProps extends ADifferentPropsClass {
          String foo;
          int bar;
        }

        @Component2()
        class FooComponent extends UiComponent2<FooProps, FooState> {
          @override
          render() {
            return Dom.ul()(
              Dom.li()('Foo: ', props.foo),
              Dom.li()('Bar: ', props.bar),
            );
          }
        }
      '''
                : '''
        @Factory()
        UiFactory<FooProps> Foo =
            // ignore: undefined_identifier
            \$Foo;

        ${semverReportUnavailableComment('FooProps')}
        @Props()
        class _\$FooProps extends ADifferentPropsClass {
          String foo;
          int bar;
        }

        @Component2()
        class FooComponent extends UiComponent2<FooProps, FooState> {
          @override
          render() {
            return Dom.ul()(
              Dom.li()('Foo: ', props.foo),
              Dom.li()('Bar: ', props.bar),
            );
          }
        }
      ''',
          );

          expect(converter.visitedNames, {
            'FooProps': null,
          });
        });
      });
    });

    group('migrates when the classes are simple', () {
      test('and there are both a props and a state class', () {
        testSuggestor(
          expectedPatchCount: isValidFilePath ? 6 : 2,
          input: r'''
          @Factory()
          UiFactory<FooProps> Foo =
              // ignore: undefined_identifier
              $Foo;
    
          @Props()
          class _$FooProps extends UiProps {
            String foo;
            int bar;
          }
    
          @State()
          class _$FooState extends UiState {
            String foo;
            int bar;
          }
    
          @Component2()
          class FooComponent extends UiStatefulComponent2<FooProps, FooState> {
            @override
            render() {
              return Dom.ul()(
                Dom.li()('Foo: ', props.foo),
                Dom.li()('Bar: ', props.bar),
              );
            }
          }
        ''',
          expectedOutput: isValidFilePath
              ? r'''
          @Factory()
          UiFactory<FooProps> Foo =
              // ignore: undefined_identifier
              $Foo;
    
          @Props()
          mixin FooProps on UiProps {
            String foo;
            int bar;
          }
    
          @State()
          mixin FooState on UiState {
            String foo;
            int bar;
          }
    
          @Component2()
          class FooComponent extends UiStatefulComponent2<FooProps, FooState> {
            @override
            render() {
              return Dom.ul()(
                Dom.li()('Foo: ', props.foo),
                Dom.li()('Bar: ', props.bar),
              );
            }
          }
        '''
              : '''
          @Factory()
          UiFactory<FooProps> Foo =
              // ignore: undefined_identifier
              \$Foo;
    
          ${semverReportUnavailableComment('FooProps')}
          @Props()
          class _\$FooProps extends UiProps {
            String foo;
            int bar;
          }
    
          ${semverReportUnavailableComment('FooState')}
          @State()
          class _\$FooState extends UiState {
            String foo;
            int bar;
          }
    
          @Component2()
          class FooComponent extends UiStatefulComponent2<FooProps, FooState> {
            @override
            render() {
              return Dom.ul()(
                Dom.li()('Foo: ', props.foo),
                Dom.li()('Bar: ', props.bar),
              );
            }
          }
        ''',
        );

        expect(converter.visitedNames, {
          'FooProps': isValidFilePath ? 'FooProps' : null,
          'FooState': isValidFilePath ? 'FooState' : null,
        });
      });

      test('and there is only a props class', () {
        testSuggestor(
          expectedPatchCount: isValidFilePath ? 3 : 1,
          input: r'''
          @Factory()
          UiFactory<FooProps> Foo =
              // ignore: undefined_identifier
              $Foo;
    
          @Props()
          class _$FooProps extends UiProps {
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
        ''',
          expectedOutput: isValidFilePath
              ? r'''
          @Factory()
          UiFactory<FooProps> Foo =
              // ignore: undefined_identifier
              $Foo;
    
          @Props()
          mixin FooProps on UiProps {
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
        '''
              : '''
          @Factory()
          UiFactory<FooProps> Foo =
              // ignore: undefined_identifier
              \$Foo;
    
          ${semverReportUnavailableComment('FooProps')}
          @Props()
          class _\$FooProps extends UiProps {
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
        ''',
        );

        expect(converter.visitedNames, {
          'FooProps': isValidFilePath ? 'FooProps' : null,
        });
      });

      test('and are abstract', () {
        testSuggestor(
          expectedPatchCount: isValidFilePath ? 8 : 2,
          input: r'''
          @Factory()
          UiFactory<FooProps> Foo =
              // ignore: undefined_identifier
              $Foo;
    
          @AbstractProps()
          abstract class _$FooProps extends UiProps {
            String foo;
            int bar;
          }
    
          @AbstractState()
          abstract class _$FooState extends UiState {
            String foo;
            int bar;
          }
    
          @AbstractComponent2()
          abstract class FooComponent extends UiStatefulComponent2<FooProps, FooState> {
            @override
            render() {
              return Dom.ul()(
                Dom.li()('Foo: ', props.foo),
                Dom.li()('Bar: ', props.bar),
              );
            }
          }
        ''',
          expectedOutput: isValidFilePath
              ? r'''
          @Factory()
          UiFactory<FooProps> Foo =
              // ignore: undefined_identifier
              $Foo;
    
          @AbstractProps()
          mixin FooProps on UiProps {
            String foo;
            int bar;
          }
    
          @AbstractState()
          mixin FooState on UiState {
            String foo;
            int bar;
          }
    
          @AbstractComponent2()
          abstract class FooComponent extends UiStatefulComponent2<FooProps, FooState> {
            @override
            render() {
              return Dom.ul()(
                Dom.li()('Foo: ', props.foo),
                Dom.li()('Bar: ', props.bar),
              );
            }
          }
          '''
              : '''
          @Factory()
          UiFactory<FooProps> Foo =
              // ignore: undefined_identifier
              \$Foo;
    
          ${semverReportUnavailableComment('FooProps')}
          @AbstractProps()
          abstract class _\$FooProps extends UiProps {
            String foo;
            int bar;
          }
    
          ${semverReportUnavailableComment('FooState')}
          @AbstractState()
          abstract class _\$FooState extends UiState {
            String foo;
            int bar;
          }
    
          @AbstractComponent2()
          abstract class FooComponent extends UiStatefulComponent2<FooProps, FooState> {
            @override
            render() {
              return Dom.ul()(
                Dom.li()('Foo: ', props.foo),
                Dom.li()('Bar: ', props.bar),
              );
            }
          }
        ''',
        );

        expect(converter.visitedNames, {
          'FooProps': isValidFilePath ? 'FooProps' : null,
          'FooState': isValidFilePath ? 'FooState' : null,
        });
      });
    });
  });
}

String semverReportUnavailableComment(String nodeName) {
  return '''
    // FIXME: A Workiva Semver report was not found. `$nodeName` is assumed to be exported from a library in this repo and thus was not auto-migrated to the new over_react boilerplate.
    //
    // --------- If you are migrating an OSS library outside of Workiva ---------
    // You do not have access to Workiva's internal Semver audit tool. 
    // To complete the migration, you should:
    //
    //   1. Revert all changes to remove this FIX-ME comment
    //   2. Re-run the migration script with the following flag:    
    //
    //        pub global run over_react_codemod:boilerplate_upgrade --treat-all-components-as-private
    //
    //   NOTE: The changes made to props / state classes by the codemod constitute breaking changes
    //   if you publicly export them from your library. We strongly recommend that you release 
    //   the subsequent changes in a major version.
    //
    // --------- If you are migrating a Workiva library ---------
    // To complete the migration, you should:
    //   1. Revert all changes to remove this FIX-ME comment
    //   2. Generate a semver report by running the following script:
    //
    //        pub global activate semver_audit --hosted-url=https://pub.workiva.org
    //        pub global run semver_audit generate 2> semver_report.json
    //
    //   3. Re-run the migration script:
    //
    //        pub global run over_react_codemod:boilerplate_upgrade''';
}

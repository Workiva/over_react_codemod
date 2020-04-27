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

import 'package:over_react_codemod/src/boilerplate_suggestors/advanced_props_and_state_class_migrator.dart';
import 'package:over_react_codemod/src/boilerplate_suggestors/boilerplate_utilities.dart';
import 'package:test/test.dart';

import '../util.dart';

void main() {
  group('AdvancedPropsAndStateClassMigrator', () {
    advancedPropsAndStateClassMigratorTestHelper();

    group('with --treat-all-components-as-private flag', () {
      advancedPropsAndStateClassMigratorTestHelper(
        shouldTreatAllComponentsAsPrivate: true,
      );
    });
  });
}

void advancedPropsAndStateClassMigratorTestHelper({
  bool shouldTreatAllComponentsAsPrivate = false,
}) {
  const publicPropsClassName = 'FooProps';
  const propsClassName = '_\$$publicPropsClassName';
  const publicStateClassName = 'FooState';
  const stateClassName = '_\$$publicStateClassName';
  const factoryDecl = '''
      @Factory()
      UiFactory<$publicPropsClassName> Foo =
          // ignore: undefined_identifier
          \$Foo;
      ''';
  const componentDecl = '''
      @Component2()
      class FooComponent extends UiComponent2<$publicPropsClassName> {}
      ''';

  const statefulComponentDecl = '''
      @Component2()
      class FooComponent extends UiStatefulComponent2<$publicPropsClassName, $publicStateClassName> {}
      ''';

  String consumedPropsOverride(Iterable<String> mixinNames,
          {String fixmeComment = ''}) =>
      '''
      $fixmeComment
      @override
      get consumedProps => ${mixinNames.isEmpty ? '[]' : 'propsMeta.forMixins({${mixinNames.join(',')}})'};
      ''';

  String componentDeclWithConsumedProps(Iterable<String> mixinNames,
          {String fixmeComment = ''}) =>
      '''
      @Component2()
      class FooComponent extends UiComponent2<$publicPropsClassName> {
        ${consumedPropsOverride(mixinNames, fixmeComment: fixmeComment)}
      }
      ''';

  String statefulComponentDeclWithConsumedProps(Iterable<String> mixinNames,
          {String fixmeComment = ''}) =>
      '''
      @Component2()
      class FooComponent extends UiStatefulComponent2<$publicPropsClassName, $publicStateClassName> {
        ${consumedPropsOverride(mixinNames, fixmeComment: fixmeComment)}
      }
      ''';

  group('', () {
    var runCount = 0;
    final converter = ClassToMixinConverter();
    SuggestorTester testSuggestor({
      bool convertClassesWithExternalSuperclass = false,
      Map<String, String> visitedClassNames = const {},
      bool isValidSemverReportFilePath = true,
      String sourceFileUrl = defaultSuggestorTesterInputUrl,
    }) {
      runCount++;
      final semverHelper = getSemverHelper(
          isValidSemverReportFilePath
              ? 'test/boilerplate_suggestors/semver_report.json'
              : 'test/boilerplate_suggestors/does_not_exist.json',
          shouldTreatAllComponentsAsPrivate: shouldTreatAllComponentsAsPrivate);
      final tester = getSuggestorTester(
          AdvancedPropsAndStateClassMigrator(
            converter,
            semverHelper,
            treatUnvisitedClassesAsExternal: runCount > 1,
            convertClassesWithExternalSuperclass:
                convertClassesWithExternalSuperclass,
          ),
          inputUrl: sourceFileUrl);

      // If visitedClassNames is set, append the value of `converter.visitedClassNames`.
      // This is done to ensure that those custom classNames are not treated as members of an external library API.
      if (visitedClassNames.isNotEmpty) {
        converter
            .setVisitedNames({...converter.visitedNames, ...visitedClassNames});
      }

      return tester;
    }

    tearDown(() {
      runCount = 0;
      converter.setVisitedNames({});
    });

    group('does not perform a migration when', () {
      test('it\'s an empty file', () {
        testSuggestor()(expectedPatchCount: 0, input: '');

        expect(converter.visitedNames, isEmpty);
      });

      test('the class is simple', () {
        testSuggestor()(
          expectedPatchCount: 0,
          input: '''
          $factoryDecl
  
          @Props()
          class $propsClassName extends UiProps {
            String foo;
            int bar;
          }
  
          $componentDecl
        ''',
        );

        expect(converter.wasMigrated(publicPropsClassName), isFalse);
      });

      test('the class is not Component2, but does add a FIXME comment', () {
        testSuggestor()(
          expectedPatchCount: 1,
          input: '''
          $factoryDecl
  
          /// Some documentation comment 
          /// might get in the way of fix me comment removal
          @Props()
          class $propsClassName extends UiProps with SomePropsMixin {
            String foo;
            int bar;
          }
  
          @Component()
          class FooComponent extends UiComponent<$publicPropsClassName> {
            @override
            render() {
              return Dom.ul()(
                Dom.li()('Foo: ', props.foo),
                Dom.li()('Bar: ', props.bar),
              );
            }
          }
      ''',
          expectedOutput: '''
          $factoryDecl
  
          /// Some documentation comment 
          /// might get in the way of fix me comment removal
          @Props()
          // FIXME: `$publicPropsClassName` could not be auto-migrated to the new over_react boilerplate because `FooComponent` does not extend from `UiComponent2`.
          // 
          // Once you have upgraded the component, you can remove this FIX-ME comment and 
          // re-run the boilerplate migration script:
          // pub global run over_react_codemod:boilerplate_upgrade
          class $propsClassName extends UiProps with SomePropsMixin {
            String foo;
            int bar;
          }
  
          @Component()
          class FooComponent extends UiComponent<$publicPropsClassName> {
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

        expect(converter.wasMigrated(publicPropsClassName), isFalse);
      });

      test('the class is publicly exported, but does add a FIXME comment', () {
        testSuggestor()(
          expectedPatchCount: shouldTreatAllComponentsAsPrivate ? 0 : 2,
          input: r'''
          @Factory()
          UiFactory<BarProps> Bar =
              // ignore: undefined_identifier
              $Bar;
  
          @Props()
          class _$BarProps extends ADifferentPropsClass {
            String foo;
            int bar;
          }
  
          @State()
          class _$BarState extends ADifferentStateClass {
            String foo;
            int bar;
          }
  
          @Component2()
          class BarComponent extends UiStatefulComponent2<BarProps, BarState> {
            @override
            render() {
              return Dom.ul()(
                Dom.li()('Foo: ', props.foo),
                Dom.li()('Bar: ', props.bar),
              );
            }
          }
        ''',
          expectedOutput: '''
          @Factory()
          UiFactory<BarProps> Bar =
              // ignore: undefined_identifier
              \$Bar;
  
          @Props()
          ${shouldTreatAllComponentsAsPrivate ? '' : '''// FIXME: `BarProps` could not be auto-migrated to the new over_react boilerplate because it is exported from the following libraries in this repo:
          // lib/web_skin_dart.dart/BarProps
          // lib/another_file.dart/BarProps
          //
          // Upgrading it would be considered a breaking change since consumer components can no longer extend from it.
          //
          // To complete the migration, you can: 
          //   1. Deprecate `BarProps`.
          //   2. Make a copy of it, renaming it something like `BarPropsV2`.
          //   3. Replace all your current usage of the deprecated `BarProps` with `BarPropsV2`.
          //   4. Add a `hide BarPropsV2` clause to all places where it is exported, and then run:
          //        pub global run over_react_codemod:boilerplate_upgrade
          //   5a. If `BarProps` had consumers outside this repo, and it was intentionally made public,
          //       remove the `hide` clause you added in step 4 so that the new mixin created from `BarPropsV2` 
          //       will be a viable replacement for `BarProps`.
          //   5b. If `BarProps` had no consumers outside this repo, and you have no reason to make the new
          //       "V2" class / mixin public, update the `hide` clause you added in step 4 to include both the 
          //       concrete class and the newly created mixin.
          //   6. Remove this FIX-ME comment.
          //
          // If are migrating a Workiva library and have questions, or want to discuss alternative solutions, 
          // please reach out in the #support-ui-platform Slack room.'''}
          class _\$BarProps extends ADifferentPropsClass {
            String foo;
            int bar;
          }

          @State()
          ${shouldTreatAllComponentsAsPrivate ? '' : '''// FIXME: `BarState` could not be auto-migrated to the new over_react boilerplate because it is exported from the following library in this repo:
          // lib/web_skin_dart.dart/BarState
          //
          // Upgrading it would be considered a breaking change since consumer components can no longer extend from it.
          //
          // To complete the migration, you can: 
          //   1. Deprecate `BarState`.
          //   2. Make a copy of it, renaming it something like `BarStateV2`.
          //   3. Replace all your current usage of the deprecated `BarState` with `BarStateV2`.
          //   4. Add a `hide BarStateV2` clause to all places where it is exported, and then run:
          //        pub global run over_react_codemod:boilerplate_upgrade
          //   5a. If `BarState` had consumers outside this repo, and it was intentionally made public,
          //       remove the `hide` clause you added in step 4 so that the new mixin created from `BarStateV2` 
          //       will be a viable replacement for `BarState`.
          //   5b. If `BarState` had no consumers outside this repo, and you have no reason to make the new
          //       "V2" class / mixin public, update the `hide` clause you added in step 4 to include both the 
          //       concrete class and the newly created mixin.
          //   6. Remove this FIX-ME comment.
          //
          // If are migrating a Workiva library and have questions, or want to discuss alternative solutions, 
          // please reach out in the #support-ui-platform Slack room.'''}
          class _\$BarState extends ADifferentStateClass {
            String foo;
            int bar;
          }
  
          @Component2()
          class BarComponent extends UiStatefulComponent2<BarProps, BarState> {
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

        expect(converter.wasMigrated('BarProps'), isFalse);
        expect(converter.wasMigrated('BarState'), isFalse);
      });

      group('the semver report does not exist, but does add a FIXME comment',
          () {
        test('', () {
          testSuggestor(isValidSemverReportFilePath: false)(
            expectedPatchCount: shouldTreatAllComponentsAsPrivate ? 0 : 2,
            input: '''
            $factoryDecl
    
            @Props()
            class $propsClassName extends ADifferentPropsClass {
              String foo;
              int bar;
            }
    
            @State()
            class $stateClassName extends ADifferentStateClass {
              String foo;
              int bar;
            }
    
            $componentDecl
          ''',
            expectedOutput: '''
            $factoryDecl
    
            @Props()
            ${shouldTreatAllComponentsAsPrivate ? '' : '''// FIXME: A Workiva Semver report was not found. `$publicPropsClassName` is assumed to be exported from a library in this repo and thus was not auto-migrated to the new over_react boilerplate.
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
            //        pub global run over_react_codemod:boilerplate_upgrade'''}
            class $propsClassName extends ADifferentPropsClass {
              String foo;
              int bar;
            }
    
            @State()
            ${shouldTreatAllComponentsAsPrivate ? '' : '''// FIXME: A Workiva Semver report was not found. `$publicStateClassName` is assumed to be exported from a library in this repo and thus was not auto-migrated to the new over_react boilerplate.
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
            //        pub global run over_react_codemod:boilerplate_upgrade'''}
            class $stateClassName extends ADifferentStateClass {
              String foo;
              int bar;
            }
    
            $componentDecl
          ''',
          );

          expect(converter.wasMigrated(publicPropsClassName), isFalse);
          expect(converter.wasMigrated(publicStateClassName), isFalse);
        });

        test('unless the declaration is in a file outside of lib/', () {
          testSuggestor(
            isValidSemverReportFilePath: false,
            sourceFileUrl: 'web/src/input.dart',
            visitedClassNames: {
              'ADifferentPropsClass': 'ADifferentPropsClassMixin',
            },
          )(
            input: '''
            $factoryDecl

            @Props()
            class $propsClassName extends ADifferentPropsClass {
              String foo;
              int bar;
            }

            $componentDecl
          ''',
            expectedOutput: '''
            $factoryDecl

            @Props()
            mixin ${publicPropsClassName}Mixin on UiProps {
              String foo;
              int bar;
            }

            @Props()
            // FIXME:
            //   1. Ensure that all mixins used by ADifferentPropsClass are also mixed into this class.
            //   2. Fix any analyzer warnings on this class about missing mixins.
            class $publicPropsClassName = UiProps with ADifferentPropsClassMixin, ${publicPropsClassName}Mixin;

            ${componentDeclWithConsumedProps(['${publicPropsClassName}Mixin'])}
          ''',
          );

          expect(converter.wasMigrated(publicPropsClassName), isTrue,
              reason:
                  'Declarations outside of lib/ should always be converted - even if no valid semver report is found.');
        });
      });

      group(
          'the class extends from a class not found within ClassToMixinConverter.visitedClassNames',
          () {
        const externalSuperclassName = 'SomeExternalPropsClass';

        const input = '''
            $factoryDecl
            
            @Props()
            class $propsClassName extends $externalSuperclassName {
              String foo;
              int bar;
            }
            
            $componentDecl
            ''';

        const expectedOutputWithExternalSuperclassReasonComment = '''
            $factoryDecl
            
            @Props()
            // FIXME: `$publicPropsClassName` could not be auto-migrated to the new over_react boilerplate because it extends from: $externalSuperclassName - which comes from an external library.
            //
            // To complete the migration, you should:
            //   1. Check on the boilerplate migration status of the library it comes from.
            //   2. Once the library has released a version that includes updated boilerplate,
            //      bump the lower bound of your dependency to that version in your `pubspec.yaml`, and run `pub get`.
            //   3. Re-run the migration script with the following flag:
            //      pub global run over_react_codemod:boilerplate_upgrade --convert-classes-with-external-superclasses
            //   4. Once the migration is complete, you should notice that $externalSuperclassName has been deprecated. 
            //      Follow the deprecation instructions to consume the replacement by either updating your usage to
            //      the new class name and/or updating to a different entrypoint that exports the version(s) of 
            //      $externalSuperclassName that is compatible with the new over_react boilerplate.
            class $propsClassName extends $externalSuperclassName {
              String foo;
              int bar;
            }
            
            $componentDecl
          ''';

        group('but does add a FIXME comment', () {
          setUp(() {
            // When it is run the first time, nothing should happen since
            // we don't know if the custom classes are external or not.
            testSuggestor()(expectedPatchCount: 0, input: input);
            testSuggestor()(
              expectedPatchCount: 1,
              input: input,
              expectedOutput: expectedOutputWithExternalSuperclassReasonComment,
            );
          });

          test('', () {
            expect(
                converter.visitedNames,
                {
                  publicPropsClassName: null,
                },
                reason:
                    '$publicPropsClassName should not be converted since $externalSuperclassName is external, '
                    'and the --convert-classes-with-external-superclasses flag is not set');
          });

          test(
              'which then gets removed from the declaration that is converted to a mixin, and replaced '
              'with updated instructions on the new concrete class declaration when the script '
              'is re-ran with the --convert-classes-with-external-superclasses flag set',
              () {
            // Run it a third time - this time simulating `--convert-classes-with-external-superclasses`
            // being set - which allows conversion of external superclasses
            testSuggestor(convertClassesWithExternalSuperclass: true)(
              input: expectedOutputWithExternalSuperclassReasonComment,
              expectedOutput: '''
              $factoryDecl
  
              @Props()
              mixin ${publicPropsClassName}Mixin on UiProps {
                String foo;
                int bar;
              }
  
              @Props()
              // FIXME:
              //   1. Ensure that all mixins used by $externalSuperclassName are also mixed into this class.
              //   2. Fix any analyzer warnings on this class about missing mixins.
              //   3. You should notice that $externalSuperclassName is deprecated.  
              //      Follow the deprecation instructions to consume the replacement by either updating your usage to
              //      the new class/mixin name and/or updating to a different entrypoint that exports the version of 
              //      $externalSuperclassName that is compatible with the new over_react boilerplate.
              //
              //      If it is not deprecated, something most likely went wrong during the migration of the 
              //      library that contains it. 
              class $publicPropsClassName = UiProps with $externalSuperclassName, ${publicPropsClassName}Mixin;
  
              ${componentDeclWithConsumedProps([
                '${publicPropsClassName}Mixin'
              ])}
            ''',
            );

            expect(
                converter.visitedNames,
                {
                  publicPropsClassName: '${publicPropsClassName}Mixin',
                },
                reason:
                    '$publicPropsClassName should be converted to a mixin since the '
                    '--convert-classes-with-external-superclasses flag is set');
          });
        });

        test(
            'unless the --convert-classes-with-external-superclasses flag is set',
            () {
          // When it is run the first time, nothing should happen since
          // we don't know if the custom classes are external or not.
          testSuggestor()(expectedPatchCount: 0, input: input);
          // Run it a second time - this time simulating `--convert-classes-with-external-superclasses`
          // being set - which allows conversion of external superclasses
          testSuggestor(convertClassesWithExternalSuperclass: true)(
            input: '''
            $factoryDecl

            @Props()
            class $propsClassName extends $externalSuperclassName {
              String foo;
              int bar;
            }

            $componentDecl
          ''',
            expectedOutput: '''
              $factoryDecl
  
              @Props()
              mixin ${publicPropsClassName}Mixin on UiProps {
                String foo;
                int bar;
              }
  
              @Props()
              // FIXME:
              //   1. Ensure that all mixins used by $externalSuperclassName are also mixed into this class.
              //   2. Fix any analyzer warnings on this class about missing mixins.
              //   3. You should notice that $externalSuperclassName is deprecated.  
              //      Follow the deprecation instructions to consume the replacement by either updating your usage to
              //      the new class/mixin name and/or updating to a different entrypoint that exports the version of 
              //      $externalSuperclassName that is compatible with the new over_react boilerplate.
              //
              //      If it is not deprecated, something most likely went wrong during the migration of the 
              //      library that contains it.
              class $publicPropsClassName = UiProps with $externalSuperclassName, ${publicPropsClassName}Mixin;
  
              ${componentDeclWithConsumedProps([
              '${publicPropsClassName}Mixin'
            ])}
            ''',
          );

          expect(
              converter.visitedNames,
              {
                publicPropsClassName: '${publicPropsClassName}Mixin',
              },
              reason:
                  '$publicPropsClassName should be converted to a mixin since the '
                  '--convert-classes-with-external-superclasses flag is set');
        });
      });

      group(
          'the class extends from a custom class that has been visited, '
          'but not yet converted to the new boilerplate after two runs '
          'but does add a FIXME comment', () {
        const expectedOutputWithUnMigratedSuperclassReasonComment = '''
            $factoryDecl
            
            @Props()
            // FIXME: `$publicPropsClassName` could not be auto-migrated to the new over_react boilerplate because it extends from `ADifferentPropsClass`, which was not able to be migrated.
            //
            // To complete the migration, you should:
            //   1. Look at the FIX-ME comment that has been added to `ADifferentPropsClass` - 
            //      and follow the steps outlined there to complete the migration.
            //   2. Re-run the migration script:
            //      pub global run over_react_codemod:boilerplate_upgrade
            class $propsClassName extends ADifferentPropsClass {
              String foo;
              int bar;
            }
    
            $componentDecl
            ''';

        test('', () {
          const input = '''
              $factoryDecl
      
              @Props()
              class $propsClassName extends ADifferentPropsClass {
                String foo;
                int bar;
              }
      
              $componentDecl
            ''';

          // When it is run the first time, nothing should happen since
          // we don't know if the custom classes are "migratable" or not.
          testSuggestor()(expectedPatchCount: 0, input: input);
          testSuggestor(
            visitedClassNames: {
              'ADifferentPropsClass': null,
            },
          )(
            input: input,
            expectedOutput: expectedOutputWithUnMigratedSuperclassReasonComment,
          );

          expect(converter.visitedNames, {
            'ADifferentPropsClass': null,
            publicPropsClassName: null,
          });
        });

        test(
            'which then gets removed and replaced with updated instructions '
            'when the script is re-ran after the consumer makes the class "migratable"',
            () {
          // When it is run the first time, nothing should happen since
          // we don't know if the custom classes are "migratable" or not.
          testSuggestor()(
              expectedPatchCount: 0,
              input: expectedOutputWithUnMigratedSuperclassReasonComment);
          testSuggestor(
            visitedClassNames: {
              'ADifferentPropsClass': 'ADifferentPropsClassMixin',
            },
          )(
            input: expectedOutputWithUnMigratedSuperclassReasonComment,
            expectedOutput: '''
            $factoryDecl
            
            @Props()
            mixin ${publicPropsClassName}Mixin on UiProps {
              String foo;
              int bar;
            }

            @Props()
            // FIXME:
            //   1. Ensure that all mixins used by ADifferentPropsClass are also mixed into this class.
            //   2. Fix any analyzer warnings on this class about missing mixins.
            class $publicPropsClassName = UiProps with ADifferentPropsClassMixin, ${publicPropsClassName}Mixin;
    
            ${componentDeclWithConsumedProps(['${publicPropsClassName}Mixin'])}
          ''',
          );

          expect(converter.visitedNames, {
            'ADifferentPropsClass': 'ADifferentPropsClassMixin',
            publicPropsClassName: '${publicPropsClassName}Mixin',
          });
        });
      });

      test(
          'the class uses one or more mixins not found within ClassToMixinConverter.visitedClassNames:',
          () {
        const externalMixinName = 'SomeExternalMixin';
        testSuggestor()(
          input: '''
          $factoryDecl

          @Props()
          class $propsClassName extends UiProps with $externalMixinName {
            String foo;
            int bar;
          }

          $componentDecl
          ''',
          expectedOutput: '''
          $factoryDecl
          
          @Props()
          mixin ${publicPropsClassName}Mixin on UiProps {
            String foo;
            int bar;
          }

          @Props()
          class $publicPropsClassName = UiProps with ${publicPropsClassName}Mixin, $externalMixinName;

          ${componentDeclWithConsumedProps(['${publicPropsClassName}Mixin'])}
        ''',
        );
      });
    });

    group('performs a migration when the class(es) are advanced', () {
      group(
          'and there are both a props and a state class that extend '
          'from custom classes that were converted to the new boilerplate', () {
        const input = '''
            $factoryDecl
    
            @Props()
            class $propsClassName extends ADifferentPropsClass {
              String foo;
              int bar;
            }
    
            @State()
            class $stateClassName extends ADifferentStateClass {
              String foo;
              int bar;
            }
    
            $statefulComponentDecl
          ''';

        final expectedOutput = '''
            $factoryDecl
    
            @Props()
            mixin ${publicPropsClassName}Mixin on UiProps {
              String foo;
              int bar;
            }

            @Props()
            // FIXME:
            //   1. Ensure that all mixins used by ADifferentPropsClass are also mixed into this class.
            //   2. Fix any analyzer warnings on this class about missing mixins.
            class $publicPropsClassName = UiProps with ADifferentPropsClassMixin, ${publicPropsClassName}Mixin;
    
            @State()
            mixin ${publicStateClassName}Mixin on UiState {
              String foo;
              int bar;
            }

            @State()
            // FIXME:
            //   1. Ensure that all mixins used by ADifferentStateClass are also mixed into this class.
            //   2. Fix any analyzer warnings on this class about missing mixins.
            class $publicStateClassName = UiState with ADifferentStateClassMixin, ${publicStateClassName}Mixin;
    
            ${statefulComponentDeclWithConsumedProps([
          '${publicPropsClassName}Mixin'
        ])}
          ''';

        test('on the first run', () {
          // Simulates the case where the superclasses were visited first and successfully converted
          testSuggestor(
            visitedClassNames: {
              'ADifferentPropsClass': 'ADifferentPropsClassMixin',
              'ADifferentStateClass': 'ADifferentStateClassMixin',
            },
          )(
            input: input,
            expectedOutput: expectedOutput,
          );

          expect(converter.visitedNames, {
            'ADifferentPropsClass': 'ADifferentPropsClassMixin',
            'ADifferentStateClass': 'ADifferentStateClassMixin',
            publicPropsClassName: '${publicPropsClassName}Mixin',
            publicStateClassName: '${publicStateClassName}Mixin',
          });
        });

        test('on the second run', () {
          // When it is run the first time, nothing should happen since
          // we don't know if the custom classes are external or not.
          testSuggestor(
            visitedClassNames: {
              'ADifferentPropsClass': null,
              'ADifferentStateClass': null,
            },
          )(expectedPatchCount: 0, input: input);
          testSuggestor(
            visitedClassNames: {
              'ADifferentPropsClass': 'ADifferentPropsClassMixin',
              'ADifferentStateClass': 'ADifferentStateClassMixin',
            },
          )(
            input: input,
            expectedOutput: expectedOutput,
          );

          expect(converter.visitedNames, {
            'ADifferentPropsClass': 'ADifferentPropsClassMixin',
            'ADifferentStateClass': 'ADifferentStateClassMixin',
            publicPropsClassName: '${publicPropsClassName}Mixin',
            publicStateClassName: '${publicStateClassName}Mixin',
          });
        });
      });

      group(
          'and there are both a props and state class that use mixins that were converted to the new boilerplate',
          () {
        const input = '''
            $factoryDecl
    
            @Props()
            class $propsClassName extends UiProps with AMixin, AnotherMixin {
              String foo;
              int bar;
            }
    
            @State()
            class $stateClassName extends UiState with AStateMixin, AnotherStateMixin {
              String foo;
              int bar;
            }
    
            $statefulComponentDecl
            ''';

        final expectedOutput = '''
            $factoryDecl
    
            @Props()
            mixin ${publicPropsClassName}Mixin on UiProps {
              String foo;
              int bar;
            }

            @Props()
            class $publicPropsClassName = UiProps with ${publicPropsClassName}Mixin, AMixin, AnotherMixin;

            @State()
            mixin ${publicStateClassName}Mixin on UiState {
              String foo;
              int bar;
            }
    
            @State()
            class $publicStateClassName = UiState with ${publicStateClassName}Mixin, AStateMixin, AnotherStateMixin;
    
            ${statefulComponentDeclWithConsumedProps([
          '${publicPropsClassName}Mixin'
        ])}
          ''';

        test('', () {
          // Simulates the case where the superclasses were visited first and successfully converted
          testSuggestor()(
            input: input,
            expectedOutput: expectedOutput,
          );

          expect(converter.visitedNames, {
            publicPropsClassName: '${publicPropsClassName}Mixin',
            publicStateClassName: '${publicStateClassName}Mixin',
          });
        });
      });

      group('and there is just a props class', () {
        group('that extends from the reserved FluxUiProps class', () {
          test('and uses no mixins', () {
            const input = '''
                $factoryDecl
      
                @Props()
                class $propsClassName extends FluxUiProps<SomeActions, SomeStore> {
                  String foo;
                  int bar;
                }
      
                @Component2()
                class FooComponent extends FluxUiComponent2<$publicPropsClassName> {
                  @override
                  render() {
                    return Dom.ul()(
                      Dom.li()('Foo: ', props.foo),
                      Dom.li()('Bar: ', props.bar),
                    );
                  }
                }
                ''';

            testSuggestor()(
              input: input,
              expectedOutput: '''
              $factoryDecl
  
              @Props()
              mixin ${publicPropsClassName}Mixin on UiProps {
                String foo;
                int bar;
              }
  
              @Props()
              class $publicPropsClassName = UiProps 
                  with FluxUiPropsMixin<SomeActions, SomeStore>, ${publicPropsClassName}Mixin;
  
              @Component2()
              class FooComponent extends FluxUiComponent2<$publicPropsClassName> {
                ${consumedPropsOverride(['${publicPropsClassName}Mixin'])}
                  
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
              publicPropsClassName: '${publicPropsClassName}Mixin',
            });
          });

          group('and uses a mixin', () {
            const input = '''
                $factoryDecl
      
                @Props()
                class $propsClassName extends FluxUiProps<SomeActions, SomeStore> with SomePropsMixin<SomeStore> {
                  String foo;
                  int bar;
                }
      
                @Component2()
                class FooComponent extends FluxUiComponent2<$publicPropsClassName> {
                  @override
                  render() {
                    return Dom.ul()(
                      Dom.li()('Foo: ', props.foo),
                      Dom.li()('Bar: ', props.bar),
                    );
                  }
                }
                ''';

            final expectedOutput = '''
                $factoryDecl
    
                @Props()
                mixin ${publicPropsClassName}Mixin on UiProps {
                  String foo;
                  int bar;
                }

                @Props()    
                class $publicPropsClassName = UiProps 
                    with 
                        FluxUiPropsMixin<SomeActions, SomeStore>, 
                        ${publicPropsClassName}Mixin, 
                        SomePropsMixin<SomeStore>;
    
                @Component2()
                class FooComponent extends FluxUiComponent2<$publicPropsClassName> {
                  ${consumedPropsOverride(['${publicPropsClassName}Mixin'])}
                
                  @override
                  render() {
                    return Dom.ul()(
                      Dom.li()('Foo: ', props.foo),
                      Dom.li()('Bar: ', props.bar),
                    );
                  }
                }
              ''';

            test('', () {
              testSuggestor()(
                input: input,
                expectedOutput: expectedOutput,
              );

              expect(converter.visitedNames, {
                publicPropsClassName: '${publicPropsClassName}Mixin',
              });
            });
          });

          group('and is abstract', () {
            test('with members of its own', () {
              const input = r'''
                  @AbstractProps()
                  abstract class _$AbstractFluxProps<A extends SomeActions, S extends SomeStore> 
                      extends FluxUiProps<A, S>
                      with SomePropsMixin<S> {
                    String foo;
                    int bar;
                  }
    
                  @AbstractComponent2()
                  abstract class AbstractFluxComponent<T extends AbstractFluxProps> extends FluxUiComponent2<T> {}
                ''';

              testSuggestor(visitedClassNames: {
                'SomePropsMixin': 'SomePropsMixin',
              })(
                input: input,
                expectedOutput: r'''
                @AbstractProps()
                mixin AbstractFluxPropsMixin<A extends SomeActions, S extends SomeStore> on UiProps {
                  String foo;
                  int bar;
                }

                @AbstractProps()
                abstract class AbstractFluxProps<A extends SomeActions, S extends SomeStore> 
                    implements FluxUiPropsMixin<A, S>, AbstractFluxPropsMixin<A, S>, SomePropsMixin<S> {}

                @AbstractComponent2()
                abstract class AbstractFluxComponent<T extends AbstractFluxProps> extends FluxUiComponent2<T> {}
              ''',
              );

              expect(converter.visitedNames, {
                'SomePropsMixin': 'SomePropsMixin',
                'AbstractFluxProps': 'AbstractFluxPropsMixin',
              });
            });

            test('with no members', () {
              const input = r'''
                  @AbstractProps()
                  abstract class _$AbstractFluxProps<A extends SomeActions, S extends SomeStore> 
                      extends FluxUiProps<A, S>
                      with SomePropsMixin<S> {}

                  @AbstractComponent2()
                  abstract class AbstractFluxComponent<T extends AbstractFluxProps> extends FluxUiComponent2<T> {}
                ''';

              testSuggestor(visitedClassNames: {
                'SomePropsMixin': 'SomePropsMixin',
              })(
                input: input,
                expectedOutput: r'''
                @AbstractProps()
                abstract class AbstractFluxProps<A extends SomeActions, S extends SomeStore>
                    implements FluxUiPropsMixin<A, S>, SomePropsMixin<S> {}

                @AbstractComponent2()
                abstract class AbstractFluxComponent<T extends AbstractFluxProps> extends FluxUiComponent2<T> {}
              ''',
              );

              expect(converter.visitedNames, {
                'SomePropsMixin': 'SomePropsMixin',
                'AbstractFluxProps': 'AbstractFluxProps',
              });
            });
          });
        });

        group('that extends from an arbitrary custom class', () {
          test('that is not abstract', () {
            testSuggestor(visitedClassNames: {
              'ADifferentPropsClass': 'ADifferentPropsClassMixin',
            })(
              input: '''
              $factoryDecl

              @Props()
              class $propsClassName extends ADifferentPropsClass {
                String foo;
                int bar;
              }

              $componentDecl
            ''',
              expectedOutput: '''
              $factoryDecl

              @Props()
              mixin ${publicPropsClassName}Mixin on UiProps {
                String foo;
                int bar;
              }

              @Props()
              // FIXME:
              //   1. Ensure that all mixins used by ADifferentPropsClass are also mixed into this class.
              //   2. Fix any analyzer warnings on this class about missing mixins.
              class $publicPropsClassName = UiProps with ADifferentPropsClassMixin, ${publicPropsClassName}Mixin;

              ${componentDeclWithConsumedProps([
                '${publicPropsClassName}Mixin'
              ])}
            ''',
            );

            expect(converter.visitedNames, {
              'ADifferentPropsClass': 'ADifferentPropsClassMixin',
              publicPropsClassName: '${publicPropsClassName}Mixin',
            });
          });

          group('that is abstract', () {
            test('with members of its own', () {
              const input = r'''
                  @AbstractProps()
                  abstract class _$AbstractBlockProps<A extends Something> extends SomeAbstractPropsClass<A>
                      with
                          LayoutPropsMixin,
                          // ignore: mixin_of_non_class, undefined_class
                          $LayoutPropsMixin,
                          BlockPropsMixin,
                          // ignore: mixin_of_non_class, undefined_class
                          $BlockPropsMixin
                      implements
                          BlockClassHelperMapView {
                    String foo;
                    int bar;
                  }
    
                  @AbstractComponent2()
                  abstract class AbstractBlockComponent<T extends AbstractBlockProps> extends UiComponent2<T>
                      with LayoutMixin<T>, BlockMixin<T> {}
                ''';

              // When it is run the first time, nothing should happen since
              // we don't know if the mixin(s) are external or not.
              testSuggestor()(expectedPatchCount: 0, input: input);
              testSuggestor(visitedClassNames: {
                'SomeAbstractPropsClass': 'SomeAbstractPropsClass',
                'LayoutPropsMixin': 'LayoutPropsMixin',
                'BlockPropsMixin': null,
              })(
                input: input,
                expectedOutput: r'''
                @AbstractProps()
                mixin AbstractBlockPropsMixin<A extends Something> on UiProps implements BlockClassHelperMapView {
                  String foo;
                  int bar;
                }

                @AbstractProps()
                abstract class AbstractBlockProps<A extends Something> implements
                        SomeAbstractPropsClass<A>,
                        AbstractBlockPropsMixin<A>,
                        LayoutPropsMixin,
                        BlockPropsMixin,
                        BlockClassHelperMapView {}

                @AbstractComponent2()
                abstract class AbstractBlockComponent<T extends AbstractBlockProps> extends UiComponent2<T>
                    with LayoutMixin<T>, BlockMixin<T> {}
              ''',
              );

              expect(converter.visitedNames, {
                'SomeAbstractPropsClass': 'SomeAbstractPropsClass',
                'LayoutPropsMixin': 'LayoutPropsMixin',
                'BlockPropsMixin': null,
                'AbstractBlockProps': 'AbstractBlockPropsMixin',
              });
            });

            test('with no members', () {
              const input = r'''
                  @AbstractProps()
                  abstract class _$AbstractBlockProps<A extends Something> extends SomeAbstractPropsClass<A>
                      with
                          LayoutPropsMixin,
                          // ignore: mixin_of_non_class, undefined_class
                          $LayoutPropsMixin,
                          BlockPropsMixin,
                          // ignore: mixin_of_non_class, undefined_class
                          $BlockPropsMixin
                      implements
                          BlockClassHelperMapView {}
    
                  @AbstractComponent2()
                  abstract class AbstractBlockComponent<T extends AbstractBlockProps> extends UiComponent2<T>
                      with LayoutMixin<T>, BlockMixin<T> {}
                ''';

              // When it is run the first time, nothing should happen since
              // we don't know if the mixin(s) are external or not.
              testSuggestor()(expectedPatchCount: 0, input: input);
              testSuggestor(visitedClassNames: {
                'SomeAbstractPropsClass': 'SomeAbstractPropsClass',
                'LayoutPropsMixin': 'LayoutPropsMixin',
                'BlockPropsMixin': null,
              })(
                input: input,
                expectedOutput: r'''
                @AbstractProps()
                abstract class AbstractBlockProps<A extends Something> implements
                        SomeAbstractPropsClass<A>,
                        LayoutPropsMixin,
                        BlockPropsMixin,
                        BlockClassHelperMapView {}

                @AbstractComponent2()
                abstract class AbstractBlockComponent<T extends AbstractBlockProps> extends UiComponent2<T>
                    with LayoutMixin<T>, BlockMixin<T> {}
              ''',
              );

              expect(converter.visitedNames, {
                'SomeAbstractPropsClass': 'SomeAbstractPropsClass',
                'LayoutPropsMixin': 'LayoutPropsMixin',
                'BlockPropsMixin': null,
                'AbstractBlockProps': 'AbstractBlockProps',
              });
            });
          });

          group('that is abstract based on annotation only (edge case)', () {
            test('with members of its own', () {
              const input = r'''
                  @PropsMixin()
                  abstract class BreadcrumbPathPropsMixin {}
                  
                  @AbstractProps()
                  class _$AbstractBreadcrumbPathProps extends AbstractGraphFormProps
                      with
                          BreadcrumbPathPropsMixin,
                          // ignore: mixin_of_non_class, undefined_class
                          $BreadcrumbPathPropsMixin {
                    String foo;
                    int bar;
                  }
                  
                  @AbstractComponent2()
                  class AbstractBreadcrumbPathComponent<T extends AbstractBreadcrumbPathProps> 
                      extends UiComponent2<T> {}
                ''';

              testSuggestor(visitedClassNames: {
                'BreadcrumbPathPropsMixin': 'BreadcrumbPathPropsMixin',
                'AbstractGraphFormProps': 'AbstractGraphFormProps',
              })(
                input: input,
                expectedOutput: r'''
                @PropsMixin()
                abstract class BreadcrumbPathPropsMixin {}
              
                @AbstractProps()
                mixin AbstractBreadcrumbPathPropsMixin on UiProps {
                  String foo;
                  int bar;
                }

                @AbstractProps()
                abstract class AbstractBreadcrumbPathProps 
                    implements
                        AbstractGraphFormProps,
                        AbstractBreadcrumbPathPropsMixin,
                        BreadcrumbPathPropsMixin {}

                @AbstractComponent2()
                class AbstractBreadcrumbPathComponent<T extends AbstractBreadcrumbPathProps> 
                    extends UiComponent2<T> {}
              ''',
              );

              expect(converter.visitedNames, {
                'BreadcrumbPathPropsMixin': 'BreadcrumbPathPropsMixin',
                'AbstractGraphFormProps': 'AbstractGraphFormProps',
                'AbstractBreadcrumbPathProps':
                    'AbstractBreadcrumbPathPropsMixin',
              });
            });

            test('with no members', () {
              const input = r'''
                  @PropsMixin()
                  abstract class BreadcrumbPathPropsMixin {}
                  
                  @AbstractProps()
                  class _$AbstractBreadcrumbPathProps extends AbstractGraphFormProps
                      with
                          BreadcrumbPathPropsMixin,
                          // ignore: mixin_of_non_class, undefined_class
                          $BreadcrumbPathPropsMixin {}
                  
                  @AbstractComponent2()
                  class AbstractBreadcrumbPathComponent<T extends AbstractBreadcrumbPathProps> 
                      extends UiComponent2<T> {}
                ''';

              testSuggestor(visitedClassNames: {
                'BreadcrumbPathPropsMixin': 'BreadcrumbPathPropsMixin',
                'AbstractGraphFormProps': 'AbstractGraphFormProps',
              })(
                input: input,
                expectedOutput: r'''
                @PropsMixin()
                abstract class BreadcrumbPathPropsMixin {}

                @AbstractProps()
                abstract class AbstractBreadcrumbPathProps 
                    implements 
                        AbstractGraphFormProps, 
                        BreadcrumbPathPropsMixin {}

                @AbstractComponent2()
                class AbstractBreadcrumbPathComponent<T extends AbstractBreadcrumbPathProps> 
                    extends UiComponent2<T> {}
              ''',
              );

              expect(converter.visitedNames, {
                'BreadcrumbPathPropsMixin': 'BreadcrumbPathPropsMixin',
                'AbstractGraphFormProps': 'AbstractGraphFormProps',
                'AbstractBreadcrumbPathProps': 'AbstractBreadcrumbPathProps',
              });
            });
          });

          group('that has an analagous abstract component class', () {
            test('and members of its own', () {
              testSuggestor(visitedClassNames: {
                'SomeAbstractPropsClass': 'SomeAbstractPropsClassMixin',
              })(
                input: '''
                $factoryDecl

                @Props()
                class $propsClassName extends SomeAbstractPropsClass implements SomeInterface {
                  String foo;
                  int bar;
                }

                @Component2()
                class FooComponent extends AbstractComponentClass<$publicPropsClassName> {
                  @override
                  render() {
                    return Dom.ul()(
                      Dom.li()('Foo: ', props.foo),
                      Dom.li()('Bar: ', props.bar),
                    );
                  }
                }
              ''',
                expectedOutput: '''
                $factoryDecl

                @Props()
                mixin ${publicPropsClassName}Mixin on UiProps implements SomeInterface {
                  String foo;
                  int bar;
                }

                @Props()
                // FIXME:
                //   1. Ensure that all mixins used by SomeAbstractPropsClass are also mixed into this class.
                //   2. Fix any analyzer warnings on this class about missing mixins.
                class $publicPropsClassName = UiProps 
                    with SomeAbstractPropsClassMixin, ${publicPropsClassName}Mixin
                    implements SomeAbstractPropsClass, SomeInterface;

                @Component2()
                class FooComponent extends AbstractComponentClass<$publicPropsClassName> {
                  ${consumedPropsOverride([
                  '${publicPropsClassName}Mixin'
                ], fixmeComment: '// FIXME Ensure that consumedProps shouldn\'t be inherited from AbstractComponentClass instead of overridden here.')}
                
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
                'SomeAbstractPropsClass': 'SomeAbstractPropsClassMixin',
                publicPropsClassName: '${publicPropsClassName}Mixin',
              });
            });

            test('but no members of its own', () {
              testSuggestor(visitedClassNames: {
                'SomeAbstractPropsClass': 'SomeAbstractPropsClass',
              })(
                input: '''
                $factoryDecl

                @Props()
                class $propsClassName extends SomeAbstractPropsClass implements SomeInterface {}

                @Component2()
                class FooComponent extends AbstractComponentClass<$publicPropsClassName> {
                  @override
                  render() {
                    return Dom.ul()(
                      Dom.li()('Foo: ', props.foo),
                      Dom.li()('Bar: ', props.bar),
                    );
                  }
                }
              ''',
                expectedOutput: '''
                $factoryDecl

                @Props()
                // FIXME:
                //   1. Ensure that all mixins used by SomeAbstractPropsClass are also mixed into this class.
                //   2. Fix any analyzer warnings on this class about missing mixins.
                class $publicPropsClassName extends UiProps implements SomeAbstractPropsClass, SomeInterface {}

                @Component2()
                class FooComponent extends AbstractComponentClass<$publicPropsClassName> {
                  ${consumedPropsOverride([], fixmeComment: '// FIXME Ensure that consumedProps shouldn\'t be inherited from AbstractComponentClass instead of overridden here.')}
                
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
                'SomeAbstractPropsClass': 'SomeAbstractPropsClass',
                publicPropsClassName: publicPropsClassName,
              });
            });
          });
        });

        test('that extends from UiProps, but uses mixins', () {
          const input = '''
              $factoryDecl
    
              @Props()
              class $propsClassName extends UiProps
                  with ConvertedMixin,
                       // ignore: mixin_of_non_class, undefined_class
                       \$ConvertedMixin,
                       UnconvertedMixin,
                       // ignore: mixin_of_non_class, undefined_class
                       \$UnconvertedMixin {
                String foo;
                int bar;
              }
    
              $componentDecl
            ''';

          testSuggestor()(
            input: input,
            expectedOutput: '''
            $factoryDecl

            @Props()
            mixin ${publicPropsClassName}Mixin on UiProps {
              String foo;
              int bar;
            }

            @Props()
            class $publicPropsClassName = UiProps
                with ${publicPropsClassName}Mixin, ConvertedMixin, UnconvertedMixin;

            ${componentDeclWithConsumedProps(['${publicPropsClassName}Mixin'])}
          ''',
          );

          expect(converter.visitedNames, {
            publicPropsClassName: '${publicPropsClassName}Mixin',
          });
        });

        test('that extends from UiProps, but uses a "reserved" mixin', () {
          const input = '''
              $factoryDecl
    
              @Props()
              class $propsClassName extends UiProps
                  with DomPropsMixin,
                       // ignore: mixin_of_non_class, undefined_class
                       \$DomPropsMixin {
                String foo;
                int bar;
              }
    
              $componentDecl
            ''';

          testSuggestor()(
            input: input,
            expectedOutput: '''
            $factoryDecl

            @Props()
            mixin ${publicPropsClassName}Mixin on UiProps {
              String foo;
              int bar;
            }

            @Props()
            class $publicPropsClassName = UiProps
                with ${publicPropsClassName}Mixin, DomPropsMixin;

            ${componentDeclWithConsumedProps(['${publicPropsClassName}Mixin'])}
          ''',
          );

          expect(converter.visitedNames, {
            publicPropsClassName: '${publicPropsClassName}Mixin',
          });
        });

        group('that extends from UiProps, uses mixins, implements interfaces',
            () {
          test('and is not abstract', () {
            testSuggestor(visitedClassNames: {
              'ConvertedMixin': 'ConvertedMixin',
            })(
              input: '''
              $factoryDecl

              @Props()
              class $propsClassName extends UiProps with ConvertedMixin implements SomeInterface, SomeOtherInterface {
                String foo;
                int bar;
              }

              $componentDecl
            ''',
              expectedOutput: '''
              $factoryDecl

              @Props()
              mixin ${publicPropsClassName}Mixin on UiProps implements SomeInterface, SomeOtherInterface {
                String foo;
                int bar;
              }

              @Props()
              class $publicPropsClassName = UiProps 
                  with ${publicPropsClassName}Mixin, ConvertedMixin implements SomeInterface, SomeOtherInterface;

              ${componentDeclWithConsumedProps([
                '${publicPropsClassName}Mixin'
              ])}
            ''',
            );

            expect(converter.visitedNames, {
              'ConvertedMixin': 'ConvertedMixin',
              publicPropsClassName: '${publicPropsClassName}Mixin',
            });
          });

          group('and is abstract', () {
            test('with members of its own', () {
              const input = r'''
              @AbstractProps()
              abstract class _$AbstractBlockProps extends UiProps
                  with
                      LayoutPropsMixin,
                      // ignore: mixin_of_non_class, undefined_class
                      $LayoutPropsMixin,
                      BlockPropsMixin,
                      // ignore: mixin_of_non_class, undefined_class
                      $BlockPropsMixin
                  implements
                      BlockClassHelperMapView {
                String foo;
                int bar;
              }

              @AbstractComponent2()
              abstract class AbstractBlockComponent<T extends AbstractBlockProps> extends UiComponent2<T>
                  with LayoutMixin<T>, BlockMixin<T> {}
            ''';

              testSuggestor()(
                input: input,
                expectedOutput: r'''
                @AbstractProps()
                mixin AbstractBlockPropsMixin on UiProps implements BlockClassHelperMapView {
                  String foo;
                  int bar;
                }

                @AbstractProps()
                abstract class AbstractBlockProps implements
                        AbstractBlockPropsMixin,
                        LayoutPropsMixin,
                        BlockPropsMixin,
                        BlockClassHelperMapView {}

                @AbstractComponent2()
                abstract class AbstractBlockComponent<T extends AbstractBlockProps> extends UiComponent2<T>
                    with LayoutMixin<T>, BlockMixin<T> {}
              ''',
              );

              expect(converter.visitedNames, {
                'AbstractBlockProps': 'AbstractBlockPropsMixin',
              });
            });

            test('with no members', () {
              const input = r'''
              @AbstractProps()
              abstract class _$AbstractBlockProps extends UiProps
                  with
                      LayoutPropsMixin,
                      // ignore: mixin_of_non_class, undefined_class
                      $LayoutPropsMixin,
                      BlockPropsMixin,
                      // ignore: mixin_of_non_class, undefined_class
                      $BlockPropsMixin
                  implements
                      BlockClassHelperMapView {}

              @AbstractComponent2()
              abstract class AbstractBlockComponent<T extends AbstractBlockProps> extends UiComponent2<T>
                  with LayoutMixin<T>, BlockMixin<T> {}
            ''';

              testSuggestor()(
                input: input,
                expectedOutput: r'''
                @AbstractProps()
                abstract class AbstractBlockProps implements
                        LayoutPropsMixin,
                        BlockPropsMixin,
                        BlockClassHelperMapView {}

                @AbstractComponent2()
                abstract class AbstractBlockComponent<T extends AbstractBlockProps> extends UiComponent2<T>
                    with LayoutMixin<T>, BlockMixin<T> {}
              ''',
              );

              expect(converter.visitedNames, {
                'AbstractBlockProps': 'AbstractBlockProps',
              });
            });
          });

          group('and is abstract based on annotation only (edge case)', () {
            test('with members of its own', () {
              const input = r'''
                  @PropsMixin()
                  abstract class BreadcrumbPathPropsMixin {}
                  
                  @AbstractProps()
                  class _$AbstractBreadcrumbPathProps extends UiProps
                      with
                          BreadcrumbPathPropsMixin,
                          // ignore: mixin_of_non_class, undefined_class
                          $BreadcrumbPathPropsMixin {
                    String foo;
                    int bar;
                  }
                  
                  @AbstractComponent2()
                  class AbstractBreadcrumbPathComponent<T extends AbstractBreadcrumbPathProps> 
                      extends UiComponent2<T> {}
                ''';

              testSuggestor(visitedClassNames: {
                'BreadcrumbPathPropsMixin': 'BreadcrumbPathPropsMixin',
              })(
                input: input,
                expectedOutput: r'''
                @PropsMixin()
                abstract class BreadcrumbPathPropsMixin {}
              
                @AbstractProps()
                mixin AbstractBreadcrumbPathPropsMixin on UiProps {
                  String foo;
                  int bar;
                }

                @AbstractProps()
                abstract class AbstractBreadcrumbPathProps 
                    implements
                        AbstractBreadcrumbPathPropsMixin,
                        BreadcrumbPathPropsMixin {}

                @AbstractComponent2()
                class AbstractBreadcrumbPathComponent<T extends AbstractBreadcrumbPathProps> 
                    extends UiComponent2<T> {}
              ''',
              );

              expect(converter.visitedNames, {
                'BreadcrumbPathPropsMixin': 'BreadcrumbPathPropsMixin',
                'AbstractBreadcrumbPathProps':
                    'AbstractBreadcrumbPathPropsMixin',
              });
            });

            test('with no members', () {
              const input = r'''
                  @PropsMixin()
                  abstract class BreadcrumbPathPropsMixin {}
                  
                  @AbstractProps()
                  class _$AbstractBreadcrumbPathProps extends UiProps
                      with
                          BreadcrumbPathPropsMixin,
                          // ignore: mixin_of_non_class, undefined_class
                          $BreadcrumbPathPropsMixin {}
                  
                  @AbstractComponent2()
                  class AbstractBreadcrumbPathComponent<T extends AbstractBreadcrumbPathProps> 
                      extends UiComponent2<T> {}
                ''';

              testSuggestor(visitedClassNames: {
                'BreadcrumbPathPropsMixin': 'BreadcrumbPathPropsMixin',
              })(
                input: input,
                expectedOutput: r'''
                @PropsMixin()
                abstract class BreadcrumbPathPropsMixin {}
                  
                @AbstractProps()
                abstract class AbstractBreadcrumbPathProps 
                    implements BreadcrumbPathPropsMixin {}

                @AbstractComponent2()
                class AbstractBreadcrumbPathComponent<T extends AbstractBreadcrumbPathProps> 
                    extends UiComponent2<T> {}
              ''',
              );

              expect(converter.visitedNames, {
                'BreadcrumbPathPropsMixin': 'BreadcrumbPathPropsMixin',
                'AbstractBreadcrumbPathProps': 'AbstractBreadcrumbPathProps',
              });
            });
          });
        });

        group(
            'and there is already a mixin that matches the name of the class appended with "Mixin"',
            () {
          group('and the class has no members of its own', () {
            test(
                'and an accompanying component class that does not override `consumedProps`',
                () {
              testSuggestor(visitedClassNames: {
                '${publicPropsClassName}Mixin': '${publicPropsClassName}Mixin',
              })(
                input: '''
                $factoryDecl
  
                @PropsMixin()
                mixin ${publicPropsClassName}Mixin on UiProps {
                  String foo;
                  int bar;
                }
  
                @Props()
                class $propsClassName extends UiProps with ${publicPropsClassName}Mixin {}
  
                @Component2()
                class FooComponent extends UiComponent2<$publicPropsClassName> {
                  @override
                  render() {}
                }
              ''',
                expectedOutput: '''
                $factoryDecl
  
                @PropsMixin()
                mixin ${publicPropsClassName}Mixin on UiProps {
                  String foo;
                  int bar;
                }
  
                @Component2()
                class FooComponent extends UiComponent2<${publicPropsClassName}Mixin> {
                  // Override consumedProps to an empty list so that props within 
                  // ${publicPropsClassName}Mixin are forwarded when `addUnconsumedProps` is used.
                  @override
                  get consumedProps => [];
                
                  @override
                  render() {} 
                }
              ''',
              );

              expect(converter.visitedNames, {
                '${publicPropsClassName}Mixin': '${publicPropsClassName}Mixin',
                publicPropsClassName: '${publicPropsClassName}Mixin',
              });
            });

            group(
                'and an accompanying component class that already overrides `consumedProps`',
                () {
              test('to an empty list', () {
                testSuggestor(visitedClassNames: {
                  '${publicPropsClassName}Mixin':
                      '${publicPropsClassName}Mixin',
                })(
                  input: '''
                  $factoryDecl
    
                  @PropsMixin()
                  mixin ${publicPropsClassName}Mixin on UiProps {
                    String foo;
                    int bar;
                  }
    
                  @Props()
                  class $propsClassName extends UiProps with ${publicPropsClassName}Mixin {}
    
                  @Component2()
                  class FooComponent extends UiComponent2<$publicPropsClassName> {
                    @override
                    get consumedProps => [];
                  
                    @override
                    render() {}
                  }
                ''',
                  expectedOutput: '''
                  $factoryDecl
    
                  @PropsMixin()
                  mixin ${publicPropsClassName}Mixin on UiProps {
                    String foo;
                    int bar;
                  }
    
                  @Component2()
                  class FooComponent extends UiComponent2<${publicPropsClassName}Mixin> {
                    @override
                    get consumedProps => [];
                  
                    @override
                    render() {} 
                  }
                ''',
                );
              });

              group('to a non-empty empty list using an ExpressionFunctionBody',
                  () {
                test('that contains `${publicPropsClassName}.meta`', () {
                  testSuggestor(visitedClassNames: {
                    '${publicPropsClassName}Mixin':
                        '${publicPropsClassName}Mixin',
                  })(
                    input: '''
                    $factoryDecl
      
                    @PropsMixin()
                    mixin ${publicPropsClassName}Mixin on UiProps {
                      String foo;
                      int bar;
                    }
      
                    @Props()
                    class $propsClassName extends UiProps with ${publicPropsClassName}Mixin {}
      
                    @Component2()
                    class FooComponent extends UiComponent2<$publicPropsClassName> {
                      @override
                      get consumedProps => [
                        $publicPropsClassName.meta,
                      ];
                    
                      @override
                      render() {}
                    }
                  ''',
                    expectedOutput: '''
                    $factoryDecl
      
                    @PropsMixin()
                    mixin ${publicPropsClassName}Mixin on UiProps {
                      String foo;
                      int bar;
                    }
      
                    @Component2()
                    class FooComponent extends UiComponent2<${publicPropsClassName}Mixin> {
                      // FIXME: As part of the over_react boilerplate migration, $publicPropsClassName was removed, 
                      // and replaced by ${publicPropsClassName}Mixin. Double check the `consumedProps` values below,
                      // and the prop forwarding behavior of this component to ensure that no regressions have occurred.
                      @override
                      get consumedProps => [
                        propsMeta.forMixin(${publicPropsClassName}Mixin),
                      ];
                    
                      @override
                      render() {} 
                    }
                  ''',
                  );
                });

                test('that does not contain `${publicPropsClassName}.meta`',
                    () {
                  testSuggestor(visitedClassNames: {
                    '${publicPropsClassName}Mixin':
                        '${publicPropsClassName}Mixin',
                  })(
                    input: '''
                    $factoryDecl
      
                    @PropsMixin()
                    mixin ${publicPropsClassName}Mixin on UiProps {
                      String foo;
                      int bar;
                    }
      
                    @Props()
                    class $propsClassName extends UiProps with ${publicPropsClassName}Mixin {}
      
                    @Component2()
                    class FooComponent extends UiComponent2<$publicPropsClassName> {
                      @override
                      get consumedProps => [
                        propsMeta.forMixin(${publicPropsClassName}Mixin),
                      ];
                    
                      @override
                      render() {}
                    }
                  ''',
                    expectedOutput: '''
                    $factoryDecl
      
                    @PropsMixin()
                    mixin ${publicPropsClassName}Mixin on UiProps {
                      String foo;
                      int bar;
                    }
      
                    @Component2()
                    class FooComponent extends UiComponent2<${publicPropsClassName}Mixin> {
                      // FIXME: As part of the over_react boilerplate migration, $publicPropsClassName was removed, 
                      // and replaced by ${publicPropsClassName}Mixin. Double check the `consumedProps` values below,
                      // and the prop forwarding behavior of this component to ensure that no regressions have occurred.
                      @override
                      get consumedProps => [
                        propsMeta.forMixin(${publicPropsClassName}Mixin),
                      ];
                    
                      @override
                      render() {} 
                    }
                  ''',
                  );
                });
              });

              group('to a non-empty empty list using an BlockFunctionBody', () {
                test('that contains `${publicPropsClassName}.meta`', () {
                  testSuggestor(visitedClassNames: {
                    '${publicPropsClassName}Mixin':
                        '${publicPropsClassName}Mixin',
                  })(
                    input: '''
                    $factoryDecl
      
                    @PropsMixin()
                    mixin ${publicPropsClassName}Mixin on UiProps {
                      String foo;
                      int bar;
                    }
      
                    @Props()
                    class $propsClassName extends UiProps with ${publicPropsClassName}Mixin {}
      
                    @Component2()
                    class FooComponent extends UiComponent2<$publicPropsClassName> {
                      @override
                      get consumedProps {
                        return [
                          $publicPropsClassName.meta,
                        ];
                      }
                    
                      @override
                      render() {}
                    }
                  ''',
                    expectedOutput: '''
                    $factoryDecl
      
                    @PropsMixin()
                    mixin ${publicPropsClassName}Mixin on UiProps {
                      String foo;
                      int bar;
                    }
      
                    @Component2()
                    class FooComponent extends UiComponent2<${publicPropsClassName}Mixin> {
                      // FIXME: As part of the over_react boilerplate migration, $publicPropsClassName was removed, 
                      // and replaced by ${publicPropsClassName}Mixin. Double check the `consumedProps` values below,
                      // and the prop forwarding behavior of this component to ensure that no regressions have occurred.
                      @override
                      get consumedProps { 
                        return [
                          propsMeta.forMixin(${publicPropsClassName}Mixin),
                        ];
                      }
                    
                      @override
                      render() {} 
                    }
                  ''',
                  );
                });

                test('that does not contain `${publicPropsClassName}.meta`',
                    () {
                  testSuggestor(visitedClassNames: {
                    '${publicPropsClassName}Mixin':
                        '${publicPropsClassName}Mixin',
                  })(
                    input: '''
                    $factoryDecl
      
                    @PropsMixin()
                    mixin ${publicPropsClassName}Mixin on UiProps {
                      String foo;
                      int bar;
                    }
      
                    @Props()
                    class $propsClassName extends UiProps with ${publicPropsClassName}Mixin {}
      
                    @Component2()
                    class FooComponent extends UiComponent2<$publicPropsClassName> {
                      @override
                      get consumedProps { 
                        return [
                          propsMeta.forMixin(${publicPropsClassName}Mixin),
                        ];
                      }
                    
                      @override
                      render() {}
                    }
                  ''',
                    expectedOutput: '''
                    $factoryDecl
      
                    @PropsMixin()
                    mixin ${publicPropsClassName}Mixin on UiProps {
                      String foo;
                      int bar;
                    }
      
                    @Component2()
                    class FooComponent extends UiComponent2<${publicPropsClassName}Mixin> {
                      // FIXME: As part of the over_react boilerplate migration, $publicPropsClassName was removed, 
                      // and replaced by ${publicPropsClassName}Mixin. Double check the `consumedProps` values below,
                      // and the prop forwarding behavior of this component to ensure that no regressions have occurred.
                      @override
                      get consumedProps { 
                        return [
                          propsMeta.forMixin(${publicPropsClassName}Mixin),
                        ];
                      }
                    
                      @override
                      render() {} 
                    }
                  ''',
                  );
                });
              });
            });
          });

          group('and the class has members', () {
            test(
                'and an accompanying component class that does not override `consumedProps`',
                () {
              testSuggestor(visitedClassNames: {
                '${publicPropsClassName}Mixin': '${publicPropsClassName}Mixin',
              })(
                input: '''
                $factoryDecl

                @PropsMixin()
                mixin ${publicPropsClassName}Mixin on UiProps {
                  String foo;
                  int bar;
                }
  
                @Props()
                class $propsClassName extends UiProps with ${publicPropsClassName}Mixin {
                  String baz;
                }
  
                @Component2()
                class FooComponent extends UiComponent2<$publicPropsClassName> {
                  @override
                  render() {}
                }
              ''',
                expectedOutput: '''
                $factoryDecl
  
                @PropsMixin()
                mixin ${publicPropsClassName}Mixin on UiProps {
                  String foo;
                  int bar;
                  String baz;
                }
  
                @Component2()
                class FooComponent extends UiComponent2<${publicPropsClassName}Mixin> {
                  // Override consumedProps to an empty list so that props within 
                  // ${publicPropsClassName}Mixin are forwarded when `addUnconsumedProps` is used.
                  @override
                  get consumedProps => [];
                
                  @override
                  render() {} 
                }
              ''',
              );

              expect(converter.visitedNames, {
                '${publicPropsClassName}Mixin': '${publicPropsClassName}Mixin',
                publicPropsClassName: '${publicPropsClassName}Mixin',
              });
            });

            group(
                'and an accompanying component class that already overrides `consumedProps`',
                () {
              test('to an empty list', () {
                testSuggestor(visitedClassNames: {
                  '${publicPropsClassName}Mixin':
                      '${publicPropsClassName}Mixin',
                })(
                  input: '''
                  $factoryDecl
    
                  @PropsMixin()
                  mixin ${publicPropsClassName}Mixin on UiProps {
                    String foo;
                    int bar;
                  }
    
                  @Props()
                  class $propsClassName extends UiProps with ${publicPropsClassName}Mixin {
                    String baz;
                  }
    
                  @Component2()
                  class FooComponent extends UiComponent2<$publicPropsClassName> {
                    @override
                    get consumedProps => [];
                  
                    @override
                    render() {}
                  }
                ''',
                  expectedOutput: '''
                  $factoryDecl
    
                  @PropsMixin()
                  mixin ${publicPropsClassName}Mixin on UiProps {
                    String foo;
                    int bar;
                    String baz;
                  }
    
                  @Component2()
                  class FooComponent extends UiComponent2<${publicPropsClassName}Mixin> {
                    @override
                    get consumedProps => [];
                  
                    @override
                    render() {} 
                  }
                ''',
                );
              });

              group('to a non-empty empty list using an ExpressionFunctionBody',
                  () {
                test('that contains `${publicPropsClassName}.meta`', () {
                  testSuggestor(visitedClassNames: {
                    '${publicPropsClassName}Mixin':
                        '${publicPropsClassName}Mixin',
                  })(
                    input: '''
                    $factoryDecl
      
                    @PropsMixin()
                    mixin ${publicPropsClassName}Mixin on UiProps {
                      String foo;
                      int bar;
                    }
      
                    @Props()
                    class $propsClassName extends UiProps with ${publicPropsClassName}Mixin {
                      String baz;
                    }
      
                    @Component2()
                    class FooComponent extends UiComponent2<$publicPropsClassName> {
                      @override
                      get consumedProps => [
                        $publicPropsClassName.meta,
                      ];
                    
                      @override
                      render() {}
                    }
                  ''',
                    expectedOutput: '''
                    $factoryDecl
      
                    @PropsMixin()
                    mixin ${publicPropsClassName}Mixin on UiProps {
                      String foo;
                      int bar;
                      String baz;
                    }
      
                    @Component2()
                    class FooComponent extends UiComponent2<${publicPropsClassName}Mixin> {
                      // FIXME: As part of the over_react boilerplate migration, $publicPropsClassName was removed, 
                      // and all of its props were moved to ${publicPropsClassName}Mixin. Double check the `consumedProps` values below,
                      // and the prop forwarding behavior of this component to ensure that no regressions have occurred.
                      @override
                      get consumedProps => [
                        propsMeta.forMixin(${publicPropsClassName}Mixin),
                      ];
                    
                      @override
                      render() {} 
                    }
                  ''',
                  );
                });

                test('that does not contain `${publicPropsClassName}.meta`',
                    () {
                  testSuggestor(visitedClassNames: {
                    '${publicPropsClassName}Mixin':
                        '${publicPropsClassName}Mixin',
                  })(
                    input: '''
                    $factoryDecl
      
                    @PropsMixin()
                    mixin ${publicPropsClassName}Mixin on UiProps {
                      String foo;
                      int bar;
                    }
      
                    @Props()
                    class $propsClassName extends UiProps with ${publicPropsClassName}Mixin {
                      String baz;
                    }
      
                    @Component2()
                    class FooComponent extends UiComponent2<$publicPropsClassName> {
                      @override
                      get consumedProps => [
                        propsMeta.forMixin(${publicPropsClassName}Mixin),
                      ];
                    
                      @override
                      render() {}
                    }
                  ''',
                    expectedOutput: '''
                    $factoryDecl
      
                    @PropsMixin()
                    mixin ${publicPropsClassName}Mixin on UiProps {
                      String foo;
                      int bar;
                      String baz;
                    }
      
                    @Component2()
                    class FooComponent extends UiComponent2<${publicPropsClassName}Mixin> {
                      // FIXME: As part of the over_react boilerplate migration, $publicPropsClassName was removed, 
                      // and all of its props were moved to ${publicPropsClassName}Mixin. Double check the `consumedProps` values below,
                      // and the prop forwarding behavior of this component to ensure that no regressions have occurred.
                      @override
                      get consumedProps => [
                        propsMeta.forMixin(${publicPropsClassName}Mixin),
                      ];
                    
                      @override
                      render() {} 
                    }
                  ''',
                  );
                });
              });

              group('to a non-empty empty list using an BlockFunctionBody', () {
                test('that contains `${publicPropsClassName}.meta`', () {
                  testSuggestor(visitedClassNames: {
                    '${publicPropsClassName}Mixin':
                        '${publicPropsClassName}Mixin',
                  })(
                    input: '''
                    $factoryDecl
      
                    @PropsMixin()
                    mixin ${publicPropsClassName}Mixin on UiProps {
                      String foo;
                      int bar;
                    }
      
                    @Props()
                    class $propsClassName extends UiProps with ${publicPropsClassName}Mixin {
                      String baz;
                    }
      
                    @Component2()
                    class FooComponent extends UiComponent2<$publicPropsClassName> {
                      @override
                      get consumedProps {
                        return [
                          $publicPropsClassName.meta,
                        ];
                      }
                    
                      @override
                      render() {}
                    }
                  ''',
                    expectedOutput: '''
                    $factoryDecl
      
                    @PropsMixin()
                    mixin ${publicPropsClassName}Mixin on UiProps {
                      String foo;
                      int bar;
                      String baz;
                    }
      
                    @Component2()
                    class FooComponent extends UiComponent2<${publicPropsClassName}Mixin> {
                      // FIXME: As part of the over_react boilerplate migration, $publicPropsClassName was removed, 
                      // and all of its props were moved to ${publicPropsClassName}Mixin. Double check the `consumedProps` values below,
                      // and the prop forwarding behavior of this component to ensure that no regressions have occurred.
                      @override
                      get consumedProps { 
                        return [
                          propsMeta.forMixin(${publicPropsClassName}Mixin),
                        ];
                      }
                    
                      @override
                      render() {} 
                    }
                  ''',
                  );
                });

                test('that does not contain `${publicPropsClassName}.meta`',
                    () {
                  testSuggestor(visitedClassNames: {
                    '${publicPropsClassName}Mixin':
                        '${publicPropsClassName}Mixin',
                  })(
                    input: '''
                    $factoryDecl
      
                    @PropsMixin()
                    mixin ${publicPropsClassName}Mixin on UiProps {
                      String foo;
                      int bar;
                    }
      
                    @Props()
                    class $propsClassName extends UiProps with ${publicPropsClassName}Mixin {
                      String baz;
                    }
      
                    @Component2()
                    class FooComponent extends UiComponent2<$publicPropsClassName> {
                      @override
                      get consumedProps { 
                        return [
                          propsMeta.forMixin(${publicPropsClassName}Mixin),
                        ];
                      }
                    
                      @override
                      render() {}
                    }
                  ''',
                    expectedOutput: '''
                    $factoryDecl
      
                    @PropsMixin()
                    mixin ${publicPropsClassName}Mixin on UiProps {
                      String foo;
                      int bar;
                      String baz;
                    }
      
                    @Component2()
                    class FooComponent extends UiComponent2<${publicPropsClassName}Mixin> {
                      // FIXME: As part of the over_react boilerplate migration, $publicPropsClassName was removed, 
                      // and all of its props were moved to ${publicPropsClassName}Mixin. Double check the `consumedProps` values below,
                      // and the prop forwarding behavior of this component to ensure that no regressions have occurred.
                      @override
                      get consumedProps { 
                        return [
                          propsMeta.forMixin(${publicPropsClassName}Mixin),
                        ];
                      }
                    
                      @override
                      render() {} 
                    }
                  ''',
                  );
                });
              });
            });
          });
        });
      });

      test(
          'and there are classes that extend from arbitrary custom classes, along with mixins',
          () {
        const input = '''
            $factoryDecl
    
            @Props()
            class $propsClassName extends ADifferentPropsClass with AMixin, AnotherMixin {
              String foo;
              int bar;
            }
    
            @State()
            class $stateClassName extends ADifferentStateClass with AStateMixin, AnotherStateMixin {
              String foo;
              int bar;
            }
    
            $statefulComponentDecl
          ''';

        // When it is run the first time, nothing should happen since
        // we don't know if the mixin(s) are external or not.
        testSuggestor()(expectedPatchCount: 0, input: input);
        testSuggestor(visitedClassNames: {
          'AMixin': 'AMixin',
          'AnotherMixin': 'AnotherMixin',
          'ADifferentPropsClass': 'ADifferentPropsClassMixin',
          'AStateMixin': 'AStateMixin',
          'AnotherStateMixin': 'AnotherStateMixin',
          'ADifferentStateClass': 'ADifferentStateClass',
        })(
          input: input,
          expectedOutput: '''
          $factoryDecl

          @Props()
          mixin ${publicPropsClassName}Mixin on UiProps {
            String foo;
            int bar;
          }

          @Props()
          // FIXME:
          //   1. Ensure that all mixins used by ADifferentPropsClass are also mixed into this class.
          //   2. Fix any analyzer warnings on this class about missing mixins.
          class $publicPropsClassName = UiProps 
              with ADifferentPropsClassMixin, ${publicPropsClassName}Mixin, AMixin, AnotherMixin;

          @State()
          mixin ${publicStateClassName}Mixin on UiState {
            String foo;
            int bar;
          }

          @State()
          // FIXME:
          //   1. Ensure that all mixins used by ADifferentStateClass are also mixed into this class.
          //   2. Fix any analyzer warnings on this class about missing mixins.
          class $publicStateClassName = UiState 
              with ADifferentStateClass, ${publicStateClassName}Mixin, AStateMixin, AnotherStateMixin;

          ${statefulComponentDeclWithConsumedProps([
            '${publicPropsClassName}Mixin'
          ])}
        ''',
        );

        expect(converter.visitedNames, {
          'AMixin': 'AMixin',
          'AnotherMixin': 'AnotherMixin',
          'ADifferentPropsClass': 'ADifferentPropsClassMixin',
          'AStateMixin': 'AStateMixin',
          'AnotherStateMixin': 'AnotherStateMixin',
          'ADifferentStateClass': 'ADifferentStateClass',
          publicPropsClassName: '${publicPropsClassName}Mixin',
          publicStateClassName: '${publicStateClassName}Mixin',
        });
      });

      group(
          'and there is a props class that extends from an arbitrary custom class, along with a mixin that has '
          'a name that matches the name of the class appended with "Mixin"',
          () {
        group('and that mixin exists in the same root', () {
          setUp(() {
            converter.setVisitedNames({
              '${publicPropsClassName}Mixin': '${publicPropsClassName}Mixin',
              'ADifferentPropsClass': 'ADifferentPropsClassMixin',
            });
          });

          test('and the class has no members', () {
            testSuggestor()(
              input: '''
              $factoryDecl

              @PropsMixin()
              mixin ${publicPropsClassName}Mixin on UiProps {
                String foo;
                int bar;
              }

              @Props()
              class $propsClassName extends ADifferentPropsClass with ${publicPropsClassName}Mixin {}

              $componentDecl
            ''',
              expectedOutput: '''
              $factoryDecl

              @PropsMixin()
              mixin ${publicPropsClassName}Mixin on UiProps {
                String foo;
                int bar;
              }

              @Props()
              // FIXME:
              //   1. Ensure that all mixins used by ADifferentPropsClass are also mixed into this class.
              //   2. Fix any analyzer warnings on this class about missing mixins.
              class $publicPropsClassName = UiProps with ADifferentPropsClassMixin, ${publicPropsClassName}Mixin;

              ${componentDeclWithConsumedProps([])}
            ''',
            );

            expect(converter.visitedNames, {
              '${publicPropsClassName}Mixin': '${publicPropsClassName}Mixin',
              'ADifferentPropsClass': 'ADifferentPropsClassMixin',
              publicPropsClassName: publicPropsClassName,
            });
          });

          test('and the class has members', () {
            testSuggestor()(
              input: '''
              $factoryDecl

              @PropsMixin()
              mixin ${publicPropsClassName}Mixin on UiProps {
                String foo;
                int bar;
              }

              @Props()
              class $propsClassName extends ADifferentPropsClass with ${publicPropsClassName}Mixin {
                String baz;
              }

              $componentDecl
            ''',
              expectedOutput: '''
              $factoryDecl

              @PropsMixin()
              mixin ${publicPropsClassName}Mixin on UiProps {
                String foo;
                int bar;
                String baz;
              }

              @Props()
              // FIXME:
              //   1. Ensure that all mixins used by ADifferentPropsClass are also mixed into this class.
              //   2. Fix any analyzer warnings on this class about missing mixins.
              class $publicPropsClassName = UiProps with ADifferentPropsClassMixin, ${publicPropsClassName}Mixin;

              ${componentDeclWithConsumedProps(
                ['${publicPropsClassName}Mixin'],
                fixmeComment:
                    '// FIXME ensure that these consumed props are correct, since fields were moved from $publicPropsClassName to ${publicPropsClassName}Mixin, but ${publicPropsClassName}Mixin was not consumed before.',
              )}
            ''',
            );

            expect(converter.visitedNames, {
              '${publicPropsClassName}Mixin': '${publicPropsClassName}Mixin',
              'ADifferentPropsClass': 'ADifferentPropsClassMixin',
              publicPropsClassName: publicPropsClassName,
            });
          });
        });

        group(
            'and that mixin does not exist in the same root, but has already been converted',
            () {
          setUp(() {
            converter.setVisitedNames({
              'ADifferentPropsClass': 'ADifferentPropsClassMixin',
              '${publicPropsClassName}Mixin': '${publicPropsClassName}Mixin',
            });
          });

          test('and the class has no members', () {
            testSuggestor()(
              input: '''
              $factoryDecl

              @Props()
              class $propsClassName extends ADifferentPropsClass with ${publicPropsClassName}Mixin {}

              $componentDecl
            ''',
              expectedOutput: '''
              $factoryDecl

              @Props()
              // FIXME:
              //   1. Ensure that all mixins used by ADifferentPropsClass are also mixed into this class.
              //   2. Fix any analyzer warnings on this class about missing mixins.
              class $publicPropsClassName = UiProps with ADifferentPropsClassMixin, ${publicPropsClassName}Mixin;

              ${componentDeclWithConsumedProps([])}
            ''',
            );

            expect(converter.visitedNames, {
              'ADifferentPropsClass': 'ADifferentPropsClassMixin',
              '${publicPropsClassName}Mixin': '${publicPropsClassName}Mixin',
              publicPropsClassName: publicPropsClassName,
            });
          });

          test('and the class has members', () {
            testSuggestor()(
              input: '''
              $factoryDecl

              @Props()
              class $propsClassName extends ADifferentPropsClass with ${publicPropsClassName}Mixin {
                String baz;
              }

              $componentDecl
            ''',
              expectedOutput: '''
              $factoryDecl

              @Props()
              // FIXME:
              //   1. Ensure that all mixins used by ADifferentPropsClass are also mixed into this class.
              //   2. Fix any analyzer warnings on this class about missing mixins.
              class $publicPropsClassName extends UiProps with ADifferentPropsClassMixin, ${publicPropsClassName}Mixin {
                // FIXME: Everything in this body needs to be moved to the body of ${publicPropsClassName}Mixin.
                // Once that is done, the body can be removed, and `extends` can be replaced with `=`.
                String baz;
              }              
              ${componentDeclWithConsumedProps([])}
            ''',
            );

            expect(converter.visitedNames, {
              'ADifferentPropsClass': 'ADifferentPropsClassMixin',
              '${publicPropsClassName}Mixin': '${publicPropsClassName}Mixin',
              publicPropsClassName: publicPropsClassName,
            });
          });
        });
      });
    });
  });
}

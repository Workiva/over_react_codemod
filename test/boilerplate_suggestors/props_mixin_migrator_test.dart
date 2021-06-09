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
import 'package:over_react_codemod/src/boilerplate_suggestors/props_mixins_migrator.dart';
import 'package:over_react_codemod/src/constants.dart';
import 'package:test/test.dart';

import '../util.dart';

void main() {
  group('PropsMixinMigrator', () {
    propsMixinMigratorTestHelper();

    group('with --treat-all-components-as-private flag', () {
      propsMixinMigratorTestHelper(
        shouldTreatAllComponentsAsPrivate: true,
      );
    });

    group('with invalid file path', () {
      propsMixinMigratorTestHelper(
        path: 'test/boilerplate_suggestors/does_not_exist.json',
        isValidFilePath: false,
      );
    });
  });
}

void propsMixinMigratorTestHelper({
  String path = 'test/boilerplate_suggestors/semver_report.json',
  bool shouldTreatAllComponentsAsPrivate = false,
  bool isValidFilePath = true,
}) {
  group('', () {
    final converter = ClassToMixinConverter();
    final semverHelper = getSemverHelper(path,
        shouldTreatAllComponentsAsPrivate: shouldTreatAllComponentsAsPrivate);
    final testSuggestor =
        getSuggestorTester(PropsMixinMigrator(converter, semverHelper));

    tearDown(() {
      converter.setVisitedNames({});
    });

    group('does not perform a migration', () {
      test('when it encounters an empty file', () {
        testSuggestor(expectedPatchCount: 0, input: '');
      });

      test('when there are no `PropsMixin()` annotations found', () {
        testSuggestor(
          expectedPatchCount: 0,
          input: '''
          abstract class FooPropsMixin implements UiProps {
            String foo;
          }
        ''',
        );
      });
    });

    void sharedTests(MixinType type,
        {bool withPrivateGeneratedPrefix = false}) {
      final typeStr = mixinStrByType[type];
      final mixinName = withPrivateGeneratedPrefix
          ? '_\$Foo${typeStr}Mixin'
          : 'Foo${typeStr}Mixin';

      group('converting the class to a mixin', () {
        group('when the class implements Ui$typeStr', () {
          test('only', () {
            testSuggestor(
              expectedPatchCount: withPrivateGeneratedPrefix ? 6 : 5,
              input: '''
              /// Some doc comment
              @${typeStr}Mixin()
              abstract class $mixinName implements Ui${typeStr} {
                // To ensure the codemod regression checking works properly, please keep this
                // field at the top of the class!
                // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
                static const ${typeStr}Meta meta = _\$metaForFoo${typeStr}Mixin;
                
                @override
                Map get ${typeStr.toLowerCase()};
                
                String foo;
              }
            ''',
              expectedOutput: isValidFilePath
                  ? '''
              /// Some doc comment
              @${typeStr}Mixin()
              mixin Foo${typeStr}Mixin on Ui${typeStr} {
                String foo;
              }
            '''
                  : '''
              /// Some doc comment
              @${typeStr}Mixin()
              mixin Foo${typeStr}Mixin on Ui${typeStr} {
                // To ensure the codemod regression checking works properly, please keep this
                // field at the top of the class!
                // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
                @Deprecated('Use `propsMeta.forMixin(Foo${typeStr}Mixin)` instead.')
                static const ${typeStr}Meta meta = _\$metaForFoo${typeStr}Mixin;
                
                String foo;
              }
            ''',
            );

            expect(converter.visitedNames, {
              'Foo${typeStr}Mixin': 'Foo${typeStr}Mixin',
            });
          });

          test('along with other interfaces (Ui$typeStr first)', () {
            testSuggestor(
              expectedPatchCount: withPrivateGeneratedPrefix ? 6 : 5,
              input: '''
              /// Some doc comment
              @${typeStr}Mixin()
              abstract class $mixinName implements Ui${typeStr}, Bar${typeStr}Mixin, Baz${typeStr}Mixin {
                // To ensure the codemod regression checking works properly, please keep this
                // field at the top of the class!
                // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
                static const ${typeStr}Meta meta = _\$metaForFoo${typeStr}Mixin;
                
                @override
                Map get ${typeStr.toLowerCase()};
                
                String foo;
              }
            ''',
              expectedOutput: isValidFilePath
                  ? '''
              /// Some doc comment
              @${typeStr}Mixin()
              mixin Foo${typeStr}Mixin on Ui${typeStr} implements Bar${typeStr}Mixin, Baz${typeStr}Mixin {
                String foo;
              }
            '''
                  : '''
              /// Some doc comment
              @${typeStr}Mixin()
              mixin Foo${typeStr}Mixin on Ui${typeStr} implements Bar${typeStr}Mixin, Baz${typeStr}Mixin {
                // To ensure the codemod regression checking works properly, please keep this
                // field at the top of the class!
                // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
                @Deprecated('Use `propsMeta.forMixin(Foo${typeStr}Mixin)` instead.')
                static const ${typeStr}Meta meta = _\$metaForFoo${typeStr}Mixin;
                
                String foo;
              }
            ''',
            );

            expect(converter.visitedNames, {
              'Foo${typeStr}Mixin': 'Foo${typeStr}Mixin',
            });
          });

          test('along with other interfaces (Ui$typeStr last)', () {
            testSuggestor(
              expectedPatchCount: withPrivateGeneratedPrefix ? 6 : 5,
              input: '''
              /// Some doc comment
              @${typeStr}Mixin()
              abstract class $mixinName implements Bar${typeStr}Mixin, Baz${typeStr}Mixin, Ui${typeStr} {
                // To ensure the codemod regression checking works properly, please keep this
                // field at the top of the class!
                // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
                static const ${typeStr}Meta meta = _\$metaForFoo${typeStr}Mixin;
                
                @override
                Map get ${typeStr.toLowerCase()};
                
                String foo;
              }
            ''',
              expectedOutput: isValidFilePath
                  ? '''
              /// Some doc comment
              @${typeStr}Mixin()
              mixin Foo${typeStr}Mixin on Ui${typeStr} implements Bar${typeStr}Mixin, Baz${typeStr}Mixin {
                String foo;
              }
            '''
                  : '''
              /// Some doc comment
              @${typeStr}Mixin()
              mixin Foo${typeStr}Mixin on Ui${typeStr} implements Bar${typeStr}Mixin, Baz${typeStr}Mixin {
                // To ensure the codemod regression checking works properly, please keep this
                // field at the top of the class!
                // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
                @Deprecated('Use `propsMeta.forMixin(Foo${typeStr}Mixin)` instead.')
                static const ${typeStr}Meta meta = _\$metaForFoo${typeStr}Mixin;
                
                String foo;
              }
            ''',
            );

            expect(converter.visitedNames, {
              'Foo${typeStr}Mixin': 'Foo${typeStr}Mixin',
            });
          });
        });

        group('when the class does not implement Ui$typeStr', () {
          test('but it does implement other interface(s)', () {
            testSuggestor(
              expectedPatchCount: withPrivateGeneratedPrefix ? 6 : 5,
              input: '''
              /// Some doc comment
              @${typeStr}Mixin()
              abstract class $mixinName implements Bar${typeStr}Mixin, Baz${typeStr}Mixin {
                // To ensure the codemod regression checking works properly, please keep this
                // field at the top of the class!
                // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
                static const ${typeStr}Meta meta = _\$metaForFoo${typeStr}Mixin;
                
                @override
                Map get ${typeStr.toLowerCase()};
                
                String foo;
              }
            ''',
              expectedOutput: isValidFilePath
                  ? '''
              /// Some doc comment
              @${typeStr}Mixin()
              mixin Foo${typeStr}Mixin on Ui${typeStr} implements Bar${typeStr}Mixin, Baz${typeStr}Mixin {
                String foo;
              }
            '''
                  : '''
              /// Some doc comment
              @${typeStr}Mixin()
              mixin Foo${typeStr}Mixin on Ui${typeStr} implements Bar${typeStr}Mixin, Baz${typeStr}Mixin {
                // To ensure the codemod regression checking works properly, please keep this
                // field at the top of the class!
                // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
                @Deprecated('Use `propsMeta.forMixin(Foo${typeStr}Mixin)` instead.')
                static const ${typeStr}Meta meta = _\$metaForFoo${typeStr}Mixin;
                
                String foo;
              }
            ''',
            );

            expect(converter.visitedNames, {
              'Foo${typeStr}Mixin': 'Foo${typeStr}Mixin',
            });
          });

          test('or any other interface', () {
            testSuggestor(
              expectedPatchCount: withPrivateGeneratedPrefix ? 6 : 5,
              input: '''
              /// Some doc comment
              @${typeStr}Mixin()
              abstract class $mixinName {
                // To ensure the codemod regression checking works properly, please keep this
                // field at the top of the class!
                // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
                static const ${typeStr}Meta meta = _\$metaForFoo${typeStr}Mixin;
                
                Map get ${typeStr.toLowerCase()};
                
                String foo;
              }
            ''',
              expectedOutput: isValidFilePath
                  ? '''
              /// Some doc comment
              @${typeStr}Mixin()
              mixin Foo${typeStr}Mixin on Ui${typeStr} {
                String foo;
              }
            '''
                  : '''
              /// Some doc comment
              @${typeStr}Mixin()
              mixin Foo${typeStr}Mixin on Ui${typeStr} {
                // To ensure the codemod regression checking works properly, please keep this
                // field at the top of the class!
                // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
                @Deprecated('Use `propsMeta.forMixin(Foo${typeStr}Mixin)` instead.')
                static const ${typeStr}Meta meta = _\$metaForFoo${typeStr}Mixin;
                
                String foo;
              }
            ''',
            );

            expect(converter.visitedNames, {
              'Foo${typeStr}Mixin': 'Foo${typeStr}Mixin',
            });
          });
        });
      });

      group('meta field', () {
        group('is removed if the class is not part of the public API', () {
          test('and the meta field is the first field in the class', () {
            testSuggestor(
              expectedPatchCount: withPrivateGeneratedPrefix ? 5 : 4,
              input: '''
              /// Some doc comment
              @${typeStr}Mixin()
              abstract class $mixinName implements Ui${typeStr} {
                // To ensure the codemod regression checking works properly, please keep this
                // field at the top of the class!
                // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
                static const ${typeStr}Meta meta = _\$metaForFoo${typeStr}Mixin;
                
                String foo;
              }
            ''',
              expectedOutput: isValidFilePath
                  ? '''
              /// Some doc comment
              @${typeStr}Mixin()
              mixin Foo${typeStr}Mixin on Ui${typeStr} {
                String foo;
              }
            '''
                  : '''
              /// Some doc comment
              @${typeStr}Mixin()
              mixin Foo${typeStr}Mixin on Ui${typeStr} {
                // To ensure the codemod regression checking works properly, please keep this
                // field at the top of the class!
                // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
                @Deprecated('Use `propsMeta.forMixin(Foo${typeStr}Mixin)` instead.')
                static const ${typeStr}Meta meta = _\$metaForFoo${typeStr}Mixin;
                
                String foo;
              }
            ''',
            );
          });

          test('and the meta field is not the first field in the class', () {
            testSuggestor(
              expectedPatchCount: withPrivateGeneratedPrefix ? 5 : 4,
              input: '''
              /// Some doc comment
              @${typeStr}Mixin()
              abstract class $mixinName implements Ui${typeStr} {
                // foooooo
                final baz = 'bar';
              
                // To ensure the codemod regression checking works properly, please keep this
                // field at the top of the class!
                // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
                static const ${typeStr}Meta meta = _\$metaForFoo${typeStr}Mixin;
                
                String foo;
              }
            ''',
              expectedOutput: isValidFilePath
                  ? '''
              /// Some doc comment
              @${typeStr}Mixin()
              mixin Foo${typeStr}Mixin on Ui${typeStr} {
                // foooooo
                final baz = 'bar';
                
                String foo;
              }
            '''
                  : '''
              /// Some doc comment
              @${typeStr}Mixin()
              mixin Foo${typeStr}Mixin on Ui${typeStr} {
                // foooooo
                final baz = 'bar';
                
                // To ensure the codemod regression checking works properly, please keep this
                // field at the top of the class!
                // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
                @Deprecated('Use `propsMeta.forMixin(Foo${typeStr}Mixin)` instead.')
                static const ${typeStr}Meta meta = _\$metaForFoo${typeStr}Mixin;
                
                String foo;
              }
            ''',
            );
          });

          test(
              'and the meta field is the first field in the class, but not the first member',
              () {
            testSuggestor(
              expectedPatchCount: withPrivateGeneratedPrefix ? 5 : 4,
              input: '''
              /// Some doc comment
              @${typeStr}Mixin()
              abstract class $mixinName implements Ui${typeStr} {
                // foooooo
                baz() => 'bar';
              
                // To ensure the codemod regression checking works properly, please keep this
                // field at the top of the class!
                // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
                static const ${typeStr}Meta meta = _\$metaForFoo${typeStr}Mixin;
                
                String foo;
              }
            ''',
              expectedOutput: isValidFilePath
                  ? '''
              /// Some doc comment
              @${typeStr}Mixin()
              mixin Foo${typeStr}Mixin on Ui${typeStr} {
                // foooooo
                baz() => 'bar';
                
                String foo;
              }
            '''
                  : '''
              /// Some doc comment
              @${typeStr}Mixin()
              mixin Foo${typeStr}Mixin on Ui${typeStr} {
                // foooooo
                baz() => 'bar';
                
                // To ensure the codemod regression checking works properly, please keep this
                // field at the top of the class!
                // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
                @Deprecated('Use `propsMeta.forMixin(Foo${typeStr}Mixin)` instead.')
                static const ${typeStr}Meta meta = _\$metaForFoo${typeStr}Mixin;
                
                String foo;
              }
            ''',
            );
          });
        });

        test('is deprecated if the class is part of the public API', () {
          final exportedMixinName = withPrivateGeneratedPrefix
              ? '_\$Bar${typeStr}Mixin'
              : 'Bar${typeStr}Mixin';

          testSuggestor(
            expectedPatchCount: withPrivateGeneratedPrefix ? 5 : 4,
            input: '''
            /// Some doc comment
            @${typeStr}Mixin()
            abstract class $exportedMixinName implements Ui${typeStr} {
              // To ensure the codemod regression checking works properly, please keep this
              // field at the top of the class!
              // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
              static const ${typeStr}Meta meta = _\$metaForBar${typeStr}Mixin;
              
              String foo;
            }
          ''',
            expectedOutput: shouldTreatAllComponentsAsPrivate
                ? '''
            /// Some doc comment
            @${typeStr}Mixin()
            mixin Bar${typeStr}Mixin on Ui${typeStr} {
              String foo;
            }
          '''
                : '''
            /// Some doc comment
            @${typeStr}Mixin()
            mixin Bar${typeStr}Mixin on Ui${typeStr} {
              // To ensure the codemod regression checking works properly, please keep this
              // field at the top of the class!
              // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
              @Deprecated('Use `propsMeta.forMixin(Bar${typeStr}Mixin)` instead.')
              static const ${typeStr}Meta meta = _\$metaForBar${typeStr}Mixin;
              
              String foo;
            }
          ''',
          );
        });
      });
    }

    group(
        'performs a migration when there is a `@PropsMixin()` annotation present:',
        () {
      sharedTests(MixinType.props);

      group('and the class begins with the $privateGeneratedPrefix prefix', () {
        sharedTests(MixinType.props, withPrivateGeneratedPrefix: true);
      });
    });

    group(
        'performs a migration when there is a `@StateMixin()` annotation present:',
        () {
      sharedTests(MixinType.state);

      group('and the class begins with the $privateGeneratedPrefix prefix', () {
        sharedTests(MixinType.props, withPrivateGeneratedPrefix: true);
      });
    });
  });
}

enum MixinType { props, state }

const mixinStrByType = {
  MixinType.props: 'Props',
  MixinType.state: 'State',
};

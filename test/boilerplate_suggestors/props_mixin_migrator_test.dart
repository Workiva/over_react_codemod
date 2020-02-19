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

import 'dart:convert';

import 'package:over_react_codemod/src/boilerplate_suggestors/boilerplate_utilities.dart';
import 'package:over_react_codemod/src/boilerplate_suggestors/props_mixins_migrator.dart';
import 'package:test/test.dart';

import '../util.dart';
import 'boilerplate_utilities_test.dart';

main() {
  group('PropsMixinMigrator', () {
    final converter = ClassToMixinConverter();
    final testSuggestor = getSuggestorTester(PropsMixinMigrator(converter));

    setUpAll(() {
      semverHelper = SemverHelper(jsonDecode(reportJson));
    });

    tearDown(() {
      converter.setVisitedClassNames({});
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

    void sharedTests(MixinType type) {
      final typeStr = mixinStrByType[type];

      group('converting the class to a mixin', () {
        group('when the class implements Ui$typeStr', () {
          test('only', () {
            testSuggestor(
              expectedPatchCount: 6,
              input: '''
              /// Some doc comment
              @${typeStr}Mixin()
              abstract class Foo${typeStr}Mixin implements Ui${typeStr} {
                // To ensure the codemod regression checking works properly, please keep this
                // field at the top of the class!
                // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
                static const ${typeStr}Meta meta = _\$metaForFoo${typeStr}Mixin;
                
                @override
                Map get ${typeStr.toLowerCase()};
                
                String foo;
              }
            ''',
              expectedOutput: '''
              /// Some doc comment
              mixin Foo${typeStr}Mixin on Ui${typeStr} {
                String foo;
              }
            ''',
            );

            expect(converter.visitedClassNames, {
              'Foo${typeStr}Mixin': 'Foo${typeStr}Mixin',
            });
          });

          test('along with other interfaces (Ui$typeStr first)', () {
            testSuggestor(
              expectedPatchCount: 6,
              input: '''
              /// Some doc comment
              @${typeStr}Mixin()
              abstract class Foo${typeStr}Mixin implements Ui${typeStr}, Bar${typeStr}Mixin, Baz${typeStr}Mixin {
                // To ensure the codemod regression checking works properly, please keep this
                // field at the top of the class!
                // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
                static const ${typeStr}Meta meta = _\$metaForFoo${typeStr}Mixin;
                
                @override
                Map get ${typeStr.toLowerCase()};
                
                String foo;
              }
            ''',
              expectedOutput: '''
              /// Some doc comment
              mixin Foo${typeStr}Mixin on Ui${typeStr} implements Bar${typeStr}Mixin, Baz${typeStr}Mixin {
                String foo;
              }
            ''',
            );

            expect(converter.visitedClassNames, {
              'Foo${typeStr}Mixin': 'Foo${typeStr}Mixin',
            });
          });

          test('along with other interfaces (Ui$typeStr last)', () {
            testSuggestor(
              expectedPatchCount: 6,
              input: '''
              /// Some doc comment
              @${typeStr}Mixin()
              abstract class Foo${typeStr}Mixin implements Bar${typeStr}Mixin, Baz${typeStr}Mixin, Ui${typeStr} {
                // To ensure the codemod regression checking works properly, please keep this
                // field at the top of the class!
                // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
                static const ${typeStr}Meta meta = _\$metaForFoo${typeStr}Mixin;
                
                @override
                Map get ${typeStr.toLowerCase()};
                
                String foo;
              }
            ''',
              expectedOutput: '''
              /// Some doc comment
              mixin Foo${typeStr}Mixin on Ui${typeStr} implements Bar${typeStr}Mixin, Baz${typeStr}Mixin {
                String foo;
              }
            ''',
            );

            expect(converter.visitedClassNames, {
              'Foo${typeStr}Mixin': 'Foo${typeStr}Mixin',
            });
          });
        });

        group('when the class does not implement Ui$typeStr', () {
          test('but it does implement other interface(s)', () {
            testSuggestor(
              expectedPatchCount: 6,
              input: '''
              /// Some doc comment
              @${typeStr}Mixin()
              abstract class Foo${typeStr}Mixin implements Bar${typeStr}Mixin, Baz${typeStr}Mixin {
                // To ensure the codemod regression checking works properly, please keep this
                // field at the top of the class!
                // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
                static const ${typeStr}Meta meta = _\$metaForFoo${typeStr}Mixin;
                
                @override
                Map get ${typeStr.toLowerCase()};
                
                String foo;
              }
            ''',
              expectedOutput: '''
              /// Some doc comment
              mixin Foo${typeStr}Mixin on Ui${typeStr} implements Bar${typeStr}Mixin, Baz${typeStr}Mixin {
                String foo;
              }
            ''',
            );

            expect(converter.visitedClassNames, {
              'Foo${typeStr}Mixin': 'Foo${typeStr}Mixin',
            });
          });

          test('or any other interface', () {
            testSuggestor(
              expectedPatchCount: 6,
              input: '''
              /// Some doc comment
              @${typeStr}Mixin()
              abstract class Foo${typeStr}Mixin {
                // To ensure the codemod regression checking works properly, please keep this
                // field at the top of the class!
                // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
                static const ${typeStr}Meta meta = _\$metaForFoo${typeStr}Mixin;
                
                Map get ${typeStr.toLowerCase()};
                
                String foo;
              }
            ''',
              expectedOutput: '''
              /// Some doc comment
              mixin Foo${typeStr}Mixin on Ui${typeStr} {
                String foo;
              }
            ''',
            );

            expect(converter.visitedClassNames, {
              'Foo${typeStr}Mixin': 'Foo${typeStr}Mixin',
            });
          });
        });
      });

      group('meta field', () {
        group('is removed if the class is not part of the public API', () {
          test('and the meta field is the first field in the class', () {
            testSuggestor(
              expectedPatchCount: 5,
              input: '''
              /// Some doc comment
              @${typeStr}Mixin()
              abstract class Foo${typeStr}Mixin implements Ui${typeStr} {
                // To ensure the codemod regression checking works properly, please keep this
                // field at the top of the class!
                // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
                static const ${typeStr}Meta meta = _\$metaForFoo${typeStr}Mixin;
                
                String foo;
              }
            ''',
              expectedOutput: '''
              /// Some doc comment
              mixin Foo${typeStr}Mixin on Ui${typeStr} {
                String foo;
              }
            ''',
            );
          });

          test('and the meta field is not the first field in the class', () {
            testSuggestor(
              expectedPatchCount: 5,
              input: '''
              /// Some doc comment
              @${typeStr}Mixin()
              abstract class Foo${typeStr}Mixin implements Ui${typeStr} {
                // foooooo
                final baz = 'bar';
              
                // To ensure the codemod regression checking works properly, please keep this
                // field at the top of the class!
                // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
                static const ${typeStr}Meta meta = _\$metaForFoo${typeStr}Mixin;
                
                String foo;
              }
            ''',
              expectedOutput: '''
              /// Some doc comment
              mixin Foo${typeStr}Mixin on Ui${typeStr} {
                // foooooo
                final baz = 'bar';
                
                String foo;
              }
            ''',
            );
          });

          test(
              'and the meta field is the first field in the class, but not the first member',
              () {
            testSuggestor(
              expectedPatchCount: 5,
              input: '''
              /// Some doc comment
              @${typeStr}Mixin()
              abstract class Foo${typeStr}Mixin implements Ui${typeStr} {
                // foooooo
                baz() => 'bar';
              
                // To ensure the codemod regression checking works properly, please keep this
                // field at the top of the class!
                // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
                static const ${typeStr}Meta meta = _\$metaForFoo${typeStr}Mixin;
                
                String foo;
              }
            ''',
              expectedOutput: '''
              /// Some doc comment
              mixin Foo${typeStr}Mixin on Ui${typeStr} {
                // foooooo
                baz() => 'bar';
                
                String foo;
              }
            ''',
            );
          });
        });

        test('is deprecated if the class is part of the public API', () {
          testSuggestor(
            expectedPatchCount: 5,
            input: '''
            /// Some doc comment
            @${typeStr}Mixin()
            abstract class Bar${typeStr}Mixin implements Ui${typeStr} {
              // To ensure the codemod regression checking works properly, please keep this
              // field at the top of the class!
              // ignore: undefined_identifier, undefined_class, const_initialized_with_non_constant_value
              static const ${typeStr}Meta meta = _\$metaForBar${typeStr}Mixin;
              
              String foo;
            }
          ''',
            expectedOutput: '''
            /// Some doc comment
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
    });

    group(
        'performs a migration when there is a `@StateMixin()` annotation present:',
        () {
      sharedTests(MixinType.state);
    });
  });
}

enum MixinType { props, state }

const mixinStrByType = {
  MixinType.props: 'Props',
  MixinType.state: 'State',
};

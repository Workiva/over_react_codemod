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

import 'package:over_react_codemod/src/dart2_9_suggestors/undefined_identifier_ignore_comment_remover.dart';
import 'package:test/test.dart';

import '../util.dart';

main() {
  group('UndefinedIdentifierIgnoreCommentRemover', () {
    final testSuggestor =
        getSuggestorTester(UndefinedIdentifierIgnoreCommentRemover());

    test('empty file', () {
      testSuggestor(expectedPatchCount: 0, input: '');
    });

    test('no matches', () {
      testSuggestor(
        expectedPatchCount: 0,
        input: '''
        library foo;
        var a = 'b';
        class Foo {}
      ''',
      );
    });

    group('on Component Factory Declarations:', () {
      group('does not remove', () {
        test('ignore comments from legacy boilerplate', () {
          testSuggestor(
            expectedPatchCount: 0,
            input: r'''
              @Factory()
              // ignore: undefined_identifier
              UiFactory<FooProps> Foo =
                // ignore: undefined_identifier
                _$Foo; // ignore: undefined_identifier
            ''',
          );
        });

        test('other ignore comments', () {
          testSuggestor(
            expectedPatchCount: 0,
            input: r'''
              // ignore: invalid_assignment
              UiFactory<FooProps> Foo =
                // ignore: unused_element
                _$Foo; // ignore: unused_element
            ''',
          );
        });
      });

      group('correctly removes undefined_identifier ignore comments', () {
        test('when the comment is on the same line', () {
          testSuggestor(
            expectedPatchCount: 1,
            input: r'''
              UiFactory<FooProps> Foo = _$Foo; // ignore: undefined_identifier
            ''',
            expectedOutput: r'''
              UiFactory<FooProps> Foo = _$Foo;
            ''',
          );
        });

        test('when the comment is on the initializer', () {
          testSuggestor(
            expectedPatchCount: 1,
            input: r'''
              UiFactory<FooProps> Foo =
                // ignore: undefined_identifier
                _$Foo;
            ''',
            expectedOutput: r'''
              UiFactory<FooProps> Foo = _$Foo;
            ''',
          );
        });

        test('when the comment is on the preceding line', () {
          testSuggestor(
            expectedPatchCount: 1,
            input: r'''
              // ignore: undefined_identifier
              UiFactory<FooProps> Foo = _$Foo;
            ''',
            expectedOutput: r'''
              UiFactory<FooProps> Foo = _$Foo;
            ''',
          );
        });

        test('when there is another comment above it', () {
          testSuggestor(
            expectedPatchCount: 1,
            input: r'''
              // this is another comment
              // ignore: undefined_identifier
              UiFactory<FooProps> Foo = _$Foo; 
            ''',
            expectedOutput: r'''
              // this is another comment
              UiFactory<FooProps> Foo = _$Foo; 
            ''',
          );
        });

        test('when there is a doc comment above it', () {
          testSuggestor(
            expectedPatchCount: 1,
            input: r'''
              /// this is a doc comment
              // ignore: undefined_identifier
              UiFactory<FooProps> Foo = _$Foo; 
            ''',
            expectedOutput: r'''
              /// this is a doc comment
              UiFactory<FooProps> Foo = _$Foo; 
            ''',
          );
        });

        test('when there are multiple factories', () {
          testSuggestor(
            expectedPatchCount: 3,
            input: r'''
              UiFactory<FooProps> Foo = _$Foo; // ignore: undefined_identifier
              
              UiFactory<BarProps> Bar = 
                // ignore: undefined_identifier
                _$Bar; 
              
              // ignore: undefined_identifier
              UiFactory<BazProps> Baz = _$Baz;
            ''',
            expectedOutput: r'''
              UiFactory<FooProps> Foo = _$Foo;
              
              UiFactory<BarProps> Bar = _$Bar;
              
              UiFactory<BazProps> Baz = _$Baz;
            ''',
          );
        });

        group('when there are multiple ignores', () {
          test('in the same comment', () {
            testSuggestor(
              expectedPatchCount: 1,
              input: r'''
                UiFactory<FooProps> Foo = _$Foo; // ignore: invalid_assignment, undefined_identifier, unused_element
              ''',
              expectedOutput: r'''
                UiFactory<FooProps> Foo = _$Foo; // ignore: invalid_assignment, unused_element
              ''',
            );
          });

          test('in different comments', () {
            testSuggestor(
              expectedPatchCount: 3,
              input: r'''
                // ignore: undefined_identifier, unused_element
                UiFactory<FooProps> Foo = 
                  // ignore: undefined_identifier
                  _$Foo; // ignore: invalid_assignment, undefined_identifier 
              ''',
              expectedOutput: r'''
                // ignore: unused_element
                UiFactory<FooProps> Foo = _$Foo; // ignore: invalid_assignment
              ''',
            );
          });
        });
      });
    });

    group('on Factory Configs:', () {
      group('does not remove', () {
        test('other ignore comments', () {
          testSuggestor(
            expectedPatchCount: 0,
            input: r'''
              final Foo = uiFunction<FooProps>(
                (props) {}, 
                // ignore: invalid_assignment
                _$FooConfig, // ignore: unused_element
              );
            ''',
          );
        });

        test('when the config is public', () {
          testSuggestor(
            expectedPatchCount: 0,
            input: r'''
              final Foo = uiForwardRef<FooProps>(
                (props, ref) {},
                $TopLevelForwardUiRefFunctionConfig, // ignore: undefined_identifier
              );
            ''',
          );
        });
      });

      group('correctly removes undefined_identifier ignore comments', () {
        group('when the comment is on the same line', () {
          test('after the comma', () {
            testSuggestor(
              expectedPatchCount: 1,
              input: r'''
                final Foo = uiForwardRef<FooProps>(
                  (props, ref) {},
                  _$TopLevelForwardUiRefFunctionConfig, // ignore: undefined_identifier
                );
              ''',
              expectedOutput: r'''
                final Foo = uiForwardRef<FooProps>(
                  (props, ref) {},
                  _$TopLevelForwardUiRefFunctionConfig,
                );
              ''',
            );
          });

          test('after the semicolon', () {
            testSuggestor(
              expectedPatchCount: 1,
              input: r'''
                UiFactory<FooProps> Foo = uiFunction(
                  (props) {},
                  _$FooConfig); // ignore: undefined_identifier
              ''',
              expectedOutput: r'''
                UiFactory<FooProps> Foo = uiFunction(
                  (props) {}, 
                  _$FooConfig);
              ''',
            );
          });
        });

        test('when the comment is on the preceding line', () {
          testSuggestor(
            expectedPatchCount: 1,
            input: r'''
              UiFactory<FooProps> Foo = uiFunction(
                (props) {}, 
                // ignore: undefined_identifier
                _$FooConfig, 
              );
            ''',
            expectedOutput: r'''
              UiFactory<FooProps> Foo = uiFunction(
                (props) {}, 
                _$FooConfig, 
              );
            ''',
          );
        });

        test('when there are multiple factories', () {
          testSuggestor(
            expectedPatchCount: 2,
            input: r'''
              final Foo = uiForwardRef<FooProps>(
                (props, ref) {},
                _$FooConfig, // ignore: undefined_identifier
              );
              
              UiFactory<BarProps> Bar = uiFunction(
                (props) {}, 
                // ignore: undefined_identifier
                _$BarConfig, 
              );
            ''',
            expectedOutput: r'''
              final Foo = uiForwardRef<FooProps>(
                (props, ref) {},
                _$FooConfig,
              );
              
              UiFactory<BarProps> Bar = uiFunction(
                (props) {}, 
                _$BarConfig, 
              );
            ''',
          );
        });

        group('when there are multiple ignores', () {
          test('in the same comment', () {
            testSuggestor(
              expectedPatchCount: 1,
              input: r'''
              UiFactory<FooProps> Foo = uiFunction(
                (props) {}, 
                _$FooConfig, // ignore: invalid_assignment, undefined_identifier, unused_element
              );
            ''',
              expectedOutput: r'''
              UiFactory<FooProps> Foo = uiFunction(
                (props) {}, 
                _$FooConfig, // ignore: invalid_assignment, unused_element
              );
            ''',
            );
          });

          test('in different comments', () {
            testSuggestor(
              expectedPatchCount: 2,
              input: r'''
                final Foo = uiFunction<FooProps>(
                  (props) {}, 
                  // ignore: undefined_identifier
                  _$FooConfig, // ignore: undefined_identifier, unused_element
                );
              ''',
              expectedOutput: r'''
                final Foo = uiFunction<FooProps>(
                  (props) {}, 
                  
                  _$FooConfig, // ignore: unused_element
                );
              ''',
            );
          });
        });

        test('when wrapped in an hoc', () {
          testSuggestor(
            expectedPatchCount: 1,
            input: r'''
              UiFactory<FooProps> Foo = someHOC(uiFunction(
                (props) {}, 
                _$FooConfig, // ignore: undefined_identifier
              ));
            ''',
            expectedOutput: r'''
              UiFactory<FooProps> Foo = someHOC(uiFunction(
                (props) {}, 
                _$FooConfig,
              ));
            ''',
          );
        });
      });
    });
  });
}

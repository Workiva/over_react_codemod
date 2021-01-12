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
import 'package:over_react_codemod/src/dart2_9_suggestors/dart2_9_utilities.dart';
import 'package:test/test.dart';

void main() {
  group('Dart 2.9 Utilities:', () {
    group('getGeneratedArg()', () {
      group('returns null', () {
        void _expectNullReturnValue(String input) {
          final unit = parseString(content: input).unit;
          final argList = (unit.declarations
              .whereType<TopLevelVariableDeclaration>()
              .first
              .variables
              .variables
              .first
              .initializer as MethodInvocation)
              .argumentList;

          expect(getGeneratedArg(argList), isNull);
        }

        test('when the config is not generated', () {
          _expectNullReturnValue(
            '''
              UiFactory<FooProps> Foo = uiForwardRef(
                (props) {},
                UiFactoryConfig(), // ignore: undefined_identifier
              );
            ''',
          );
        });

        test('when the second argument does not end with `Config`', () {
          _expectNullReturnValue(
            '''
              UiFactory<FooProps> Foo = uiForwardRef(
                (props) {},
                _\$Foo, // ignore: undefined_identifier
              );
            ''',
          );
        });

        test('when there are too many arguments', () {
          _expectNullReturnValue(
            '''
              UiFactory<FooProps> Foo = uiForwardRef(
                (props) {},
                _\$FooConfig, // ignore: undefined_identifier
                'another arg',
              );
            ''',
          );
        });
      });

      group('returns the generated factory config', () {
        void _expectConfigName({String input, String expectedName}) {
          final unit = parseString(content: input).unit;
          final argList = (unit.declarations
                  .whereType<TopLevelVariableDeclaration>()
                  .first
                  .variables
                  .variables
                  .first
                  .initializer as MethodInvocation)
              .argumentList;

          final returnValue = getGeneratedArg(argList);
          expect(returnValue, isA<SimpleIdentifier>());
          expect(returnValue.name, expectedName);
        }

        group('when the config is public', () {
          test('', () {
            _expectConfigName(
              input: '''
                UiFactory<FooProps> Foo = uiFunction(
                  (props) {},
                  \$FooConfig, // ignore: undefined_identifier
                );
              ''',
              expectedName: '\$FooConfig',
            );
          });

          test('and type casted', () {
            _expectConfigName(
              input: '''
              final Foo = uiFunction<FooProps>(
                (props) {},
                \$FooConfig as UiFactory<FooProps>, // ignore: undefined_identifier
              );
            ''',
              expectedName: '\$FooConfig',
            );
          });
        });

        group('when the config is private', () {
          test('', () {
            _expectConfigName(
              input: '''
                UiFactory<FooProps> Foo = uiFunction(
                  (props) {},
                  _\$FooConfig, // ignore: undefined_identifier
                );
              ''',
              expectedName: '_\$FooConfig',
            );
          });

          test('and type casted', () {
            _expectConfigName(
              input: '''
              final Foo = uiFunction<FooProps>(
                (props) {},
                _\$FooConfig as UiFactory<FooProps>, // ignore: undefined_identifier
              );
            ''',
              expectedName: '_\$FooConfig',
            );
          });
        });

        test('when the config is used in uiForwardRef', () {
          _expectConfigName(
            input: '''
              UiFactory<FooProps> Foo = uiForwardRef(
                (props) {},
                _\$FooConfig, // ignore: undefined_identifier
              );
            ''',
            expectedName: '_\$FooConfig',
          );
        });
      });

      group('returns the generated factory argument for connected components', () {
        void _expectGeneratedFactoryName({String input, String expectedName}) {
          final unit = parseString(content: input).unit;
          final argList = (unit.declarations
              .whereType<TopLevelVariableDeclaration>()
              .first
              .variables
              .variables
              .first
              .initializer as FunctionExpressionInvocation).argumentList;

          final returnValue = getGeneratedArg(argList);
          expect(returnValue, isA<SimpleIdentifier>());
          expect(returnValue.name, expectedName);
        }

        test('', () {
          _expectGeneratedFactoryName(
            input: '''
              UiFactory<FooProps> Foo = connect<SomeState, FooProps>(
                mapStateToProps: (state) => (Foo()
                  ..foo = state.foo
                  ..bar = state.bar
                ),
              )(_\$Foo); // ignore: undefined_identifier
            ''',
            expectedName: '_\$Foo',
          );
        });

        test('when the argument is type casted', () {
          _expectGeneratedFactoryName(
            input: '''
              UiFactory<FooProps> Foo = connect<SomeState, FooProps>(
                mapStateToProps: (state) => (Foo()
                  ..foo = state.foo
                  ..bar = state.bar
                ),
              )(_\$Foo as UiFactory<FooProps>); // ignore: undefined_identifier
            ''',
            expectedName: '_\$Foo',
          );
        });
      });
    });
  });
}

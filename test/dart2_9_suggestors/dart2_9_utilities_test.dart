// Copyright 2021 Workiva Inc.
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
import 'package:over_react_codemod/src/dart2_9_suggestors/dart2_9_constants.dart';
import 'package:over_react_codemod/src/dart2_9_suggestors/dart2_9_utilities.dart';
import 'package:test/test.dart';

void main() {
  group('Dart 2.9 Utilities:', () {
    group('getGeneratedFactoryArg()', () {
      group('returns null', () {
        void _expectNullReturnValue(String input) {
          final unit = parseString(content: input).unit;
          final argList = (unit.declarations
                  .whereType<TopLevelVariableDeclaration>()
                  .first
                  .variables
                  .variables
                  .first
                  .initializer as FunctionExpressionInvocation)
              .argumentList;

          expect(getGeneratedFactoryArg(argList), isNull);
        }

        test('when there are too many arguments', () {
          _expectNullReturnValue(
            '''
              UiFactory<FooProps> Foo = connect()(
                _\$Foo,
                'another arg',
              );
            ''',
          );
        });

        test('when when the method call is not connect', () {
          _expectNullReturnValue(
            '''
              UiFactory<FooProps> Foo = someOtherMethod()(_\$Foo);
            ''',
          );
        });
      });

      group('returns the generated factory argument for connected components',
          () {
        void _expectGeneratedFactoryName({String input, String expectedName}) {
          final unit = parseString(content: input).unit;
          final argList = (unit.declarations
                  .whereType<TopLevelVariableDeclaration>()
                  .first
                  .variables
                  .variables
                  .first
                  .initializer as FunctionExpressionInvocation)
              .argumentList;

          final returnValue = getGeneratedFactoryArg(argList);
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
              )($castFunctionName(_\$Foo)); // ignore: undefined_identifier
            ''',
            expectedName: '_\$Foo',
          );
        });
      });
    });

    group('getGeneratedFactoryConfigArg()', () {
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

          expect(getGeneratedFactoryConfigArg(argList), isNull);
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

          final returnValue = getGeneratedFactoryConfigArg(argList);
          expect(returnValue, isA<SimpleIdentifier>());
          expect(returnValue.name, expectedName);
        }

        test('when the config is public', () {
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

        test('when the config is private', () {
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
    });

    group('isClassComponentFactory()', () {
      group('returns false', () {
        void _expectFalse({String input}) {
          final unit = parseString(content: input).unit;
          final decl =
              unit.declarations.whereType<TopLevelVariableDeclaration>()?.first;

          expect(isClassComponentFactory(decl), isFalse);
        }

        test('when there is explicit type casting and no left hand typing', () {
          _expectFalse(input: '''
            final Foo = _\$Foo as UiFactory<FooProps>; // ignore: undefined_identifier
          ''');
        });

        test('when there is explicit type casting', () {
          _expectFalse(input: '''
            UiFactory<FooProps> Foo = _\$Foo as UiFactory<FooProps>; // ignore: undefined_identifier
          ''');
        });

        test('when the initializer is a non-cast method call', () {
          _expectFalse(input: '''
            UiFactory<FooProps> Foo = someMethod(_\$Foo);
          ''');
        });

        test('when the initializer is not generated', () {
          _expectFalse(input: '''
            UiFactory<FooProps> Foo = someFactory;
          ''');
        });

        test('when the input is not a component factory', () {
          _expectFalse(input: '''
            DriverFactory driverFactory = createDriver;
          ''');
        });
      });

      group('returns true', () {
        void _expectTrue({String input}) {
          final unit = parseString(content: input).unit;
          final decl =
              unit.declarations.whereType<TopLevelVariableDeclaration>()?.first;

          expect(isClassComponentFactory(decl), isTrue);
        }

        test('when the factory is annotated', () {
          _expectTrue(input: '''
            @Factory()
            UiFactory<FooProps> Foo = _\$Foo; // ignore: undefined_identifier
          ''');
        });

        test('when the factory is not annotated', () {
          _expectTrue(input: '''
            UiFactory<FooProps> Foo = _\$Foo; // ignore: undefined_identifier
          ''');
        });

        test('without ignore comment', () {
          _expectTrue(input: '''
            UiFactory<FooProps> Foo = _\$Foo;
          ''');
        });

        test('when the ignore comment is before the initializer', () {
          _expectTrue(input: '''
            UiFactory<FooProps> Foo = 
              // ignore: undefined_identifier
              _\$Foo;
          ''');
        });

        test('with type casting function', () {
          _expectTrue(input: '''
            UiFactory<FooProps> Foo = $castFunctionName(_\$Foo); // ignore: undefined_identifier
          ''');
        });
      });
    });

    group('isLegacyFactoryDecl()', () {
      group('returns false', () {
        void _expectFalse({String input}) {
          final unit = parseString(content: input).unit;
          final decl =
              unit.declarations.whereType<TopLevelVariableDeclaration>()?.first;

          expect(isLegacyFactoryDecl(decl), isFalse);
        }

        test('when the initializer is not generated', () {
          _expectFalse(input: '''
            UiFactory<FooProps> Foo = someFactory;
          ''');
        });

        test('when the input is not a component factory', () {
          _expectFalse(input: '''
            DriverFactory driverFactory = createDriver;
          ''');
        });

        test('when the factory is not annotated', () {
          _expectFalse(input: '''
            UiFactory<FooProps> Foo = _\$Foo; // ignore: undefined_identifier
          ''');
        });

        test('with type casting function', () {
          _expectFalse(input: '''
            UiFactory<FooProps> Foo = $castFunctionName(_\$Foo); // ignore: undefined_identifier
          ''');
        });
      });

      group('returns true', () {
        void _expectTrue({String input}) {
          final unit = parseString(content: input).unit;
          final decl =
              unit.declarations.whereType<TopLevelVariableDeclaration>()?.first;

          expect(isLegacyFactoryDecl(decl), isTrue);
        }

        test('when the factory is annotated', () {
          _expectTrue(input: '''
            @Factory()
            UiFactory<FooProps> Foo = _\$Foo; // ignore: undefined_identifier
          ''');
        });

        test('without ignore comment', () {
          _expectTrue(input: '''
            @Factory()
            UiFactory<FooProps> Foo = _\$Foo;
          ''');
        });

        test('when the ignore comment is before the initializer', () {
          _expectTrue(input: '''
            @Factory()
            UiFactory<FooProps> Foo = 
              // ignore: undefined_identifier
              _\$Foo;
          ''');
        });
      });
    });
  });
}

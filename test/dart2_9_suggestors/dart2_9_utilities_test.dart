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
          _expectNullReturnValue('''
            UiFactory<FooProps> Foo = uiForwardRef(
              (props) {},
              UiFactoryConfig(), // ignore: undefined_identifier
            );
          ''');
        });

        test('when the second argument does not end with `Config`', () {
          _expectNullReturnValue('''
            UiFactory<FooProps> Foo = uiForwardRef(
              (props) {},
              _\$Foo, // ignore: undefined_identifier
            );
          ''');
        });

        test('when there are too many arguments', () {
          _expectNullReturnValue('''
            UiFactory<FooProps> Foo = uiForwardRef(
              (props) {},
              _\$FooConfig, // ignore: undefined_identifier
              'another arg',
            );
          ''');
        });
      });

      group('returns the generated factory config', () {
        void _expectConfigName({required String input, String? expectedName}) {
          final unit = parseString(content: input).unit;
          final argList = (unit.declarations
                  .whereType<TopLevelVariableDeclaration>()
                  .first
                  .variables
                  .variables
                  .first
                  .initializer as MethodInvocation)
              .argumentList;

          final returnValue = getGeneratedFactoryConfigArg(argList)!;
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

        test('when the config has a number in the name', () {
          _expectConfigName(
            input: '''
              UiFactory<FooProps> Foo = uiFunction(
                (props) {},
                \$Foo2Config, // ignore: undefined_identifier
              );
            ''',
            expectedName: '\$Foo2Config',
          );
        });

        test('when the config has an underscore in the name', () {
          _expectConfigName(
            input: '''
              UiFactory<FooProps> _Foo = uiFunction(
                (props) {},
                \$_FooConfig, // ignore: undefined_identifier
              );
            ''',
            expectedName: '\$_FooConfig',
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

        test('when the function component is wrapped in memo', () {
          final input = '''
            UiFactory<FooProps> Foo = memo<FooProps>(uiFunction(
              (props) {},
              _\$FooConfig, // ignore: undefined_identifier
            ));
          ''';
          final unit = parseString(content: input).unit;
          final memoArgList = (unit.declarations
                  .whereType<TopLevelVariableDeclaration>()
                  .first
                  .variables
                  .variables
                  .first
                  .initializer as MethodInvocation)
              .argumentList;
          final uiFunctionArgList = memoArgList.arguments
              .whereType<MethodInvocation>()
              .first
              .argumentList;

          final returnValue = getGeneratedFactoryConfigArg(uiFunctionArgList)!;
          expect(returnValue, isA<SimpleIdentifier>());
          expect(returnValue.name, '_\$FooConfig');
        });
      });
    });

    group('getGeneratedFactory() and isClassOrConnectedComponentFactory()', () {
      group('returns null and false, respectively', () {
        void _expectNullReturnValue(String input) {
          final unit = parseString(content: input).unit;
          final decl =
              unit.declarations.whereType<TopLevelVariableDeclaration>().first;

          expect(getGeneratedFactory(decl), isNull);
          expect(isClassOrConnectedComponentFactory(decl), isFalse);
        }

        test('when the initializer is not generated', () {
          _expectNullReturnValue('''
            UiFactory<FooProps> Foo = someFactory;
          ''');
        });

        test('when the input is not a component factory', () {
          _expectNullReturnValue('''
            DriverFactory driverFactory = _\$Foo;
          ''');
        });

        test('when the generated name does not match the factory name', () {
          _expectNullReturnValue('''
            UiFactory<BarProps> Bar = _\$Foo;
          ''');
        });

        test('for function components', () {
          _expectNullReturnValue('''
            UiFactory<FooProps> Foo = uiFunction((props) {}, _\$FooConfig);
          ''');
        });
      });

      group('returns the generated factory and true, respectively', () {
        void _expectGeneratedFactoryName(
            {required String input, String? expectedName}) {
          final unit = parseString(content: input).unit;
          final decl =
              unit.declarations.whereType<TopLevelVariableDeclaration>().first;

          final returnValue = getGeneratedFactory(decl)!;
          expect(returnValue, isA<SimpleIdentifier>());
          expect(returnValue.name, expectedName);

          expect(isClassOrConnectedComponentFactory(decl), isTrue);
        }

        test('when the factory is annotated', () {
          _expectGeneratedFactoryName(
            input: '''
            @Factory()
            UiFactory<FooProps> Foo = _\$Foo; // ignore: undefined_identifier
          ''',
            expectedName: '_\$Foo',
          );
        });

        test('when the factory is not annotated', () {
          _expectGeneratedFactoryName(
            input: '''
            UiFactory<FooProps> Foo = _\$Foo; // ignore: undefined_identifier
          ''',
            expectedName: '_\$Foo',
          );
        });

        test('without ignore comment', () {
          _expectGeneratedFactoryName(
            input: '''
            UiFactory<FooProps> Foo = _\$Foo;
          ''',
            expectedName: '_\$Foo',
          );
        });

        test('when the initializer is wrapped in some function', () {
          _expectGeneratedFactoryName(
            input: '''
            UiFactory<FooProps> Foo = wrapper(_\$Foo);
          ''',
            expectedName: '_\$Foo',
          );
        });

        test('when the ignore comment is before the initializer', () {
          _expectGeneratedFactoryName(
            input: '''
            UiFactory<FooProps> Foo = 
              // ignore: undefined_identifier
              _\$Foo;
          ''',
            expectedName: '_\$Foo',
          );
        });

        test('when the ignore comment is for intl_message_migration', () {
          _expectGeneratedFactoryName(
            input: '''
            UiFactory<FooProps> Foo = 
              // ignore: intl_message_migration
              _\$Foo;
          ''',
            expectedName: '_\$Foo',
          );
        });

        test('with type casting function', () {
          _expectGeneratedFactoryName(
            input: '''
            UiFactory<FooProps> Foo = $castFunctionName(_\$Foo); // ignore: undefined_identifier
          ''',
            expectedName: '_\$Foo',
          );
        });

        test('when the generated factory is nested in wrapper functions', () {
          _expectGeneratedFactoryName(
            input: '''
              UiFactory<FooProps> Foo = wrapper(anotherFunction(someFunction(_\$Foo))); // ignore: undefined_identifier
            ''',
            expectedName: '_\$Foo',
          );
        });

        test('for connected components', () {
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

        test('for connected components with type casting', () {
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

        test('for `composeHocs`', () {
          _expectGeneratedFactoryName(
            input: '''
              UiFactory<FooProps> Foo = composeHocs([
                connect<RandomColorStore, FooProps>(
                  context: randomColorStoreContext,
                  mapStateToProps: (_) => {},
                  pure: false,
                ),
                connect<LowLevelStore, FooProps>(
                  context: lowLevelStoreContext,
                  mapStateToProps: (_) => {},
                  pure: false,
                ),
              ])(_\$Foo); // ignore: undefined_identifier
            ''',
            expectedName: '_\$Foo',
          );
        });
      });
    });

    group('isLegacyFactoryDecl()', () {
      group('returns false', () {
        void _expectFalse({required String input}) {
          final unit = parseString(content: input).unit;
          final decl =
              unit.declarations.whereType<TopLevelVariableDeclaration>().first;

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
        void _expectTrue({required String input}) {
          final unit = parseString(content: input).unit;
          final decl =
              unit.declarations.whereType<TopLevelVariableDeclaration>().first;

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

// @dart=2.7
// ^ Do not remove until migrated to null safety. More info at https://wiki.atl.workiva.net/pages/viewpage.action?pageId=189370832
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
import 'package:over_react_codemod/src/dart2_9_suggestors/latest_boilerplate_visitor.dart';
import 'package:test/test.dart';

void main() {
  group('LatestBoilerplateVisitor', () {
    group('`detectedLatestBoilerplate`', () {
      group('is `false` when', () {
        test('the file is empty', () {
          const src = ' ';

          final boilerplateVisitor = LatestBoilerplateVisitor();
          parseString(content: src).unit.accept(boilerplateVisitor);

          expect(boilerplateVisitor.detectedLatestBoilerplate, false);
        });

        test('the factory is not really a factory', () {
          const src = r'''
              AFactory<FooProps> Foo = foo;
              ''';

          final boilerplateVisitor = LatestBoilerplateVisitor();
          parseString(content: src).unit.accept(boilerplateVisitor);

          expect(boilerplateVisitor.detectedLatestBoilerplate, false);
        });

        group('a class based factory declaration is found and', () {
          test('is wrapped in a different function', () {
            const src = r'''
            UiFactory<FooProps> Foo = someRandomThing(_$Foo); // ignore: undefined_identifier
            ''';

            final boilerplateVisitor = LatestBoilerplateVisitor();
            parseString(content: src).unit.accept(boilerplateVisitor);

            expect(boilerplateVisitor.detectedLatestBoilerplate, false);
          });

          group('it is legacy', () {
            test('(simple)', () {
              const src = r'''
              @Factory()
              UiFactory<FooProps> Foo = _$Foo; // ignore: undefined_identifier
              ''';

              final boilerplateVisitor = LatestBoilerplateVisitor();
              parseString(content: src).unit.accept(boilerplateVisitor);

              expect(boilerplateVisitor.detectedLatestBoilerplate, false);
            });

            test('and connected', () {
              const src = r'''
              @Factory()
              UiFactory<FooProps> Foo = connect<TestState,FooProps>()(_$Foo); // ignore: undefined_identifier
              ''';

              final boilerplateVisitor = LatestBoilerplateVisitor();
              parseString(content: src).unit.accept(boilerplateVisitor);

              expect(boilerplateVisitor.detectedLatestBoilerplate, false);
            });

            test('and connected (`connectFlux`)', () {
              const src = r'''
              @Factory()
              UiFactory<FooProps> Foo = connectFlux<TestState,FooProps>()(_$Foo); // ignore: undefined_identifier
              ''';

              final boilerplateVisitor = LatestBoilerplateVisitor();
              parseString(content: src).unit.accept(boilerplateVisitor);

              expect(boilerplateVisitor.detectedLatestBoilerplate, false);
            });
          });
        });

        group('a function based factory is found and', () {
          group('it is legacy', () {
            test('(simple)', () {
              const src = r'''
              UiFactory<FooProps> Foo = uiFunction((props) {
                  return 'test';
                },
                $FooConfig, // ignore: undefined_identifier
              );
              ''';

              final boilerplateVisitor = LatestBoilerplateVisitor();
              parseString(content: src).unit.accept(boilerplateVisitor);

              expect(boilerplateVisitor.detectedLatestBoilerplate, false);
            });

            test('wrapped in an HOC', () {
              const src = r'''
              UiFactory<FooProps> Foo = memo(uiFunction((props) {
                  return 'test';
                },
                $FooConfig, // ignore: undefined_identifier
              ));
              ''';

              final boilerplateVisitor = LatestBoilerplateVisitor();
              parseString(content: src).unit.accept(boilerplateVisitor);

              expect(boilerplateVisitor.detectedLatestBoilerplate, false);
            });

            test('wrapped in an HOC (uiForwardRef)', () {
              const src = r'''
              UiFactory<FooProps> Foo = memo(uiForwardRef((props, _) {
                  return 'test';
                },
                $FooConfig, // ignore: undefined_identifier
              ));
              ''';

              final boilerplateVisitor = LatestBoilerplateVisitor();
              parseString(content: src).unit.accept(boilerplateVisitor);

              expect(boilerplateVisitor.detectedLatestBoilerplate, false);
            });

            test('with no LHS typing', () {
              const src = r'''
              final Foo = uiFunction((props) {
                  return 'test';
                },
                $FooConfig, // ignore: undefined_identifier
              );
              ''';

              final boilerplateVisitor = LatestBoilerplateVisitor();
              parseString(content: src).unit.accept(boilerplateVisitor);

              expect(boilerplateVisitor.detectedLatestBoilerplate, false);
            });

            test('with no trailing comma', () {
              const src = r'''
              final Foo = uiFunction((props) => 'test', $FooConfig); // ignore: undefined_identifier
              ''';

              final boilerplateVisitor = LatestBoilerplateVisitor();
              parseString(content: src).unit.accept(boilerplateVisitor);

              expect(boilerplateVisitor.detectedLatestBoilerplate, false);
            });
          });
        });
      });

      group('is true when new boilerplate is used in a', () {
        group('class based component factory declaration', () {
          test('that is simple', () {
            const src = r'''
            UiFactory<FooProps> Foo = castUiFactory(_$Foo); // ignore: undefined_identifier
            ''';

            final boilerplateVisitor = LatestBoilerplateVisitor();
            parseString(content: src).unit.accept(boilerplateVisitor);

            expect(boilerplateVisitor.detectedLatestBoilerplate, true);
          });

          test('that is simple (formatted on two lines)', () {
            const src = r'''
            UiFactory<FooProps> Foo = 
                // ignore: undefined_identifier
                castUiFactory(_$Foo);
            ''';

            final boilerplateVisitor = LatestBoilerplateVisitor();
            parseString(content: src).unit.accept(boilerplateVisitor);

            expect(boilerplateVisitor.detectedLatestBoilerplate, true);
          });

          test('with a wrapper function', () {
            const src = r'''
            UiFactory<FooProps> Foo = random(castUiFactory(_$Foo)); // ignore: undefined_identifier
            ''';

            final boilerplateVisitor = LatestBoilerplateVisitor();
            parseString(content: src).unit.accept(boilerplateVisitor);

            expect(boilerplateVisitor.detectedLatestBoilerplate, true);
          });

          test('with multiple factories', () {
            const src = r'''
            UiFactory<FooProps> Foo = castUiFactory(_$Foo); // ignore: undefined_identifier
            
            UiFactory<BarProps> Bar = 
              // ignore: undefined_identifier
              castUiFactory(_$Bar); 
            
            // ignore: undefined_identifier
            UiFactory<BazProps> Baz = castUiFactory(_$Baz);
            ''';

            final boilerplateVisitor = LatestBoilerplateVisitor();
            parseString(content: src).unit.accept(boilerplateVisitor);

            expect(boilerplateVisitor.detectedLatestBoilerplate, true);
          });

          test('with multiple factories (with one non-legacy)', () {
            const src = r'''
            UiFactory<FooProps> Foo = _$Foo; // ignore: undefined_identifier
            
            UiFactory<BarProps> Bar = 
              // ignore: undefined_identifier
              castUiFactory(_$Bar); 
            
            // ignore: undefined_identifier
            UiFactory<BazProps> Baz = _$Baz;
            ''';

            final boilerplateVisitor = LatestBoilerplateVisitor();
            parseString(content: src).unit.accept(boilerplateVisitor);

            expect(boilerplateVisitor.detectedLatestBoilerplate, true);
          });

          group('that is connected', () {
            test('(simple)', () {
              const src = r'''
              UiFactory<FooProps> Foo = connect<TestState, FooProps>()(castUiFactory(_$Foo)); // ignore: undefined_identifier
              ''';

              final boilerplateVisitor = LatestBoilerplateVisitor();
              parseString(content: src).unit.accept(boilerplateVisitor);

              expect(boilerplateVisitor.detectedLatestBoilerplate, true);
            });

            test('with two factories', () {
              const src = r'''
              UiFactory<FooProps> ConnectedFoo = 
                  connect<TestStore, FooProps>()(castUiFactory(Foo));
                  
              UiFactory<FooProps> Foo = castUiFactory(_$Foo); // ignore: undefined_identifier
              ''';

              final boilerplateVisitor = LatestBoilerplateVisitor();
              parseString(content: src).unit.accept(boilerplateVisitor);

              expect(boilerplateVisitor.detectedLatestBoilerplate, true);
            });
          });

          test('(`connectFlux`)', () {
            const src = r'''
              UiFactory<FooProps> Foo = connectFlux<TestState, FooProps>()(castUiFactory(_$Foo)); // ignore: undefined_identifier
              ''';

            final boilerplateVisitor = LatestBoilerplateVisitor();
            parseString(content: src).unit.accept(boilerplateVisitor);

            expect(boilerplateVisitor.detectedLatestBoilerplate, true);
          });
        });

        group('functional component declaration', () {
          test('(simple)', () {
            const src = r'''
              UiFactory<FooProps> Foo = uiFunction((props) {
                  return 'test';
                },
                _$FooConfig, // ignore: undefined_identifier
              );
              ''';

            final boilerplateVisitor = LatestBoilerplateVisitor();
            parseString(content: src).unit.accept(boilerplateVisitor);

            expect(boilerplateVisitor.detectedLatestBoilerplate, true);
          });

          test('wrapped in an HOC', () {
            const src = r'''
              UiFactory<FooProps> Foo = memo(uiFunction((props) {
                  return 'test';
                },
                _$FooConfig, // ignore: undefined_identifier
              ));
              ''';

            final boilerplateVisitor = LatestBoilerplateVisitor();
            parseString(content: src).unit.accept(boilerplateVisitor);

            expect(boilerplateVisitor.detectedLatestBoilerplate, true);
          });

          test('wrapped in an HOC (uiForwardRef)', () {
            const src = r'''
              UiFactory<FooProps> Foo = memo(uiForwardRef((props, _) {
                  return 'test';
                },
                _$FooConfig, // ignore: undefined_identifier
              ));
              ''';

            final boilerplateVisitor = LatestBoilerplateVisitor();
            parseString(content: src).unit.accept(boilerplateVisitor);

            expect(boilerplateVisitor.detectedLatestBoilerplate, true);
          });

          test('with no LHS typing', () {
            const src = r'''
              final Foo = uiFunction((props) {
                  return 'test';
                },
                _$FooConfig, // ignore: undefined_identifier
              );
              ''';

            final boilerplateVisitor = LatestBoilerplateVisitor();
            parseString(content: src).unit.accept(boilerplateVisitor);

            expect(boilerplateVisitor.detectedLatestBoilerplate, true);
          });

          test('with no trailing comma', () {
            const src = r'''
              final Foo = uiFunction((props) => 'test', _$FooConfig); // ignore: undefined_identifier
              ''';

            final boilerplateVisitor = LatestBoilerplateVisitor();
            parseString(content: src).unit.accept(boilerplateVisitor);

            expect(boilerplateVisitor.detectedLatestBoilerplate, true);
          });

          test('with multiple factories', () {
            const src = r'''
            final Foo = uiForwardRef<FooProps>(
                (props, ref) {},
                _$FooConfig, // ignore: undefined_identifier
              );
              
              UiFactory<BarProps> Bar = uiFunction(
                (props) {}, 
                _$BarConfig, // ignore: undefined_identifier
              );
              ''';

            final boilerplateVisitor = LatestBoilerplateVisitor();
            parseString(content: src).unit.accept(boilerplateVisitor);

            expect(boilerplateVisitor.detectedLatestBoilerplate, true);
          });

          test('with multiple factories (with one non-legacy)', () {
            const src = r'''
            final Foo = uiForwardRef<FooProps>(
                (props, ref) {},
                $FooConfig, // ignore: undefined_identifier
              );
              
              UiFactory<BarProps> Bar = uiFunction(
                (props) {}, 
                _$BarConfig, // ignore: undefined_identifier
              );
              ''';

            final boilerplateVisitor = LatestBoilerplateVisitor();
            parseString(content: src).unit.accept(boilerplateVisitor);

            expect(boilerplateVisitor.detectedLatestBoilerplate, true);
          });
        });
      });
    });
  });
}

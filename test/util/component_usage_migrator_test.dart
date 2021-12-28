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

import 'package:meta/meta.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:over_react_codemod/src/util/component_usage_migrator.dart';
import 'package:test/test.dart';

import '../resolved_file_context.dart';
import '../util.dart';

final sharedContext = SharedAnalysisContext.overReact;

main() {
  group('ComponentUsageMigrator', () {
    setUpAll(() async {
      await SharedAnalysisContext.overReact.warmUpAnalysis();
    });

    group('throws when a component usage is not resolved', () {
      test('', () async {
        const unresolvedUsages = [
          'Foo()()',
          '(Foo()..bar = "baz")()',
          'Dom.div()()',
          'builder()',
        ];

        for (final usage in unresolvedUsages) {
          final migrator = GenericMigrator(
              migrateUsage: boundExpectAsync2((_, __) {},
                  count: 0,
                  reason:
                      'migrator should not be called for any of these usages;'
                      ' it should throw first'));

          final context = await sharedContext.resolvedFileContextForTest(
            // We're intentionally not importing over_react here since we don't
            // want things like Dom.div to resolve.
            'usage() => $usage;',
            // Don't pre-resolve, otherwise resolvedFileContextForTest might throw.
            // We want to see how the migrator handles it when it's the first
            // thing that resolves a file.
            preResolveLibrary: false,
            throwOnAnalysisErrors: false,
          );
          await expectLater(
            () async => await migrator(context).toList(),
            throwsA(isA<Exception>().havingToStringValue(allOf(
              contains('Builder static type could not be resolved'),
              contains(usage),
            ))),
          );
        }
      });

      test(
          'but not for resolved dynamic calls might look like unresolved usages',
          () async {
        // Valid dynamic calls that are resolved and just looks like usages
        const source = /*language=dart*/ '''
            // Dynamic first and second invocation
            dynamic Foo1;
            usage1() => Foo1()();
            
            // Static first invocation, dynamic second invocation
            dynamic Foo2() {}
            dynamic builder2;
            usage2_1() => Foo2()();
            usage2_2() => builder2();
            
            // Static first/second invocation, dynamic return value
            dynamic Function() Foo3() {}
            dynamic builder3() {}
            usage3_1() => Foo3()();
            usage3_2() => builder3();
        ''';

        final migrator = GenericMigrator(
          migrateUsage: boundExpectAsync2((_, __) {},
              count: 0, reason: 'these calls should not be detected as usages'),
        );
        // awaiting this is the best way to assert it does not throw, since
        // returnsNormally doesn't work as intended with async functions.
        await sharedContext.getPatches(migrator, source);
      });
    });

    group('respects ignore comments, skipping shouldMigrateUsage when', () {
      group('a component usage is ignored', () {
        Future<List<FluentComponentUsage>> getShouldMigrateUsageCalls(
            String source) async {
          final calls = <FluentComponentUsage>[];
          final migrator = GenericMigrator(shouldMigrateUsage: (_, usage) {
            calls.add(usage);
            return false;
          });
          await sharedContext.getPatches(migrator, source);
          return calls;
        }

        test('via a plain orcm_ignore comment on the usage', () async {
          final source = withOverReactImport(/*language=dart*/ r'''
              usage() {
                // orcm_ignore
                Dom.div()("ignored via comment on line before");
                
                (Dom.div() // orcm_ignore
                  ..id = 'id'
                  ..onClick = (_) {}
                )("ignored via comment on same line");
                
                Dom.div()("not ignored");
                
                Dom.div()("not ignored (comment is on next line)");
                // orcm_ignore
                
                // orcm_ignore
                
                Dom.div()("not ignored (comment is two lines above)");
              }
          ''');

          final calls = await getShouldMigrateUsageCalls(source);
          expect(calls.map((u) => u.node.argumentList.toSource()).toList(), [
            '("not ignored")',
            '("not ignored (comment is on next line)")',
            '("not ignored (comment is two lines above)")',
          ]);
        });

        test('via a orcm_ignore comment with args on the usage', () async {
          final source = withOverReactImport(/*language=dart*/ r'''
              UiFactory<FooProps> Foo;
              mixin FooProps on UiProps {}
              
              usage() {
                // orcm_ignore: Foo
                Foo()("ignored via factory");
                // orcm_ignore: FooProps
                Foo()("ignored via props");
                
                // orcm_ignore:
                Foo()("not ignored (no args)");
                
                // orcm_ignore: Foo
                Dom.div()("not ignored (not a matching factory)");
                // orcm_ignore: FooProps
                Dom.div()("not ignored (not a matching props class)");
              }
          ''');

          final calls = await getShouldMigrateUsageCalls(source);
          expect(calls.map((u) => u.node.argumentList.toSource()).toList(), [
            '("not ignored (no args)")',
            '("not ignored (not a matching factory)")',
            '("not ignored (not a matching props class)")',
          ]);
        });

        test('via a plain orcm_ignore_for_file comment somewhere in the file',
            () async {
          final source = withOverReactImport(/*language=dart*/ r'''
              // orcm_ignore_for_file
          
              usage() {
                Dom.div()("ignored");
                Dom.div()("ignored");
              }
          ''');

          final calls = await getShouldMigrateUsageCalls(source);
          expect(calls, isEmpty);
        });

        test(
            'via an orcm_ignore_for_file comment with args somewhere in the file',
            () async {
          final source = withOverReactImport(/*language=dart*/ r'''          
              // orcm_ignore_for_file: Foo
              // orcm_ignore_for_file: BarProps
              // orcm_ignore_for_file: Dom.div, Dom.span
              // (Verify that that no args does not ignore everything)
              // orcm_ignore_for_file:
          
              UiFactory<FooProps> Foo;
              mixin FooProps on UiProps {}
              
              UiFactory<BarProps> Bar;
              mixin BarProps on UiProps {}
              
              UiFactory<BarProps> BarHoc;
              
              UiFactory<QuxProps> Qux;
              mixin QuxProps on UiProps {}
              
              usage() {
                Foo()("ignored in whole file via factory");
                
                Bar()("ignored in whole file via props");
                BarHoc()("ignored in whole file via props (different factory)");
                
                Dom.div()("ignored in whole file via (DOM) factory");
                Dom.span()("ignored in whole file via (DOM) factory (same comment)");
                
                Qux()("not ignored");
                Dom.a()("not ignored");
              }
          ''');

          final calls = await getShouldMigrateUsageCalls(source);
          expect(calls.map((u) => u.builder.toSource()).toList(), [
            'Qux()',
            'Dom.a()',
          ]);
        });
      });
    });

    group('calls migrateUsage for each component usage', () {
      test('only if shouldMigrateUsage returns true', () async {
        final migrateUsageCalls = <FluentComponentUsage>[];
        await sharedContext.getPatches(
          GenericMigrator(
            migrateUsage: (_, usage) => migrateUsageCalls.add(usage),
            shouldMigrateUsage: (_, usage) {
              switch (usage.builder.toSource()) {
                case 'Dom.div()':
                  return false;
                case 'Dom.span()':
                  return true;
              }
              throw ArgumentError('Unexpected builder');
            },
          ),
          withOverReactImport(/*language=dart*/ '''
              usages() => [
                Dom.div()(),
                Dom.span()(),
              ];
          '''),
        );
        expect(migrateUsageCalls.map((u) => u.builder.toSource()).toList(), [
          'Dom.span()',
        ]);
      });

      test('for all types of components', () async {
        final migrateUsageCalls = <FluentComponentUsage>[];
        await sharedContext.getPatches(
          GenericMigrator(
            migrateUsage: (_, usage) => migrateUsageCalls.add(usage),
          ),
          withOverReactImport(/*language=dart*/ '''
              UiFactory Foo;
              UiFactory Bar;
              UiProps builder;
              dynamic notAUsage() {}
              dynamic alsoNotAUsage;
                        
              usages() => Foo()(
                (Bar()..id = 'something')(),
                Dom.div()(),
                builder(),
                notAUsage(),
                alsoNotAUsage,
              );
          '''),
        );

        expect(migrateUsageCalls.map((u) => u.builder.toSource()).toList(), [
          'Foo()',
          'Bar()',
          'Dom.div()',
          'builder',
        ]);
      });
    });

    group('common usage flagging', () {
      test('flags the ref prop', () async {
        await testSuggestor(
          suggestor: GenericMigrator(),
          resolvedContext: sharedContext,
          input: withOverReactImport(/*language=dart*/ '''
              content() {
                (Dom.div()..ref = (ref) {})();
              }
          '''),
          expectedOutput: withOverReactImport(/*language=dart*/ '''
              content() {
                (Dom.div()
                  // FIXME(generic_migrator) - ref prop - manually verify ref type is correct
                  ..ref = (ref) {}
                )();
              }
          '''),
        );
      });

      test('flags the className prop', () async {
        await testSuggestor(
          suggestor: GenericMigrator(),
          resolvedContext: sharedContext,
          input: withOverReactImport(/*language=dart*/ '''
              content() {
                (Dom.div()..className = 'foo')();
              }
          '''),
          expectedOutput: withOverReactImport(/*language=dart*/ '''
              content() {
                (Dom.div()
                  // FIXME(generic_migrator) - className prop - manually verify (see doc for more details)
                  ..className = 'foo'
                )();
              }
          '''),
        );
      });

      test('flags prefixed props (except DOM and aria ones)', () async {
        await testSuggestor(
          suggestor: GenericMigrator(),
          resolvedContext: sharedContext,
          input: withOverReactImport(/*language=dart*/ '''
              UiFactory<FooProps> Foo;
              mixin FooProps on UiProps {
                dynamic otherPrefix;
              }
          
              content() {
                (Foo()
                  ..dom.id = 'id'
                  ..aria.label = 'label'
                  ..otherPrefix.something = 'foo'
                )();
              }
          '''),
          expectedOutput: withOverReactImport(/*language=dart*/ '''
              UiFactory<FooProps> Foo;
              mixin FooProps on UiProps {
                dynamic otherPrefix;
              }
          
              content() {
                (Foo()
                  ..dom.id = 'id'
                  ..aria.label = 'label'
                  // FIXME(generic_migrator) - otherPrefix (prefix) - manually verify
                  ..otherPrefix.something = 'foo'
                )();
              }
          '''),
        );
      });

      group('of untyped props:', () {
        const constantsSource = /*language=dart*/ '''

            const dataFooConst = 'data-foo';
            const somethingElseConst = 'somethingElse';

            class Foo {
              static const dataFooConst = 'data-foo';
              static const somethingElseConst = 'somethingElse';
            }
        ''';

        test('does not flag valid usages', () async {
          await testSuggestor(
            suggestor: GenericMigrator(
              migrateUsage: boundExpectAsync2((_, __) {},
                  // This suggestor gets run twice since idempotency is tested.
                  count: 2,
                  reason: 'should have run on the valid component usage'),
            ),
            resolvedContext: sharedContext,
            input: withOverReactImport(/*language=dart*/ '''
                contents() => (Dom.div()
                  ..addProp('data-foo', '')
                  ..addProp(dataFooConst, '')
                  ..addProp(Foo.dataFooConst, '')
                  ..['data-foo'] = ''
                  ..[dataFooConst] = ''
                  ..[Foo.dataFooConst] = ''
                  // ignore: not_enough_positional_arguments
                  ..addProp() /* bad call */
                )();
                $constantsSource
            '''),
          );
        });

        test('flags usages as expected', () async {
          await testSuggestor(
            suggestor: GenericMigrator(),
            resolvedContext: sharedContext,
            input: withOverReactImport(/*language=dart*/ '''
                bool condition;
            
                contents() => (Dom.div()
                  ..addProp('somethingElse', '')
                  ..addProp(somethingElseConst, '')
                  ..addProp(Foo.somethingElseConst, '')
                  ..['somethingElse'] = ''
                  ..[somethingElseConst] = ''
                  ..[Foo.somethingElseConst] = ''
                  ..[condition ? 'data-foo' : 'data-bar'] = ''
                )();
                $constantsSource
            '''),
            expectedOutput: withOverReactImport(/*language=dart*/ '''
                bool condition;
                
                contents() => (Dom.div()
                  // FIXME(generic_migrator) - addProp - manually verify prop key
                  ..addProp('somethingElse', '')
                  // FIXME(generic_migrator) - addProp - manually verify prop key
                  ..addProp(somethingElseConst, '')
                  // FIXME(generic_migrator) - addProp - manually verify prop key
                  ..addProp(Foo.somethingElseConst, '')
                  // FIXME(generic_migrator) - operator[]= - manually verify prop key
                  ..['somethingElse'] = ''
                  // FIXME(generic_migrator) - operator[]= - manually verify prop key
                  ..[somethingElseConst] = ''
                  // FIXME(generic_migrator) - operator[]= - manually verify prop key
                  ..[Foo.somethingElseConst] = ''
                  // FIXME(generic_migrator) - operator[]= - manually verify prop key
                  ..[condition ? 'data-foo' : 'data-bar'] = ''
                )();
                $constantsSource
            '''),
          );
        });
      });

      group('methods:', () {
        test('flags method calls other than addTestId', () async {
          await testSuggestor(
            suggestor: GenericMigrator(),
            resolvedContext: sharedContext,
            input: withOverReactImport(/*language=dart*/ '''            
                content() => (Dom.div()
                  ..addProps({})
                  ..modifyProps((_) {})
                  ..addTestId("foo")
                )();
            '''),
            expectedOutput: withOverReactImport(/*language=dart*/ '''
                content() => (Dom.div()
                  // FIXME(generic_migrator) - addProps call - manually verify
                  ..addProps({})
                  // FIXME(generic_migrator) - modifyProps call - manually verify
                  ..modifyProps((_) {})
                  ..addTestId("foo")
                )();
            '''),
          );
        });
      });

      test('flags static extension getters and setters', () async {
        const extensionSource = /*language=dart*/ '''
            extension on DomProps {
              get extensionGetter => null;
              set extensionSetter(value) {}
            }
        ''';

        await testSuggestor(
          suggestor: GenericMigrator(),
          resolvedContext: sharedContext,
          input: withOverReactImport(/*language=dart*/ '''
              content() => (Dom.div()
                ..extensionGetter
                ..extensionSetter = 'foo'
              )();
              
              $extensionSource
          '''),
          expectedOutput: withOverReactImport(/*language=dart*/ '''
              content() => (Dom.div()
                // FIXME(generic_migrator) - extensionGetter (extension) - manually verify
                ..extensionGetter
                // FIXME(generic_migrator) - extensionSetter (extension) - manually verify
                ..extensionSetter = 'foo'
              )();
              
              $extensionSource
          '''),
        );
      });
    });

    group('patch yielding utilities', () {
      group('yieldInsertionPatch', () {
        test('yields a patch with the same start and end location', () async {
          await testSuggestor(
            suggestor: GenericMigrator(migrateUsage: (migrator, usage) {
              migrator.yieldInsertionPatch('/*insertion*/', usage.node.offset);
            }),
            resolvedContext: sharedContext,
            input: withOverReactImport(/*language=dart*/ '''
                content() => Dom.div()();
            '''),
            expectedOutput: withOverReactImport(/*language=dart*/ '''
                content() => /*insertion*/Dom.div()();
            '''),
          );
        });
      });

      group('yieldPatchOverNode', () {
        test(
            'yields a patch with the same start and end position as the given node',
            () async {
          await testSuggestor(
            suggestor: GenericMigrator(migrateUsage: (migrator, usage) {
              migrator.yieldPatchOverNode('newBuilder', usage.builder);
            }),
            resolvedContext: sharedContext,
            input: withOverReactImport(/*language=dart*/ '''
                content() => Dom.div()();
            '''),
            expectedOutput: withOverReactImport(/*language=dart*/ '''
                content() => newBuilder();
            '''),
          );
        });
      });

      group('yieldAddPropPatch', yieldAddPropPatchTests);
      group('yieldRemovePropPatch', yieldRemovePropPatchTests);
      group('yieldPropPatch', yieldPropPatchTests);

      group('yieldBuilderMemberFixmePatch', yieldBuilderMemberFixmePatchTests);
      group('yieldPropFixmePatch', yieldPropFixmePatchTests);
      group('yieldChildFixmePatch', yieldChildFixmePatchTests);

      group('yieldPropManualMigratePatch', () {
        yieldPropFixmePatchTests(fixmeType: PropFixmeType.manuallyMigrate);
      });

      group('yieldRemoveChildPatch', yieldRemoveChildPatchTests);
      group('yieldAddChildPatch', yieldAddChildPatchTests);
    });
  });

  group('handleCascadedPropsByName', () {
    test('runs the migrator for each prop with a matching name', () async {
      final suggestor = GenericMigrator(migrateUsage: (migrator, usage) {
        handleCascadedPropsByName(usage, {
          'onClick': boundExpectAsync1((p) {
            expect(p.name.name, 'onClick');
          }),
          'href': boundExpectAsync1((p) {
            expect(p.name.name, 'href');
          }),
          'target': boundExpectAsync1((_) {},
              count: 0, reason: 'should not call props that are not present'),
        }, catchAll: boundExpectAsync1((p) {
          expect(p.name.name, 'id');
        }));
      });
      final source = withOverReactImport(/*language=dart*/ '''
          content() => (Dom.div()
            ..onClick = (_) {}
            ..href = "example.com"
            ..id = "foo"
          )();
      ''');
      await sharedContext.getPatches(suggestor, source);
    });

    test('throws when a prop does not exist on the props class', () async {
      final suggestor = GenericMigrator(migrateUsage: (migrator, usage) {
        handleCascadedPropsByName(usage, {
          'notARealProp': (_) {},
        });
      });

      final source = withOverReactImport('content() => Dom.div()();');
      expect(
          () async => await sharedContext.getPatches(suggestor, source),
          throwsA(isArgumentError.havingMessage(allOf(
            contains("'migratorsByName' contains unknown prop name"),
            contains("notARealProp"),
          ))));
    });
  });

  group('getFirstPropByName', () {
    test('returns the first prop with a matching name', () async {
      final suggestor = GenericMigrator(migrateUsage: (migrator, usage) {
        final prop = getFirstPropWithName(usage, 'href');
        expect(prop, isNotNull);
        expect(prop!.name.name, 'href');
        expect(prop.rightHandSide.toSource(), '"example.com/1"');
      });
      final source = withOverReactImport(/*language=dart*/ '''
          content() => (Dom.div()
            ..onClick = (_) {}
            ..href = "example.com/1"
            ..href = "example.com/2"
            ..id = "foo"
          )();
      ''');
      await sharedContext.getPatches(suggestor, source);
    });

    test('returns null when no prop matches the given name', () async {
      final suggestor = GenericMigrator(migrateUsage: (migrator, usage) {
        final prop = getFirstPropWithName(usage, 'href');
        expect(prop, isNull);
      });
      final source = withOverReactImport(/*language=dart*/ '''
          content() => (Dom.div()
            ..onClick = (_) {}
            ..id = "foo"
          )();
      ''');
      await sharedContext.getPatches(suggestor, source);
    });

    test('throws when a prop does not exist on the props class', () async {
      final suggestor = GenericMigrator(migrateUsage: (migrator, usage) {
        getFirstPropWithName(usage, 'notARealProp');
      });

      final source = withOverReactImport('content() => Dom.div()();');
      expect(
          () async => await sharedContext.getPatches(suggestor, source),
          throwsA(isArgumentError.havingMessage(allOf(
            contains("not statically available"),
            contains("notARealProp"),
          ))));
    });
  });
}

@isTestGroup
void yieldAddPropPatchTests() {
  test('when the builder is not parenthesized', () async {
    await testSuggestor(
      suggestor: GenericMigrator(migrateUsage: (migrator, usage) {
        migrator.yieldAddPropPatch(usage, '..foo = "foo"');
      }),
      resolvedContext: sharedContext,
      input: withOverReactImport(/*language=dart*/ '''
          content() => Dom.div()();
      '''),
      expectedOutput: withOverReactImport(/*language=dart*/ '''
          content() => (Dom.div()..foo = "foo")();
      '''),
    );
  });

  test(
      'when the builder is not parenthesized and yieldAddPropPatch is called more than once',
      () async {
    await testSuggestor(
      suggestor: GenericMigrator(migrateUsage: (migrator, usage) {
        migrator.yieldAddPropPatch(usage, '..foo = "foo"');
        migrator.yieldAddPropPatch(usage, '..bar = "bar"');
      }),
      resolvedContext: sharedContext,
      input: withOverReactImport(/*language=dart*/ '''
          content() => Dom.div()();
      '''),
      expectedOutput: withOverReactImport(/*language=dart*/ '''
          content() => ((Dom.div()
            ..foo = "foo"
            ..bar = "bar"
          ))();
      '''),
    );
  });

  test('when the builder is parenthesized with no cascade', () async {
    await testSuggestor(
      suggestor: GenericMigrator(migrateUsage: (migrator, usage) {
        migrator.yieldAddPropPatch(usage, '..foo = "foo"');
      }),
      resolvedContext: sharedContext,
      input: withOverReactImport(/*language=dart*/ '''
          content() => (Dom.div())();
      '''),
      expectedOutput: withOverReactImport(/*language=dart*/ '''
          content() => (Dom.div()..foo = "foo")();
      '''),
    );
  });

  test('when the builder has a single cascade on one line', () async {
    await testSuggestor(
      suggestor: GenericMigrator(migrateUsage: (migrator, usage) {
        final getLine = migrator.context.sourceFile.getLine;
        expect(getLine(usage.cascadeSections.single.offset),
            getLine(usage.builder.offset),
            reason: 'cascade and builder should be on the same line');

        migrator.yieldAddPropPatch(usage, '..foo = "foo"');
      }),
      resolvedContext: sharedContext,
      input: withOverReactImport(/*language=dart*/ '''
          content() => (Dom.div()..id = "some_id")();
      '''),
      expectedOutput: withOverReactImport(/*language=dart*/ '''
          content() => (Dom.div()
            ..id = "some_id"
            ..foo = "foo"
          )();
      '''),
    );
  });

  test('when the builder has a single cascade on a new line', () async {
    await testSuggestor(
      suggestor: GenericMigrator(migrateUsage: (migrator, usage) {
        final getLine = migrator.context.sourceFile.getLine;
        expect(getLine(usage.cascadeSections.single.offset),
            isNot(getLine(usage.builder.offset)),
            reason: 'cascade and builder should not be on the same line');

        migrator.yieldAddPropPatch(usage, '..foo = "foo"');
      }),
      resolvedContext: sharedContext,
      input: withOverReactImport(/*language=dart*/ '''
          content() => (Dom.div()
            // This comment puts this cascaded prop on a separate line
            ..id = "some_id"
          )();
      '''),
      expectedOutput: withOverReactImport(/*language=dart*/ '''
          content() => (Dom.div()
            // This comment puts this cascaded prop on a separate line
            ..id = "some_id"
            ..foo = "foo"
          )();
      '''),
    );
  });

  test('when the builder has multiple cascaded sections', () async {
    await testSuggestor(
      suggestor: GenericMigrator(migrateUsage: (migrator, usage) {
        migrator.yieldAddPropPatch(usage, '..foo = "foo"');
      }),
      resolvedContext: sharedContext,
      input: withOverReactImport(/*language=dart*/ '''
          content() => (Dom.div()
            ..id = "some_id"
            ..onClick = (_) {}
          )();
      '''),
      expectedOutput: withOverReactImport(/*language=dart*/ '''
          content() => (Dom.div()
            ..id = "some_id"
            ..onClick = (_) {}
            ..foo = "foo"
          )();
      '''),
    );
  });

  group('automatically places a prop in the best location', () {
    test('when there are no special case props', () async {
      await testSuggestor(
        suggestor: GenericMigrator(migrateUsage: (migrator, usage) {
          migrator.yieldAddPropPatch(usage, '..foo = "foo"');
        }),
        resolvedContext: sharedContext,
        input: withOverReactImport(/*language=dart*/ '''
            content() => (Dom.div()
              ..id = "some_id"
              ..style = {"width": '25rem'}
            )();
        '''),
        expectedOutput: withOverReactImport(/*language=dart*/ '''
            content() => (Dom.div()
              ..id = "some_id"
              ..style = {"width": '25rem'}
              ..foo = "foo"
            )();
        '''),
      );
    });

    group('when there are props that should remain last -', () {
      test('index assignment prop', () async {
        await testSuggestor(
          suggestor: GenericMigrator(migrateUsage: (migrator, usage) {
            migrator.yieldAddPropPatch(usage, '..foo = "foo"');
          }),
          resolvedContext: sharedContext,
          input: withOverReactImport(/*language=dart*/ '''
              content() => (Dom.div()
                ..id = "some_id"
                ..["data-test-id"] = "some_test_id"
              )();
          '''),
          expectedOutput: withOverReactImport(/*language=dart*/ '''
              content() => (Dom.div()
                ..id = "some_id"
                ..foo = "foo"
                ..["data-test-id"] = "some_test_id"
              )();
          '''),
        );
      });

      test('method invocation prop', () async {
        await testSuggestor(
          suggestor: GenericMigrator(migrateUsage: (migrator, usage) {
            migrator.yieldAddPropPatch(usage, '..foo = "foo"');
          }),
          resolvedContext: sharedContext,
          input: withOverReactImport(/*language=dart*/ '''
              content() => (Dom.div()
                ..id = "some_id"
                ..addTestId('some_test_id')
              )();
          '''),
          expectedOutput: withOverReactImport(/*language=dart*/ '''
              content() => (Dom.div()
                ..id = "some_id"
                ..foo = "foo"
                ..addTestId('some_test_id')
              )();
          '''),
        );
      });

      test('key prop', () async {
        await testSuggestor(
          suggestor: GenericMigrator(migrateUsage: (migrator, usage) {
            migrator.yieldAddPropPatch(usage, '..foo = "foo"');
          }),
          resolvedContext: sharedContext,
          input: withOverReactImport(/*language=dart*/ '''
              content() => (Dom.div()
                ..id = "some_id"
                ..key = "1"
              )();
          '''),
          expectedOutput: withOverReactImport(/*language=dart*/ '''
              content() => (Dom.div()
                ..id = "some_id"
                ..foo = "foo"
                ..key = "1"
              )();
          '''),
        );
      });

      test('ref prop', () async {
        await testSuggestor(
          suggestor: GenericMigrator(migrateUsage: (migrator, usage) {
            migrator.yieldAddPropPatch(usage, '..foo = "foo"');
          }),
          resolvedContext: sharedContext,
          input: withOverReactImport(/*language=dart*/ '''
              final ref = createRef();
              content() => (Dom.div()
                ..id = "some_id"
                ..ref = ref
              )();
          '''),
          expectedOutput: withOverReactImport(/*language=dart*/ '''
              final ref = createRef();
              content() => (Dom.div()
                ..id = "some_id"
                ..foo = "foo"
                // FIXME(generic_migrator) - ref prop - manually verify ref type is correct
                ..ref = ref
              )();
          '''),
        );
      });

      test('but the prop is not last', () async {
        await testSuggestor(
          suggestor: GenericMigrator(migrateUsage: (migrator, usage) {
            migrator.yieldAddPropPatch(usage, '..foo = "foo"');
          }),
          resolvedContext: sharedContext,
          input: withOverReactImport(/*language=dart*/ '''
              content() => (Dom.div()
                ..key = "1"
                ..id = "some_id"
              )();
          '''),
          expectedOutput: withOverReactImport(/*language=dart*/ '''
              content() => (Dom.div()
                ..key = "1"
                ..id = "some_id"
                ..foo = "foo"
              )();
          '''),
        );
      });
    });
  });

  test('when placement is NewPropPlacement.start', () async {
    await testSuggestor(
      suggestor: GenericMigrator(migrateUsage: (migrator, usage) {
        migrator.yieldAddPropPatch(usage, '..foo = "foo"',
            placement: NewPropPlacement.start);
      }),
      resolvedContext: sharedContext,
      input: withOverReactImport(/*language=dart*/ '''
          content() => (Dom.div()
            ..id = "some_id"
            ..key = "abc"
          )();
      '''),
      expectedOutput: withOverReactImport(/*language=dart*/ '''
          content() => (Dom.div()
            ..foo = "foo"
            ..id = "some_id"
            ..key = "abc"
          )();
      '''),
    );
  });

  test('when placement is NewPropPlacement.end', () async {
    await testSuggestor(
      suggestor: GenericMigrator(migrateUsage: (migrator, usage) {
        migrator.yieldAddPropPatch(usage, '..foo = "foo"',
            placement: NewPropPlacement.end);
      }),
      resolvedContext: sharedContext,
      input: withOverReactImport(/*language=dart*/ '''
          content() => (Dom.div()
            ..id = "some_id"
            ..key = "abc"
            ..addTestId("some_test_id")
          )();
      '''),
      expectedOutput: withOverReactImport(/*language=dart*/ '''
          content() => (Dom.div()
            ..id = "some_id"
            ..key = "abc"
            ..addTestId("some_test_id")
            ..foo = "foo"
          )();
      '''),
    );
  });
}

void yieldRemovePropPatchTests() {
  group('when the builder has more than one cascade section', () {
    test('and the first prop is removed', () async {
      await testSuggestor(
        suggestor: GenericMigrator(migrateUsage: (migrator, usage) {
          migrator.yieldRemovePropPatch(usage.cascadedProps.first);
        }),
        resolvedContext: sharedContext,
        input: withOverReactImport(/*language=dart*/ '''
            content() => (Dom.div()
              ..id = "some_id"
              ..onClick = (_) {}
              ..title = "title"
            )();
        '''),
        expectedOutput: withOverReactImport(/*language=dart*/ '''
            content() => (Dom.div()
              ..onClick = (_) {}
              ..title = "title"
            )();
        '''),
      );
    });

    test('and a middle prop is removed', () async {
      await testSuggestor(
        suggestor: GenericMigrator(migrateUsage: (migrator, usage) {
          migrator.yieldRemovePropPatch(usage.cascadedProps.elementAt(1));
        }),
        resolvedContext: sharedContext,
        input: withOverReactImport(/*language=dart*/ '''
            content() => (Dom.div()
              ..id = "some_id"
              ..onClick = (_) {}
              ..title = "title"
            )();
        '''),
        expectedOutput: withOverReactImport(/*language=dart*/ '''
            content() => (Dom.div()
              ..id = "some_id"
              ..title = "title"
            )();
        '''),
      );
    });

    test('and the last prop is removed', () async {
      await testSuggestor(
        suggestor: GenericMigrator(migrateUsage: (migrator, usage) {
          migrator.yieldRemovePropPatch(usage.cascadedProps.last);
        }),
        resolvedContext: sharedContext,
        input: withOverReactImport(/*language=dart*/ '''
            content() => (Dom.div()
              ..id = "some_id"
              ..onClick = (_) {}
              ..title = "title"
            )();
        '''),
        expectedOutput: withOverReactImport(/*language=dart*/ '''
            content() => (Dom.div()
              ..id = "some_id"
              ..onClick = (_) {}
            )();
        '''),
      );
    });
  });

  test('when the builder has a single prop', () async {
    await testSuggestor(
      suggestor: GenericMigrator(migrateUsage: (migrator, usage) {
        migrator.yieldRemovePropPatch(usage.cascadedProps.single);
      }),
      resolvedContext: sharedContext,
      input: withOverReactImport(/*language=dart*/ '''
          content() => (Dom.div()
            ..id = "some_id"
          )();
      '''),
      expectedOutput: withOverReactImport(/*language=dart*/ '''
          content() => (Dom.div())();
      '''),
    );
  });
}

@isTestGroup
void yieldBuilderMemberFixmePatchTests() {
  group(
      'adds a FIXME comment to a cascaded member with a custom message,'
      ' placing newlines properly so that the comment stays attached to the node after formatting',
      () {
    test('for the first cascade section', () async {
      await testSuggestor(
        suggestor: GenericMigrator(migrateUsage: (migrator, usage) {
          migrator.yieldBuilderMemberFixmePatch(
              usage.cascadedMembers.first, 'custom comment');
        }),
        resolvedContext: sharedContext,
        input: withOverReactImport(/*language=dart*/ '''
            content() {
              // Same line as builder
              (Dom.div()..id = '')();
              
              // Multiline, starts on same line as builder
              (Dom.div()..onClick = (_) {
                print("hi");
              })();
              
              // On separate line
              (Dom.div()
                ..id = ''
                ..title = ''
              )();
            }
        '''),
        expectedOutput: withOverReactImport(/*language=dart*/ '''
            content() {
              // Same line as builder
              (Dom.div()
                // FIXME(generic_migrator) - custom comment
                ..id = ''
              )();
              
              // Multiline, starts on same line as builder
              (Dom.div()
                // FIXME(generic_migrator) - custom comment
                ..onClick = (_) {
                  print("hi");
                }
              )();
              
              // On separate line
              (Dom.div()
                // FIXME(generic_migrator) - custom comment
                ..id = ''
                ..title = ''
              )();
            }
        '''),
      );
    });

    test('for other cascade sections', () async {
      await testSuggestor(
        suggestor: GenericMigrator(migrateUsage: (migrator, usage) {
          migrator.yieldBuilderMemberFixmePatch(
              usage.cascadedMembers.last, 'custom comment');
        }),
        resolvedContext: sharedContext,
        input: withOverReactImport(/*language=dart*/ '''
            content() {
              (Dom.div()
                ..id = ''
                ..title = ''
              )();
            }
        '''),
        expectedOutput: withOverReactImport(/*language=dart*/ '''
            content() {
              (Dom.div()
                ..id = ''
                // FIXME(generic_migrator) - custom comment
                ..title = ''
              )();
            }
        '''),
      );
    });
  });
}

/// The types of fix me comments that can be added to a particular prop.
enum PropFixmeType {
  /// Refers to fix me comments added by [yieldPropFixmePatch].
  custom,

  /// Refers to fix me comments added by [yieldPropManualMigratePatch].
  manuallyMigrate,
}

/// The fix me messages for those prop fixmes that have specific non-custom messages.
const propFixmeMessage = <PropFixmeType, String>{
  PropFixmeType.manuallyMigrate: 'manually migrate',
};

@isTestGroup
void yieldPropFixmePatchTests(
    {PropFixmeType fixmeType = PropFixmeType.custom}) {
  final expectedMessage = propFixmeMessage[fixmeType] ?? 'custom comment';

  group(
      'adds a FIXME comment to a cascaded prop with the prop name and a custom message,'
      ' placing newlines properly so that the comment stays attached to the node after formatting',
      () {
    test('for the first prop', () async {
      await testSuggestor(
        suggestor: GenericMigrator(migrateUsage: (migrator, usage) {
          final prop = usage.cascadedProps.first;
          switch (fixmeType) {
            case PropFixmeType.custom:
              migrator.yieldPropFixmePatch(prop, expectedMessage);
              break;
            case PropFixmeType.manuallyMigrate:
              migrator.yieldPropManualMigratePatch(prop);
              break;
          }
        }),
        resolvedContext: sharedContext,
        input: withOverReactImport(/*language=dart*/ '''
            content() {
              // Same line as builder
              (Dom.div()..id = '')();
              
              // Multiline, starts on same line as builder
              (Dom.div()..onClick = (_) {
                print("hi");
              })();
              
              // On separate line
              (Dom.div()
                ..id = ''
                ..title = ''
              )();
            }
        '''),
        expectedOutput: withOverReactImport('''
            content() {
              // Same line as builder
              (Dom.div()
                // FIXME(generic_migrator) - id prop - $expectedMessage
                ..id = ''
              )();
              
              // Multiline, starts on same line as builder
              (Dom.div()
                // FIXME(generic_migrator) - onClick prop - $expectedMessage
                ..onClick = (_) {
                  print("hi");
                }
              )();
              
              // On separate line
              (Dom.div()
                // FIXME(generic_migrator) - id prop - $expectedMessage
                ..id = ''
                ..title = ''
              )();
            }
        '''),
      );
    });

    test('for other props', () async {
      await testSuggestor(
        suggestor: GenericMigrator(migrateUsage: (migrator, usage) {
          final prop = usage.cascadedProps.last;
          switch (fixmeType) {
            case PropFixmeType.custom:
              migrator.yieldPropFixmePatch(prop, expectedMessage);
              break;
            case PropFixmeType.manuallyMigrate:
              migrator.yieldPropManualMigratePatch(prop);
              break;
          }
        }),
        resolvedContext: sharedContext,
        input: withOverReactImport(/*language=dart*/ '''
            content() {
              (Dom.div()
                ..id = ''
                ..title = ''
              )();
            }
        '''),
        expectedOutput: withOverReactImport('''
            content() {
              (Dom.div()
                ..id = ''
                // FIXME(generic_migrator) - title prop - $expectedMessage
                ..title = ''
              )();
            }
        '''),
      );
    });
  });
}

@isTestGroup
void yieldChildFixmePatchTests() {
  group(
      'adds a FIXME comment to a cascaded member with a custom message,'
      ' placing newlines properly so that the comment stays attached to the node after formatting',
      () {
    test('for the first child', () async {
      await testSuggestor(
        suggestor: GenericMigrator(migrateUsage: (migrator, usage) {
          migrator.yieldChildFixmePatch(usage.children.first, 'custom comment');
        }),
        resolvedContext: sharedContext,
        input: withOverReactImport(/*language=dart*/ '''
            content() {
              // Same line as builder
              Dom.div()('child');
              
              // Same line as builder, non-variadic
              Dom.div()(['child']);
              
              // Multiline, starts on same line as builder
              Dom.div()([].map((child) {
                return child;
              }));
              
              // On separate line
              Dom.div()(
                'child',
              );
              
              // On separate line, non-variadic
              Dom.div()([
                'child',
              ]);
            }
        '''),
        expectedOutput: withOverReactImport(/*language=dart*/ '''
            content() {
              // Same line as builder
              Dom.div()(
                  // FIXME(generic_migrator) - custom comment
                  'child');
              
              // Same line as builder, non-variadic
              Dom.div()([
                // FIXME(generic_migrator) - custom comment
                'child'
              ]);
              
              // Multiline, starts on same line as builder
              Dom.div()(
                  // FIXME(generic_migrator) - custom comment
                  [].map((child) {
                    return child;
                  }));
              
              // On separate line
              Dom.div()(
                // FIXME(generic_migrator) - custom comment
                'child',
              );
              
              // On separate line, non-variadic
              Dom.div()([
                // FIXME(generic_migrator) - custom comment
                'child',
              ]);
            }
        '''),
      );
    });

    test('for other children', () async {
      await testSuggestor(
        suggestor: GenericMigrator(migrateUsage: (migrator, usage) {
          migrator.yieldChildFixmePatch(usage.children.last, 'custom comment');
        }),
        resolvedContext: sharedContext,
        input: withOverReactImport(/*language=dart*/ '''
            content() {
              // Same line as builder
              Dom.div()(1, 2);
              
              // Different lines
              Dom.div()(
                1,
                2,
              );
            }
        '''),
        expectedOutput: withOverReactImport(/*language=dart*/ '''
            content() {
              // Same line as builder
              Dom.div()(
                  1, 
                  // FIXME(generic_migrator) - custom comment
                  2);
              
              // Different lines
              Dom.div()(
                1,
                // FIXME(generic_migrator) - custom comment
                2,
              );
            }
        '''),
      );
    });
  });
}

void yieldRemoveChildPatchTests() {
  test('when it is the only child', () async {
    await testSuggestor(
      suggestor: GenericMigrator(migrateUsage: (migrator, usage) {
        migrator.yieldRemoveChildPatch(usage.children.single.node);
      }),
      resolvedContext: sharedContext,
      input: withOverReactImport(/*language=dart*/ '''
          content() => [
            Dom.div()('single child'),
            Dom.div()(
              'single child with trailing comma',
            ),
            Dom.div()(['single child in list']),
            Dom.div()([
              'single child in list with trailing comma',
            ]),
          ];
      '''),
      expectedOutput: withOverReactImport(/*language=dart*/ '''
          content() => [
            Dom.div()(),
            Dom.div()(),
            Dom.div()([]),
            Dom.div()([]),
          ];
      '''),
    );
  });

  group('when there are multiple children', () {
    test('last child', () async {
      await testSuggestor(
        suggestor: GenericMigrator(migrateUsage: (migrator, usage) {
          migrator.yieldRemoveChildPatch(usage.children.last.node);
        }),
        resolvedContext: sharedContext,
        input: withOverReactImport(/*language=dart*/ '''
            content() => [
              Dom.div()('first child', 'second child'),
              Dom.div()(
                'first child', 
                'second child with trailing comma',
              ),
              Dom.div()(['first child in list', 'second child in list']),
              Dom.div()([
                'first child in list',
                'second child in list with trailing comma',
              ]),
            ];
        '''),
        expectedOutput: withOverReactImport(/*language=dart*/ '''
            content() => [
              Dom.div()('first child'),
              Dom.div()(
                'first child',
              ),
              Dom.div()(['first child in list']),
              Dom.div()([
                'first child in list',
              ]),
            ];
        '''),
      );
    });

    test('first child', () async {
      await testSuggestor(
        suggestor: GenericMigrator(migrateUsage: (migrator, usage) {
          migrator.yieldRemoveChildPatch(usage.children.first.node);
        }),
        resolvedContext: sharedContext,
        input: withOverReactImport(/*language=dart*/ '''
            content() => [
              Dom.div()('first child', 'second child'),
              Dom.div()(
                'first child', 
                'second child with trailing comma',
              ),
              Dom.div()(['first child in list', 'second child in list']),
              Dom.div()([
                'first child in list',
                'second child in list with trailing comma',
              ]),
            ];
        '''),
        expectedOutput: withOverReactImport(/*language=dart*/ '''
            content() => [
              Dom.div()('second child'),
              Dom.div()(
                'second child with trailing comma',
              ),
              Dom.div()(['second child in list']),
              Dom.div()([
                'second child in list with trailing comma',
              ]),
            ];
        '''),
      );
    });
  });
}

void yieldAddChildPatchTests() {
  test('when there are no existing children', () async {
    await testSuggestor(
      suggestor: GenericMigrator(migrateUsage: (migrator, usage) {
        migrator.yieldAddChildPatch(usage, 'Dom.div()(\'A child\')');
      }),
      resolvedContext: sharedContext,
      input: withOverReactImport(/*language=dart*/ '''
          content() => [
            Dom.div()(),
            Dom.div()([]),
          ];
      '''),
      expectedOutput: withOverReactImport(/*language=dart*/ '''
          content() => [
            Dom.div()(
              Dom.div()('A child'),
            ),
            Dom.div()([
              Dom.div()('A child'),
            ]),
          ];
      '''),
    );
  });

  group('when there are multiple children', () {
    test('and a string child is being added', () async {
      await testSuggestor(
        suggestor: GenericMigrator(migrateUsage: (migrator, usage) {
          migrator.yieldAddChildPatch(usage, "'A child'");
        }),
        resolvedContext: sharedContext,
        input: withOverReactImport(/*language=dart*/ '''
            content() => [
              Dom.div()('first child', 'second child'),
              Dom.div()(
                'first child',
                'second child with trailing comma',
              ),
              Dom.div()(['first child in list', 'second child in list']),
              Dom.div()([
                'first child in list',
                'second child in list with trailing comma',
              ]),
            ];
        '''),
        expectedOutput: withOverReactImport(/*language=dart*/ '''
            content() => [
              Dom.div()('A child', 'first child', 'second child'),
              Dom.div()(
              'A child',
                'first child',
                'second child with trailing comma',
              ),
              Dom.div()([ 'A child', 'first child in list', 'second child in list']),
              Dom.div()([
               'A child',
                'first child in list',
                'second child in list with trailing comma',
              ]),
            ];
        '''),
      );
    });

    test('and a basic component usage is being added', () async {
      await testSuggestor(
        suggestor: GenericMigrator(migrateUsage: (migrator, usage) {
          migrator.yieldAddChildPatch(usage, 'Dom.div()(\'A child\')');
        }),
        resolvedContext: sharedContext,
        input: withOverReactImport(/*language=dart*/ '''
            content() => [
              Dom.div()('first child', 'second child'),
              Dom.div()(
                'first child',
                'second child with trailing comma',
              ),
              Dom.div()(['first child in list', 'second child in list']),
              Dom.div()([
                'first child in list',
                'second child in list with trailing comma',
              ]),
            ];
        '''),
        expectedOutput: withOverReactImport(/*language=dart*/ '''
            content() => [
              Dom.div()(Dom.div()('A child'), 'first child', 'second child'),
              Dom.div()(
              Dom.div()('A child'),
                'first child',
                'second child with trailing comma',
              ),
              Dom.div()([Dom.div()('A child'), 'first child in list', 'second child in list']),
              Dom.div()([
              Dom.div()('A child'),
                'first child in list',
                'second child in list with trailing comma',
              ]),
            ];
        '''),
      );
    });

    test('and a complicated component usage is being added', () async {
      await testSuggestor(
        suggestor: GenericMigrator(migrateUsage: (migrator, usage) {
          migrator.yieldAddChildPatch(usage,
              '(Dom.div()..dom.href = content..style = {\'color\': \'blue\'})(\'A child\')');
        }),
        resolvedContext: sharedContext,
        input: withOverReactImport(/*language=dart*/ '''
            content(dynamic content) => [
              Dom.div()('first child', 'second child'),
              Dom.div()(
                'first child',
                'second child with trailing comma',
              ),
              Dom.div()(['first child in list', 'second child in list']),
              Dom.div()([
                'first child in list',
                'second child in list with trailing comma',
              ]),
            ];
        '''),
        expectedOutput: withOverReactImport(/*language=dart*/ '''
            content(dynamic content) => [
              Dom.div()((Dom.div()..dom.href = content..style = {'color': 'blue'})('A child'), 'first child', 'second child'),
              Dom.div()(
              (Dom.div()..dom.href = content..style = {'color': 'blue'})('A child'),
                'first child',
                'second child with trailing comma',
              ),
              Dom.div()([(Dom.div()..dom.href = content..style = {'color': 'blue'})('A child'), 'first child in list', 'second child in list']),
              Dom.div()([
              (Dom.div()..dom.href = content..style = {'color': 'blue'})('A child'),
                'first child in list',
                'second child in list with trailing comma',
              ]),
            ];
        '''),
      );
    });
  });
}

void yieldPropPatchTests() {
  test('throws if neither arguments are specified', () async {
    await sharedContext.getPatches(
      GenericMigrator(migrateUsage: boundExpectAsync2((migrator, usage) {
        expect(
            () => migrator.yieldPropPatch(usage.cascadedProps.first),
            throwsA(isArgumentError
                .havingToStringValue(contains('either newName or newRhs'))));
      })),
      withOverReactImport(/*language=dart*/ '''
          content() => (Dom.div()..id = "some_id" )();
      '''),
    );
  });

  test('inserts content', () async {
    await testSuggestor(
      suggestor: GenericMigrator(migrateUsage: (migrator, usage) {
        final propAt = usage.cascadedProps.elementAt;
        migrator.yieldPropPatch(propAt(0), newName: 'newName0');
        migrator.yieldPropPatch(propAt(1), newRhs: 'newRhs1');
        migrator.yieldPropPatch(propAt(2),
            newName: 'newName2',
            newRhs: 'newRhs2',
            additionalCascadeSection: '..additionalCascade');
      }),
      resolvedContext: sharedContext,
      input: withOverReactImport(/*language=dart*/ '''
          content() => (Dom.div()
            ..id = "some_id"
            ..title = "some_id"
            ..onClick = (_) {}
          )();
      '''),
      expectedOutput: withOverReactImport(/*language=dart*/ '''
          content() => (Dom.div()
            ..newName0 = "some_id"
            ..title = newRhs1
            ..newName2 = newRhs2
            ..additionalCascade
          )();
      '''),
    );
  });
}

typedef OnMigrateUsage = void Function(
    GenericMigrator migrator, FluentComponentUsage usage);
typedef OnShouldMigrateUsage = bool Function(
    GenericMigrator migrator, FluentComponentUsage usage);

class GenericMigrator extends ComponentUsageMigrator {
  final OnMigrateUsage? _onMigrateUsage;
  final OnShouldMigrateUsage? _onShouldMigrateUsage;

  GenericMigrator({
    OnMigrateUsage? migrateUsage,
    OnShouldMigrateUsage? shouldMigrateUsage,
  })  : _onMigrateUsage = migrateUsage,
        _onShouldMigrateUsage = shouldMigrateUsage;

  @override
  bool shouldMigrateUsage(usage) =>
      _onShouldMigrateUsage?.call(this, usage) ?? true;

  @override
  void migrateUsage(usage) {
    super.migrateUsage(usage);
    _onMigrateUsage?.call(this, usage);
  }

  @override
  String get fixmePrefix => 'FIXME(generic_migrator)';
}

const overReactImport = "import 'package:over_react/over_react.dart';";

String withOverReactImport(String source) {
  return '$overReactImport\n$source';
}

String fileWithCascadeOnUsage(String cascade) {
  return withOverReactImport('content() => (Dom.div()\n$cascade\n)())');
}

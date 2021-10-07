import 'package:codemod/codemod.dart';
import 'package:meta/meta.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:over_react_codemod/src/util/component_usage_migrator.dart';
import 'package:test/test.dart';

import '../resolved_file_context.dart';
import '../util.dart';

final sharedContext = SharedAnalysisContext.overReact;

main() {
  group('ComponentUsageMigrator', () {
    group('identifies web_skin_dart component usages', () {});

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
            preResolveFile: false,
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
            return MigrationDecision.notApplicable;
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
      test('only if shouldMigrateUsage returns MigrationDecision.shouldMigrate',
          () async {
        final migrateUsageCalls = <FluentComponentUsage>[];
        await sharedContext.getPatches(
          GenericMigrator(
            migrateUsage: (_, usage) => migrateUsageCalls.add(usage),
            shouldMigrateUsage: (_, usage) {
              switch (usage.builder.toSource()) {
                case 'Dom.div()':
                  return MigrationDecision.notApplicable;
                case 'Dom.span()':
                  return MigrationDecision.shouldMigrate;
                case 'Dom.a()':
                  return MigrationDecision.needsManualIntervention;
              }
              throw ArgumentError('Unexpected builder');
            },
          ),
          withOverReactImport(/*language=dart*/ '''
              usages() => [
                Dom.div()(),
                Dom.span()(),
                Dom.a()(),
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
                  // FIXME(mui_migration) - addProp - manually verify prop key
                  ..addProp('somethingElse', '')
                  // FIXME(mui_migration) - addProp - manually verify prop key
                  ..addProp(somethingElseConst, '')
                  // FIXME(mui_migration) - addProp - manually verify prop key
                  ..addProp(Foo.somethingElseConst, '')
                  // FIXME(mui_migration) - operator[]= - manually verify prop key
                  ..['somethingElse'] = ''
                  // FIXME(mui_migration) - operator[]= - manually verify prop key
                  ..[somethingElseConst] = ''
                  // FIXME(mui_migration) - operator[]= - manually verify prop key
                  ..[Foo.somethingElseConst] = ''
                  // FIXME(mui_migration) - operator[]= - manually verify prop key
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
                  // FIXME(mui_migration) - addProps call - manually verify
                  ..addProps({})
                  // FIXME(mui_migration) - modifyProps call - manually verify
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
                // FIXME(mui_migration) - extensionGetter (extension) - manually verify
                ..extensionGetter
                // FIXME(mui_migration) - extensionSetter (extension) - manually verify
                ..extensionSetter = 'foo'
              )();
              
              $extensionSource
          '''),
        );
      });
    });

    group('migratePropsByName', () {
      test('runs the migrator for each prop with a matching name', () async {
        final suggestor = GenericMigrator(migrateUsage: (migrator, usage) {
          migrator.migratePropsByName(
            usage,
            migratorsByName: {
              'onClick': boundExpectAsync1((p) {
                expect(p.name.name, 'onClick');
              }),
              'href': boundExpectAsync1((p) {
                expect(p.name.name, 'href');
              }),
              'target': boundExpectAsync1((_) {},
                  count: 0,
                  reason: 'should not call props that are not present'),
            },
            catchAll: boundExpectAsync1((p) {
              expect(p.name.name, 'id');
            }),
          );
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
          migrator.migratePropsByName(usage, migratorsByName: {
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

    group('patch yielding utilities', () {
      group('yieldInsertionPatch', () {
        // fixme add tests
      });
      group('yieldPatchOverNode', () {
        // fixme add tests
      });

      group('yieldAddPropPatch', yieldAddPropPatchTests);
      group('yieldRemovePropPatch', yieldRemovePropPatchTests);
      group('yieldPropPatch', yieldPropPatchTests);

      group('yieldPropManualVerificationPatch', () {
        // fixme add tests
      });

      group('yieldPropManualMigratePatch', () {
        // fixme add tests
      });

      group('yieldPropFixmePatch', () {
        // fixme add tests
      });

      group('yieldRemoveChildPatch', yieldRemoveChildPatchTests);
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
    // fixme add tests
    // various test cases
  });

  test('when placement is placement is NewPropPlacement.start', () {
    // fixme add tests
  });

  test('when placement is placement is NewPropPlacement.end', () {
    // fixme add tests
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

Func1<T, A> boundExpectAsync1<T, A>(T Function(A) callback,
        {int count = 1, int max = 0, String? id, String? reason}) =>
    expectAsync1(callback, count: count, max: max, id: id, reason: reason);

Func2<T, A, B> boundExpectAsync2<T, A, B>(T Function(A, B) callback,
        {int count = 1, int max = 0, String? id, String? reason}) =>
    expectAsync2(callback, count: count, max: max, id: id, reason: reason);

extension on TypeMatcher<ArgumentError> {
  Matcher havingMessage(dynamic matcher) =>
      having((e) => e.message, 'message', matcher);
}

Matcher hasPatchText(dynamic matcher) => isA<Patch>().havingText(matcher);

Matcher isMuiMigrationFixmeCommentPatch({String withMessage = ''}) =>
    hasPatchText(matches(
      RegExp(r'// FIXME\(mui_migration\) - .+ - ' + RegExp.escape(withMessage)),
    ));

extension on TypeMatcher<Patch> {
  Matcher havingText(dynamic matcher) =>
      having((p) => p.updatedText, 'updatedText', matcher);
}

extension on TypeMatcher<Object> {
  Matcher havingToStringValue(dynamic matcher) =>
      having((p) => p.toString(), 'toString() value', matcher);
}

typedef OnMigrateUsage = void Function(
    GenericMigrator migrator, FluentComponentUsage usage);
typedef OnShouldMigrateUsage = MigrationDecision Function(
    GenericMigrator migrator, FluentComponentUsage usage);

class GenericMigrator with ClassSuggestor, ComponentUsageMigrator {
  final OnMigrateUsage? _onMigrateUsage;
  final OnShouldMigrateUsage? _onShouldMigrateUsage;

  GenericMigrator({
    OnMigrateUsage? migrateUsage,
    OnShouldMigrateUsage? shouldMigrateUsage,
  })  : _onMigrateUsage = migrateUsage,
        _onShouldMigrateUsage = shouldMigrateUsage;

  @override
  MigrationDecision shouldMigrateUsage(usage) =>
      _onShouldMigrateUsage?.call(this, usage) ??
      MigrationDecision.shouldMigrate;

  @override
  void migrateUsage(usage) {
    super.migrateUsage(usage);
    _onMigrateUsage?.call(this, usage);
  }
}

const overReactImport = "import 'package:over_react/over_react.dart';";

String withOverReactImport(String source) {
  return '$overReactImport\n$source';
}

String fileWithCascadeOnUsage(String cascade) {
  return withOverReactImport('content() => (Dom.div()\n$cascade\n)())');
}

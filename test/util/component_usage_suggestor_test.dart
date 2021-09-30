import 'dart:async';

import 'package:codemod/codemod.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:over_react_codemod/src/util/component_usage_migrator.dart';
import 'package:test/test.dart';

import '../resolved_file_context.dart';
import '../util.dart';

main() {
  group('ComponentUsageMigrator', () {
    late SharedAnalysisContext sharedContext;

    setUpAll(() async {
      sharedContext = SharedAnalysisContext.overReact;
      await sharedContext.init();
    });

    Future<List<Patch>> patchesForCascade(String cascade,
        {String otherContents = ''}) async {
      final source = getTestComponentUsageSourceFile(
          cascade: cascade, otherContents: otherContents);
      final context = await sharedContext.resolvedFileContextForTest(source);
      return await CommonOnlySuggestor()(context).toList();
    }

    group('identifies web_skin_dart component usages', () {});

    test('throws when a file fails to resolve', () async {
      // FIXME a Dart file with parse errors won't satisfy this; need to come up with a different setup or use a mocked context?
      // const unresolvableSource = 'class E extends E {}';
      //
      // final migrator = GenericMigrator();
      // final context =
      //     await sharedContext.resolvedFileContextForTest(unresolvableSource,
      //         // Otherwise, resolvedFileContextForTest will throw.
      //         // We want to see how the migrator handles it.
      //         preResolveFile: false);
      //
      // expect(
      //     () async => await migrator(context).toList(),
      //     throwsA(isA<Exception>()
      //         .havingToStringValue(contains('Could not get resolved unit'))));
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
          final migrator = GenericMigrator(boundExpectAsync2((_, __) {},
              count: 0,
              reason: 'migrator should not be called for any of these usages;'
                  ' it should throw first'));
          await expectLater(
            () async =>
                await sharedContext.getPatches(migrator, 'usage() => $usage;',
                    // Otherwise, resolvedFileContextForTest might throw.
                    // We want to see how the migrator handles it.
                    preResolveFile: false),
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
        const source = '''
        // Dynamic first and second invocation
        dynamic Foo1;
        usage() => Foo1()();
        
        // Static first invocation, dynamic second invocation
        dynamic Foo2() {}
        dynamic builder2;
        usage() => Foo2()();
        usage() => builder2();
        
        // Static first/second invocation, dynamic return value
        dynamic Function() Foo3() {}
        dynamic builder3() {}
        usage() => Foo3()();
        usage() => builder3();
       ''';

        final migrator = GenericMigrator(boundExpectAsync2((_, __) {},
            count: 0, reason: 'these calls should not be detected as usages'));
        // awaiting this is the best way to assert it does not throw, since
        // returnsNormally doesn't work as intended with async functions.
        await sharedContext.getPatches(migrator, source);
      });
    });

    test('calls migrateUsage for each component usage', () async {
      final usages = <FluentComponentUsage>[];
      final suggestor = GenericMigrator((_, usage) {
        usages.add(usage);
      });
      final source = unindent(/*language=dart*/ r'''
          import 'package:over_react/over_react.dart';
            
          UiFactory Foo;
          UiFactory Bar;
          UiProps builder;
          dynamic notAUsage() {}
          dynamic alsoNotAUsage;
                    
          usages() => Foo()(
            (Bar()..baz = 'something')(),
            Dom.div()(),
            builder(),
            notAUsage(),
            alsoNotAUsage,
          );
      ''');
      await sharedContext.getPatches(suggestor, source);

      expect(
          usages.map((u) => u.builder.toSource()),
          unorderedEquals([
            'Foo()',
            'Bar()',
            'Dom.div()',
            'builder',
          ]));
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
            suggestor: GenericMigrator(boundExpectAsync2(
              (_, __) {},
              // This suggestor gets run twice since idempotency is tested.
              count: 2,
              reason: 'should have run on the valid component usage',
            )),
            resolvedContext: sharedContext,
            input: /*language=dart*/ withOverReactImport('''
                contents() => (Dom.div()
                  ..addProp('data-foo', '')
                  ..addProp(dataFooConst, '')
                  ..addProp(Foo.dataFooConst, '')
                  ..['data-foo'] = ''
                  ..[dataFooConst] = ''
                  ..[Foo.dataFooConst] = ''
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
            input: /*language=dart*/ withOverReactImport('''
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
            expectedOutput: /*language=dart*/ withOverReactImport('''
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
            input: /*language=dart*/ withOverReactImport('''
                content() => (Dom.div()
                  ..addProps({})
                  ..modifyProps(modifier)
                  ..addTestId("foo")
                )();
            '''),
            expectedOutput: /*language=dart*/ withOverReactImport('''
                content() => (Dom.div()
                  // FIXME(mui_migration) - addProps call - manually verify
                  ..addProps({})
                  // FIXME(mui_migration) - modifyProps call - manually verify
                  ..modifyProps(modifier)
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
          input: /*language=dart*/ withOverReactImport('''
              content() => (Dom.div()
                ..extensionGetter
                ..extensionSetter = 'foo'
              )();
              
              $extensionSource
          '''),
          expectedOutput: /*language=dart*/ withOverReactImport('''
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
        final suggestor = GenericMigrator((migrator, usage) {
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
        final source = getTestComponentUsageSourceFile(
            cascade: '\n'
                '  ..onClick = (_) {}\n'
                '  ..href = "example.com"\n'
                '  ..id = "foo"\n');
        await sharedContext.getPatches(suggestor, source);
      });

      test('throws when a prop does not exist on the props class', () async {
        final suggestor = GenericMigrator((migrator, usage) {
          migrator.migratePropsByName(usage, migratorsByName: {
            'notARealProp': (_) {},
          });
        });

        final source = getTestComponentUsageSourceFile(cascade: '');
        expect(
            () async => await sharedContext.getPatches(suggestor, source),
            throwsA(isA<ArgumentError>().havingMessage(allOf(
              contains("'migratorsByName' contains unknown prop name"),
              contains("notARealProp"),
            ))));
      });
    });
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

class CommonOnlySuggestor with ClassSuggestor, ComponentUsageMigrator {
  @override
  MigrationDecision shouldMigrateUsage(usage) =>
      MigrationDecision.shouldMigrate;
}

class GenericMigrator with ClassSuggestor, ComponentUsageMigrator {
  @override
  MigrationDecision shouldMigrateUsage(usage) =>
      MigrationDecision.shouldMigrate;

  void Function(GenericMigrator migrator, FluentComponentUsage usage)?
      onMigrateUsage;

  GenericMigrator([this.onMigrateUsage]);

  @override
  migrateUsage(usage) {
    super.migrateUsage(usage);
    onMigrateUsage?.call(this, usage);
  }
}

String getTestComponentUsageSourceFile({
  required String cascade,
  String otherContents = '',
}) =>
    '''
import 'package:over_react/over_react.dart';

render() => ${getTestComponentUsageWithCascade(cascade)};

$otherContents
'''
        .trimRight() +
    '\n';

String getTestComponentUsageWithCascade(String cascade) =>
    '(Dom.div()$cascade)()';

String unindent(String multilineString) {
  var indent = RegExp(r'^( *)').firstMatch(multilineString)![1]!;
  assert(indent.isNotEmpty);
  return multilineString.trim().replaceAll('\n$indent', '\n');
}

const overReactImport = "import 'package:over_react/over_react.dart';";

String withOverReactImport(String source) {
  return '$overReactImport\n$source';
}

String fileWithCascadeOnUsage(String cascade) {
  return withOverReactImport('content() => (Dom.div()\n$cascade\n)())');
}

import 'dart:async';

import 'package:codemod/codemod.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:over_react_codemod/src/util/component_usage_migrator.dart';
import 'package:test/test.dart';

import '../resolved_file_context.dart';

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

    group('common usage flagging', () {
      group('of untyped props:', () {
        final otherContents = unindent('''
          const dataFooConst = 'data-foo';
          const somethingElseConst = 'somethingElse';
          
          class Foo {
            static const dataFooConst = 'data-foo';
            static const somethingElseConst = 'somethingElse';
          }
        ''');

        group('does not flag usages:', () {
          const cascadesToNotFlag = {
            'addProp with data-attribute key (inline)': /*          */ r"..addProp('data-foo', '')",
            'addProp with data-attribute key (const)': /*           */ r"..addProp(dataFooConst, '')",
            'addProp with data-attribute key (class const)': /*     */ r"..addProp(Foo.dataFooConst, '')",
            'operator[]= with data-attribute key (inline)': /*      */ r"..['data-foo'] = ''",
            'operator[]= with data-attribute key (const)': /*       */ r"..[dataFooConst] = ''",
            'operator[]= with data-attribute key (class const)': /* */ r"..[Foo.dataFooConst] = ''",
            'addProp without arguments': /**/ r"..addProp() /* bad call */",
          };

          cascadesToNotFlag.forEach((description, cascade) {
            test(description, () async {
              final patches = await patchesForCascade(cascade,
                  otherContents: otherContents);
              expect(patches, isEmpty);
            });
          });
        });

        group('flags usages:', () {
          const cascadesToFlag = {
            'addProp (inline)': /*         */ r"..addProp('somethingElse', '')",
            'addProp (const)': /*          */ r"..addProp(somethingElseConst, '')",
            'addProp (class const)': /*    */ r"..addProp(Foo.somethingElseConst, '')",
            'operator[]= (inline)': /*     */ r"..['somethingElse'] = ''",
            'operator[]= (const)': /*      */ r"..[somethingElseConst] = ''",
            'operator[]= (class const)': /**/ r"..[Foo.somethingElseConst] = ''",
            'operator[]= (unknown)': /*    */ r"..[condition ? 'data-foo' : 'data-bar'] = ''",
          };

          cascadesToFlag.forEach((description, cascade) {
            test(description, () async {
              final patches = await patchesForCascade(cascade,
                  otherContents: otherContents);
              expect(patches, [
                isMuiMigrationFixmeCommentPatch(
                    withMessage: 'manually verify prop key'),
              ]);
            });
          });
        });
      });

      group('methods:', () {
        test('flags method calls other than addTestId', () async {
          expect(await patchesForCascade('..addProps({})'), [
            isMuiMigrationFixmeCommentPatch(),
          ]);
          expect(await patchesForCascade('..modifyProps(modifier)'), [
            isMuiMigrationFixmeCommentPatch(),
          ]);

          expect(await patchesForCascade('..addTestId("foo")'), isEmpty);
        });
      });

      group('flags static extension', () {
        final extensionSource = ''
            'extension on DomProps {\n'
            '  get extension => null;\n'
            '  set extension(value) {}\n'
            '}';

        test('getters', () async {
          final patches = await patchesForCascade('..extension',
              otherContents: extensionSource);
          expect(patches, [
            isMuiMigrationFixmeCommentPatch(),
          ]);
        });

        test('setters', () async {
          final patches = await patchesForCascade('..extension = "foo"',
              otherContents: extensionSource);
          expect(patches, [
            isMuiMigrationFixmeCommentPatch(),
          ]);
        });
      },
          skip:
              'staticElement on these extension methods seems to be null... perhaps an analyzer bug?');
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

class CommonOnlySuggestor with ClassSuggestor, ComponentUsageMigrator {
  @override
  MigrationDecision shouldMigrateUsage(usage) =>
      MigrationDecision.shouldMigrate;
}

class GenericMigrator with ClassSuggestor, ComponentUsageMigrator {
  @override
  MigrationDecision shouldMigrateUsage(usage) =>
      MigrationDecision.shouldMigrate;

  void Function(GenericMigrator migrator, FluentComponentUsage usage)
      onMigrateUsage;

  GenericMigrator(this.onMigrateUsage);

  @override
  migrateUsage(usage) {
    super.migrateUsage(usage);
    onMigrateUsage(this, usage);
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

import 'package:codemod/codemod.dart';
import 'package:over_react_codemod/src/util/component_usage_migrator.dart';
import 'package:test/test.dart';

import '../resolved_file_context.dart';

main() {
  late SharedAnalysisContext sharedContext;

  setUpAll(() async {
    sharedContext = SharedAnalysisContext.overReact;
    await sharedContext.init();
  });

  group('ComponentUsageMigrator', () {
    group('identifies web_skin_dart component usages', () {
      test('', () async {
        final context = await sharedContext
            .resolvedFileContextForTest(getTestComponentUsageSourceFile(
          cascade: '..addProp("foo", "bar")',
        ));

        final patches = await CommonOnlySuggestor()(context).toList();
        expect(patches, hasLength(1));
      });
    });

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
              final sourceText = getTestComponentUsageSourceFile(
                  cascade: cascade, otherContents: otherContents);
              final patches = await sharedContext.getPatches(
                  CommonOnlySuggestor(), sourceText);
              expect(patches, isEmpty,
                  reason: 'should not suggest any patches');
            });
          });
        });

        group('flags usages:', () {
          final expectedTodoPattern = RegExp(
              r'// FIXME\(mui_migration\) - .+ - manually verify prop key');

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
              final sourceText = getTestComponentUsageSourceFile(
                  cascade: cascade, otherContents: otherContents);
              final patches = await sharedContext.getPatches(
                  CommonOnlySuggestor(), sourceText);
              expect(
                  patches,
                  [
                    hasPatchText(matches(expectedTodoPattern)),
                  ],
                  reason: 'should not suggest any patches');
            });
          });
        });
      });
    });
  });
}

Matcher hasPatchText(dynamic matcher) => isA<Patch>().havingText(matcher);

extension on TypeMatcher<Patch> {
  Matcher havingText(dynamic matcher) =>
      having((p) => p.updatedText, 'updatedText', matcher);
}

class CommonOnlySuggestor with ClassSuggestor, ComponentUsageMigrator {
  @override
  MigrationDecision shouldMigrateUsage(usage) =>
      MigrationDecision.shouldMigrate;
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

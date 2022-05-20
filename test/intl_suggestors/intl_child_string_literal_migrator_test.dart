import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:over_react_codemod/src/intl_suggestors/intl_child_migrator.dart';
import 'package:over_react_codemod/src/intl_suggestors/utils.dart';
import 'package:test/test.dart';

import '../resolved_file_context.dart';
import '../util.dart';

void main() {
  final resolvedContext = SharedAnalysisContext.overReact;

  // Warm up analysis in a setUpAll so that if getting the resolved AST times out
  // (which is more common for the WSD context), it fails here instead of failing the first test.
  setUpAll(resolvedContext.warmUpAnalysis);

  group('IntlChildMigrator', () {
    late File file;
    SuggestorTester? testSuggestor;

    setUp(() async {
      final FileSystem fs = MemoryFileSystem();
      final Directory tmp = await fs.systemTempDirectory.createTemp();
      file = tmp.childFile('TestClassIntl')
        ..createSync(recursive: true);
      testSuggestor = getSuggestorTester(
        IntlChildMigrator('test_namespace', file),
        resolvedContext: resolvedContext,
      );
    });

    tearDown(() {
      file.deleteSync();
    });

    group('StringLiteral', () {
      test('StringLiteral single child', () async {
        await testSuggestor!(
          input: '''
            import 'package:over_react/over_react.dart';

            mixin FooProps on UiProps {}

            UiFactory<FooProps> Foo = uiFunction(
              (props) {

                return (Dom.div())('viewer');
              },
              _\$FooConfig, //ignore: undefined_identifier
            );
            ''',
          expectedOutput: '''
            import 'package:over_react/over_react.dart';

            mixin FooProps on UiProps {}

            UiFactory<FooProps> Foo = uiFunction(
              (props) {

                return (Dom.div())(viewer);
              },
              _\$FooConfig, //ignore: undefined_identifier
            );
            
            String get viewer => Intl.message(
                'viewer', 
                name: 'test_namespace_viewer',
              );
            ''',
        );
        // final expectedFileContent = literalTemplate("test_namespace_viewer", 'viewer', 'viewer');
        // expect(file.readAsStringSync(), expectedFileContent);
      });

      test('StringLiteral two children', () async {
        await testSuggestor!(
          input: '''
            import 'package:over_react/over_react.dart';

            mixin FooProps on UiProps {}

            UiFactory<FooProps> Foo = uiFunction(
              (props) {

                return (Dom.div())(
                  'testString1',
                  'testString2',
                );
              },
              _\$FooConfig, //ignore: undefined_identifier
            );
            ''',
          expectedOutput: '''
            import 'package:over_react/over_react.dart';

            mixin FooProps on UiProps {}

            UiFactory<FooProps> Foo = uiFunction(
              (props) {

                return (Dom.div())(testString1, testString2,);
              },
              _\$FooConfig, //ignore: undefined_identifier
            );
            
            String get testString1 => Intl.message(
                  'testString1',
                  name: 'test_namespace_testString1',
                );
            String get testString2 => Intl.message(
                  'testString2',
                  name: 'test_namespace_testString2',
                );
            ''',
        );
      });

      test('single number string', () async {
        await testSuggestor!(
          input: '''
            import 'package:over_react/over_react.dart';

            mixin FooProps on UiProps {}

            UiFactory<FooProps> Foo = uiFunction(
              (props) {

                return (Dom.div())('12');
              },
              _\$FooConfig, //ignore: undefined_identifier
            );
            ''',
          expectedOutput: '''
            import 'package:over_react/over_react.dart';

            mixin FooProps on UiProps {}

            UiFactory<FooProps> Foo = uiFunction(
              (props) {

                return (Dom.div())('12');
              },
              _\$FooConfig, //ignore: undefined_identifier
            );
            ''',
        );
      });
    });
  });
}
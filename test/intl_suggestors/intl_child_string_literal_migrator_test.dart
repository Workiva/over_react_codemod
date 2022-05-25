import 'package:over_react_codemod/src/intl_suggestors/intl_child_string_literal_migrator.dart';
import 'package:test/test.dart';

import '../resolved_file_context.dart';
import '../util.dart';

void main() {
  final resolvedContext = SharedAnalysisContext.overReact;

  // Warm up analysis in a setUpAll so that if getting the resolved AST times out
  // (which is more common for the WSD context), it fails here instead of failing the first test.
  setUpAll(resolvedContext.warmUpAnalysis);

  group('IntlChildMigrator', () {
    SuggestorTester testSuggestor = getSuggestorTester(
      IntlChildStringLiteralMigrator(),
      resolvedContext: resolvedContext,
    );

    group('StringLiteral', () {
      test('StringLiteral single child', () async {
        await testSuggestor(
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

                return (Dom.div())(
                  Intl.message(
                    'viewer', 
                    name: 'Foo',
                  ),
                );
              },
              _\$FooConfig, //ignore: undefined_identifier
            );
            ''',
        );
      });

      test('StringLiteral two children', () async {
        await testSuggestor(
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

                return (Dom.div())(Intl.message(
                      'testString1',
                      name: 'Foo',
                    ),
                  Intl.message(
                      'testString2',
                      name: 'Foo',
                    ),
                );
              },
              _\$FooConfig, //ignore: undefined_identifier
            );
            ''',
        );
      });

      test('single number string', () async {
        await testSuggestor(
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

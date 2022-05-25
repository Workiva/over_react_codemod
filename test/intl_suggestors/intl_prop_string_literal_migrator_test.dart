// // Copyright 2021 Workiva Inc.
// //
// // Licensed under the Apache License, Version 2.0 (the "License");
// // you may not use this file except in compliance with the License.
// // You may obtain a copy of the License at
// //
// //     http://www.apache.org/licenses/LICENSE-2.0
// //
// // Unless required by applicable law or agreed to in writing, software
// // distributed under the License is distributed on an "AS IS" BASIS,
// // WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// // See the License for the specific language governing permissions and
// // limitations under the License.

import 'package:over_react_codemod/src/intl_suggestors/intl_prop_string_literal_migrator.dart';
import 'package:test/test.dart';

import '../resolved_file_context.dart';
import '../util.dart';

void main() {
  final resolvedContext = SharedAnalysisContext.overReact;

  // Warm up analysis in a setUpAll so that if getting the resolved AST times out
  // (which is more common for the WSD context), it fails here instead of failing the first test.
  setUpAll(resolvedContext.warmUpAnalysis);

  group('IntlPropStringLiteralMigrator', () {
    SuggestorTester testSuggestor = getSuggestorTester(
        IntlPropStringLiteralMigrator(),
        resolvedContext: resolvedContext,
      );

    group('StringLiteral', () {
      test('uiFunction string literal', () async {
        await testSuggestor(
          input: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {}

              UiFactory<FooProps> Foo = uiFunction(
                (props) {
                  return (Dom.div()
                    ..label = 'Test String')();
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
          expectedOutput: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {}

              UiFactory<FooProps> Foo = uiFunction(
                (props) {
                  return (Dom.div()
                    ..label = Intl.message('Test String', name: 'Foo',))();
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );
      });

      test('class string literal', () async {
        await testSuggestor(
          input: '''
               import 'package:over_react/over_react.dart';

               mixin FooProps on UiProps {}

               class Foo extends UiComponent<UiProps> {

                 @override
                 render() {
                   return (Dom.div()
                     ..label = 'Test String')();
                 }
               }
              ''',
          expectedOutput: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {}

              class Foo extends UiComponent<UiProps> {

                 @override
                 render() {
                   return (Dom.div()
                     ..label = Intl.message('Test String', name: 'Foo',))();
                 }
               }
              ''',
        );
      });

      test('uiFunction props => component', () async {
        await testSuggestor(
          input: '''
                import 'package:over_react/over_react.dart';

                mixin FooProps on UiProps {}

                UiFactory<FooProps> Foo = uiFunction(
                  (props) => (Dom.div()
                      ..label = 'Test String')(),
                  _\$FooConfig, //ignore: undefined_identifier
                );
                ''',
          expectedOutput: '''
                import 'package:over_react/over_react.dart';

                mixin FooProps on UiProps {}

                UiFactory<FooProps> Foo = uiFunction(
                  (props) => (Dom.div()
                      ..label = Intl.message('Test String', name: 'Foo',))(),
                  _\$FooConfig, //ignore: undefined_identifier
                );
                ''',
        );
      });
      test('appostrophe in string', () async {
        await testSuggestor(
          input: '''
                import 'package:over_react/over_react.dart';

                mixin FooProps on UiProps {}

                UiFactory<FooProps> Foo = uiFunction(
                  (props) => (Dom.div()
                      ..label = 'Bob\\\'s Test String')(),
                  _\$FooConfig, //ignore: undefined_identifier
                );
                ''',
          expectedOutput: '''
                import 'package:over_react/over_react.dart';

                mixin FooProps on UiProps {}

                UiFactory<FooProps> Foo = uiFunction(
                  (props) => (Dom.div()
                      ..label = Intl.message('Bob\\\'s Test String', name: 'Foo',))(),
                  _\$FooConfig, //ignore: undefined_identifier
                );
                ''',
        );
      });
    });
  });
}

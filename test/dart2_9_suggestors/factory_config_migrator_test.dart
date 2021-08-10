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

import 'package:over_react_codemod/src/dart2_9_suggestors/factory_config_migrator.dart';
import 'package:test/test.dart';

import '../util.dart';

main() {
  group('FactoryConfigMigrator', () {
    final Future<void> Function({String expectedOutput, int expectedPatchCount, String input, bool shouldDartfmtOutput, bool testIdempotency, void Function(String) validateContents}) testSuggestor = getSuggestorTester(FactoryConfigMigrator() as Stream<Patch> Function(FileContext));

    test('empty file', () async {
      await testSuggestor(expectedPatchCount: 0, input: '');
    });

    test('no matches', () async {
      await testSuggestor(
        expectedPatchCount: 0,
        input: '''
          library foo;
          var a = 'b';
          class Foo {}
        ''',
      );
    });

    group('does not update', () {
      test('generated arguments in single argument list', () async {
        await testSuggestor(
          expectedPatchCount: 0,
          input: '''
            UiFactory<FooProps> Foo = someMethod(\$Foo);
          ''',
        );
      });

      test('if already updated', () async {
        await testSuggestor(
          expectedPatchCount: 0,
          input: '''
            UiFactory<FooProps> Foo = uiFunction(
              (props) {},
              _\$FooConfig, // ignore: undefined_identifier
            );
          ''',
        );
      });
    });

    test('with left hand typing', () async {
      await testSuggestor(
        expectedPatchCount: 1,
        input: '''
          UiFactory<BarProps> Bar = uiFunction(
            (props) {},
            \$BarConfig, // ignore: undefined_identifier
          );
        ''',
        expectedOutput: '''
          UiFactory<BarProps> Bar = uiFunction(
            (props) {},
            _\$BarConfig, // ignore: undefined_identifier
          );
        ''',
      );
    });

    test('without left hand typing', () async {
      await testSuggestor(
        expectedPatchCount: 1,
        input: '''
          final Foo = uiForwardRef<FooProps>(
            (props, ref) {},
            \$FooConfig, // ignore: undefined_identifier
          );
        ''',
        expectedOutput: '''
          final Foo = uiForwardRef<FooProps>(
            (props, ref) {},
            _\$FooConfig, // ignore: undefined_identifier
          );
        ''',
      );
    });

    test('when the factory is private', () async {
      await testSuggestor(
        expectedPatchCount: 1,
        input: '''
          UiFactory<FooProps> _Foo = uiFunction(
            (props) {},
            \$_FooConfig, // ignore: undefined_identifier
          );
        ''',
        expectedOutput: '''
          UiFactory<FooProps> _Foo = uiFunction(
            (props) {},
            _\$_FooConfig, // ignore: undefined_identifier
          );
        ''',
      );
    });

    test('without trailing comma', () async {
      await testSuggestor(
        expectedPatchCount: 1,
        input: '''
          UiFactory<BarProps> Bar = uiFunction((props) {}, \$BarConfig); // ignore: undefined_identifier
        ''',
        expectedOutput: '''
          UiFactory<BarProps> Bar = uiFunction((props) {}, _\$BarConfig); // ignore: undefined_identifier
        ''',
      );
    });

    test('when there are multiple factories', () async {
      await testSuggestor(
        expectedPatchCount: 2,
        input: '''
          final Foo = uiForwardRef<FooProps>(
            (props, ref) {},
            \$FooConfig, // ignore: undefined_identifier
          );

          UiFactory<BarProps> Bar = uiFunction(
            (props) {},
            \$BarConfig, // ignore: undefined_identifier
          );
        ''',
        expectedOutput: '''
          final Foo = uiForwardRef<FooProps>(
            (props, ref) {},
            _\$FooConfig, // ignore: undefined_identifier
          );

          UiFactory<BarProps> Bar = uiFunction(
            (props) {},
            _\$BarConfig, // ignore: undefined_identifier
          );
        ''',
      );
    });

    test('when wrapped in an hoc', () async {
      await testSuggestor(
        expectedPatchCount: 1,
        input: '''
          UiFactory<FooProps> Foo = someHOC(uiFunction(
            (props) {},
            \$FooConfig, // ignore: undefined_identifier
          ));
        ''',
        expectedOutput: '''
          UiFactory<FooProps> Foo = someHOC(uiFunction(
            (props) {},
            _\$FooConfig, // ignore: undefined_identifier
          ));
        ''',
      );
    });
  });
}

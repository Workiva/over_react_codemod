import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:over_react_codemod/src/intl_suggestors/intl_child_string_interpolation_migrator.dart';
import 'package:test/test.dart';

import '../resolved_file_context.dart';
import '../util.dart';

void main() {
  final resolvedContext = SharedAnalysisContext.overReact;

  // Warm up analysis in a setUpAll so that if getting the resolved AST times out
  // (which is more common for the WSD context), it fails here instead of failing the first test.
  setUpAll(resolvedContext.warmUpAnalysis);

  group('IntlChildStringInterpolationMigrator', () {
    SuggestorTester testSuggestor = getSuggestorTester(
      IntlChildStringInterpolationMigrator(),
      resolvedContext: resolvedContext,
    );

    group('StringInterpolation', () {
      test('one argument with top level accessor', () async {
        await testSuggestor(
          input: '''
                import 'package:over_react/over_react.dart';

                mixin FooProps on UiProps {}

                UiFactory<FooProps> Foo = uiFunction(
                  (props) {
                    final name = 'bob';

                    return (Dom.div())('Interpolated \${name}');
                  },
                  _\$FooConfig, //ignore: undefined_identifier
                );
                ''',
          expectedOutput: '''
                import 'package:over_react/over_react.dart';

                mixin FooProps on UiProps {}

                UiFactory<FooProps> Foo = uiFunction(
                  (props) {
                    final name = 'bob';

                    return (Dom.div())(
                      tempFunction0(name),
                    );
                  },
                  _\$FooConfig, //ignore: undefined_identifier
                );
                
                String tempFunction0(String name) => Intl.message(
                    'Interpolated \$name',
                    args: [name],
                     name: 'tempFunction0',
                   );
              ''',
        );
      });

      test('two argument with top level accessors', () async {
        await testSuggestor(
          input: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {}

              UiFactory<FooProps> Foo = uiFunction(
                (props) {
                  final name = 'bob';
                  final title = 'Test Title';

                  return (Dom.div())('Interpolated \${name} \$title');
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
          expectedOutput: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {}

              UiFactory<FooProps> Foo = uiFunction(
                (props) {
                  final name = 'bob';
                  final title = 'Test Title';

                  return (Dom.div())(
                    tempFunction0(name, title),
                  );
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              
              String tempFunction0(String name, String title) => Intl.message(
                  'Interpolated \$name \$title',
                  args: [name, title],
                  name: 'tempFunction0',
                );
              ''',
        );
      });

      test('one argument with nested accessor', () async {
        await testSuggestor(
          input: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {
                String name;
              }

              UiFactory<FooProps> Foo = uiFunction(
                (props) {

                  return (Dom.div())('Interpolated \${props.name}');
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
          expectedOutput: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {
                String name;
              }

              UiFactory<FooProps> Foo = uiFunction(
                (props) {

                  return (Dom.div())(
                    tempFunction0(props.name),
                  );
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              
              String tempFunction0(String name) => Intl.message(
                  'Interpolated \$name',
                  args: [name],
                   name: 'tempFunction0',
                 );
              ''',
        );
      });

      test('two arguments with nested accessor', () async {
        await testSuggestor(
          input: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {
                String name;
                String title;
              }

              UiFactory<FooProps> Foo = uiFunction(
                (props) {

                  return (Dom.div())('Interpolated \${props.name} \${props.title}');
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
          expectedOutput: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {
                String name;
                String title;
              }

              UiFactory<FooProps> Foo = uiFunction(
                (props) {

                  return (Dom.div())(
                    tempFunction0(props.name, props.title),
                  );
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              
              String tempFunction0(String name, String title) => Intl.message(
                  'Interpolated \$name \$title',
                  args: [name, title],
                  name: 'tempFunction0',
                );
              ''',
        );
      });

      test('Single interpolated element', () async {
        await testSuggestor(
          input: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {
                String name;
              }

              UiFactory<FooProps> Foo = uiFunction(
                (props) {

                  return (Dom.div())('\${props.name}');
                  
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
          expectedOutput: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {
                String name;
              }

              UiFactory<FooProps> Foo = uiFunction(
                (props) {

                  return (Dom.div())('\${props.name}');
                  
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
        );
      });

      test('Interpolated function call', () async {
        await testSuggestor(
          input: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {}

              UiFactory<FooProps> Foo = uiFunction(
                (props) {

                  String getName() {
                    return 'test name';
                  }
                  
                  return (Dom.div())('His name was \${getName()}');
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
          expectedOutput: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {}

              UiFactory<FooProps> Foo = uiFunction(
                (props) {
                
                  String getName() {
                    return 'test name';
                  }
                  
                  return (Dom.div())(
                    tempFunction0(getName()),
                  );
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              
              String tempFunction0(String getName) => Intl.message(
                  'His name was \$getName',
                  args: [getName],
                  name: 'tempFunction0',
                );
              ''',
        );
      });

      test('Interpolated with apostrophe', () async {
        await testSuggestor(
          input: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {}

              UiFactory<FooProps> Foo = uiFunction(
                (props) {

                  final lastName = 'Paulsen';
                  
                  return (Dom.div())("Bob's last name was \${lastName}");
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
          expectedOutput: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {}

              UiFactory<FooProps> Foo = uiFunction(
                (props) {
                
                  final lastName = 'Paulsen';
                  
                  return (Dom.div())(
                    tempFunction0(lastName),
                  );
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              
              String tempFunction0(String lastName) => Intl.message(
                  'Bob\\\'s last name was \$lastName',
                  args: [lastName],
                  name: 'tempFunction0',
                );
              ''',
        );

      });
      test('Interpolated with testId string', () async {
        await testSuggestor(
          input: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {
                String version;
              }

              UiFactory<FooProps> Foo = uiFunction(
                (props) {

                  return (Dom.p()
                    ..addTestId('truss.aboutWdeskModal.versionInfo')
                  )(
                    'Version \${props.version}',
                  );
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
          expectedOutput: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {
                String version;
              }

              UiFactory<FooProps> Foo = uiFunction(
                (props) {
                                 
                  return (Dom.p() 
                      ..addTestId('truss.aboutWdeskModal.versionInfo')
                    )(
                      versionInfo(props.version),
                    );
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              
              String versionInfo(String version) => Intl.message(
                  'Version \$version',
                  args: [version],
                  name: 'versionInfo',
                );
              ''',
        );
      });

      test('Interpolated with testId', () async {
        await testSuggestor(
          input: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {
                String version;
              }

              abstract class TestClassTestIds {
                static String get versionInfo => 'truss.aboutWdeskModal.versionInfo';
              }
              
              UiFactory<FooProps> Foo = uiFunction(
                (props) {

                  return (Dom.p()
                    ..addTestId(TestClassTestIds.versionInfo)
                  )(  
                    'Version \${props.version}',
                  );
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
          expectedOutput: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {
                String version;
              }

              abstract class TestClassTestIds {
                static String get versionInfo => 'truss.aboutWdeskModal.versionInfo';
              }
              
              UiFactory<FooProps> Foo = uiFunction(
                (props) {
                                 
                  return (Dom.p() 
                    ..addTestId(TestClassTestIds.versionInfo)
                  )(
                    versionInfo(props.version),
                  );
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              
              String versionInfo(String version) => Intl.message(
                  'Version \$version',
                  args: [version],
                  name: 'versionInfo',
                );
              ''',
        );
      });

      test('Interpolated with testId in a parent node', () async {
        await testSuggestor(
          input: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {
                String displayName;
              }

              abstract class TestClassTestIds {
                static String get emptyView => 'truss.aboutWdeskModal.emptyView';
              }
              
              UiFactory<FooProps> Foo = uiFunction(
                (props) {

                return (Dom.div()
                  ..addTestId(TestClassTestIds.emptyView)
                  )(
                    (Dom.p()..addTestId('foo'))(
                      'Create one from any \${props.displayName} by selecting Save As Template',
                    ),
                    (Dom.p()..addTestId('bar'))(
                      (Dom.p())(
                        'Create one from any \${props.displayName} by selecting Save As Template',
                      ),
                    ),
                  );
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              ''',
          expectedOutput: '''
              import 'package:over_react/over_react.dart';

              mixin FooProps on UiProps {
                String displayName;
              }

              abstract class TestClassTestIds {
                static String get emptyView => 'truss.aboutWdeskModal.emptyView';
              }
              
              UiFactory<FooProps> Foo = uiFunction(
                (props) {
                                 
                return (Dom.div()
                  ..addTestId(TestClassTestIds.emptyView)
                  )(
                   (Dom.p()..addTestId('foo'))(
                      foo(props.displayName),
                    ),
                    (Dom.p()..addTestId('bar'))(
                      (Dom.p())(
                        bar(props.displayName),
                      ),
                    ),
                  );
                },
                _\$FooConfig, //ignore: undefined_identifier
              );
              
              String foo(String displayName) => Intl.message(
                  'Create one from any \$displayName by selecting Save As Template',
                  args: [displayName],
                  name: 'foo',
                );
              String bar(String displayName) => Intl.message(
                  'Create one from any \$displayName by selecting Save As Template',
                  args: [displayName],
                  name: 'bar',
                );
              ''',
        );
      });
    });
  });
}
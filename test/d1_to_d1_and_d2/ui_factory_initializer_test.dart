@TestOn('vm')
import 'package:test/test.dart';

import 'package:codemod_over_react/src/d1_to_d1_and_d2/suggestors/ui_factory_initializer.dart';

void main() {
  group('UiFactoryInitializer', () {
    group('getFactoryInitializerValue()', () {
      test('with public factory', () {
        expect(UiFactoryInitializer.getFactoryInitializerValue('Foo'), r'$Foo');
      });

      test('with private factory', () {
        expect(
            UiFactoryInitializer.getFactoryInitializerValue('_Foo'), r'_$Foo');
      });
    });

    group('shouldSkip()', () {
      test('returns false when @Factory() annotation found', () {
        final sourceFileContents = '''library foo;
import 'package:over_react/over_react.dart';
@Factory()
UiFactory<FooProps> Foo;
class FooProps {}''';
        expect(UiFactoryInitializer().shouldSkip(sourceFileContents), isFalse);
      });

      test('returns true when no @Factory() annotation found', () {
        final sourceFileContents = '''library foo;
import 'package:over_react/over_react.dart';
UiFactory<FooProps> Foo;
class FooProps {}''';
        expect(UiFactoryInitializer().shouldSkip(sourceFileContents), isTrue);
      });

      test('returns true when @Factory() annotation is commented out', () {
        final sourceFileContents = '''library foo;
import 'package:over_react/over_react.dart';
// @Factory()
UiFactory<FooProps> Foo;
class FooProps {}''';
        expect(UiFactoryInitializer().shouldSkip(sourceFileContents), isTrue);
      });
    });
  });
}

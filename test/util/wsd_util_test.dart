import 'package:collection/collection.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:over_react_codemod/src/util.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:over_react_codemod/src/util/component_usage_migrator.dart';
import 'package:test/test.dart';

import '../mui_suggestors/components/shared.dart';
import '../resolved_file_context.dart';
import '../util.dart';

void main() {
  group('wsd_util', () {
    final resolvedContext = SharedAnalysisContext.wsd;

    // Warm up analysis in a setUpAll so that if getting the resolved AST times out
    // (which is more common for the WSD context), it fails here instead of failing the first test.
    setUpAll(resolvedContext.warmUpAnalysis);

    Future<Expression> getResolvedExpression(
      String expression, {
      String? imports,
      String otherSource = '',
    }) async {
      imports ??= withOverReactAndWsdImports('');
      return resolvedContext.parseExpression(
        expression,
        imports: imports,
        otherSource: otherSource,
        isResolved: true,
      );
    }

    Future<FluentComponentUsage> parseAndGetSingleUsage(String source) async {
      final context = await resolvedContext
          .resolvedFileContextForTest(withOverReactAndWsdImports(source));
      final result = await context.getResolvedUnit();
      return allDescendantsOfType<InvocationExpression>(result!.unit!)
          .map(getComponentUsage)
          .whereNotNull()
          .single;
    }

    group('isWsdStaticConstant', () {
      group('returns true for matching WSD static constants', () {
        test('', () async {
          final expression = await getResolvedExpression('ButtonSize.DEFAULT');
          expect(isWsdStaticConstant(expression, 'ButtonSize.DEFAULT'), isTrue);
        });

        test('when namespaced', () async {
          final expression =
              await getResolvedExpression('wsd_v2.ButtonSize.DEFAULT');
          expect(isWsdStaticConstant(expression, 'ButtonSize.DEFAULT'), isTrue);
        });
      });

      group('returns false for WSD static constants', () {
        test('that are a different static field', () async {
          final expression = await getResolvedExpression('ButtonSize.DEFAULT');
          expect(isWsdStaticConstant(expression, 'ButtonSize.SMALL'), isFalse);
        });

        test('that are a different class', () async {
          final expression = await getResolvedExpression('ButtonSize.DEFAULT');
          expect(isWsdStaticConstant(expression, 'InputSize.DEFAULT'), isFalse);
        });
      });

      group('returns false for expressions containing WSD static constants',
          () {
        const constant = 'ButtonSize.DEFAULT';

        test('property access on constant', () async {
          final expression = await getResolvedExpression('$constant.className');
          expect(isWsdStaticConstant(expression, constant), isFalse);
        });

        test('method call on constant', () async {
          final expression =
              await getResolvedExpression('$constant.toString()');
          expect(isWsdStaticConstant(expression, constant), isFalse);
        });

        test('cascade on constant', () async {
          final expression =
              await getResolvedExpression('$constant..toString()');
          expect(isWsdStaticConstant(expression, constant), isFalse);
        });

        test('other child expression', () async {
          final expression = await getResolvedExpression(
              'doSomething($constant)',
              otherSource: 'doSomething(dynamic value) {}');
          expect(isWsdStaticConstant(expression, constant), isFalse);
        });
      });

      test('returns false for constants not declared in WSD', () async {
        const constantSource = 'MyClass.staticConstant';
        final expression = await getResolvedExpression(constantSource,
            otherSource: /*language=dart*/ '''
              abstract class MyClass {
                static const staticConstant = null;
              }
          ''');
        expect(isWsdStaticConstant(expression, constantSource), isFalse);
      });

      group('returns false (and does not throw) for non-matching expressions:',
          () {
        test('simple identifier', () async {
          final expression = await getResolvedExpression('identifier',
              otherSource: 'dynamic identifier;');
          expect(
              isWsdStaticConstant(expression, 'ButtonSize.DEFAULT'), isFalse);
        });

        test('prefixed identifier', () async {
          final expression = await getResolvedExpression('identifier.property',
              otherSource: 'dynamic identifier;');
          expect(expression, isA<PrefixedIdentifier>(),
              reason: 'test setup check');
          expect(
              isWsdStaticConstant(expression, 'ButtonSize.DEFAULT'), isFalse);
        });

        test('other property access', () async {
          final expression = await getResolvedExpression(
              'identifier.property.property',
              otherSource: 'dynamic identifier;');
          expect(expression, isA<PropertyAccess>(), reason: 'test setup check');
          expect(
              isWsdStaticConstant(expression, 'ButtonSize.DEFAULT'), isFalse);
        });

        test('other expressions', () async {
          final expression = await getResolvedExpression('1 + 1');
          expect(
              isWsdStaticConstant(expression, 'ButtonSize.DEFAULT'), isFalse);
        });
      });

      test('throws when the provided string is not a prefixed identifier',
          () async {
        final expression = await getResolvedExpression('ButtonSize.DEFAULT');
        final throwsExpectedError = throwsA(isArgumentError.havingToStringValue(
            contains("Expected 'ClassName.constantName'")));

        expect(() {
          isWsdStaticConstant(expression, 'notPrefixed');
        }, throwsExpectedError);
        expect(() {
          isWsdStaticConstant(
              expression, 'prefixed.but not a valid identifier');
        }, throwsExpectedError);
        expect(() {
          isWsdStaticConstant(
              expression, 'prefixed but not a valid.identifier');
        }, throwsExpectedError);
      });
    });

    group('mapWsdConstant', () {
      test(
          'returns the correct value for the WSD constant key matching the given expression',
          () async {
        final expression = await getResolvedExpression('ButtonSize.DEFAULT');
        final mapped = mapWsdConstant(expression, {
          'ButtonSize.SMALL': 'small',
          'ButtonSize.DEFAULT': 'default',
          'ButtonSize.LARGE': 'large',
        });
        expect(mapped, 'default');
      });

      test('returns null if there is no matching value', () async {
        final expression = await getResolvedExpression('ButtonSize.DEFAULT');
        final mapped = mapWsdConstant(expression, {
          'ButtonSize.SMALL': 'small',
          'ButtonSize.LARGE': 'large',
        });
        expect(mapped, isNull);
      });

      test(
          'returns null if the matching value is not a constant declared in WSD',
          () async {
        const constantSource = 'MyClass.staticConstant';
        final expression = await getResolvedExpression(constantSource,
            otherSource: /*language=dart*/ '''
              abstract class MyClass {
                static const staticConstant = null;
              }
          ''');
        final mapped = mapWsdConstant(expression, {
          constantSource: 'mapped',
        });
        expect(mapped, isNull);
      });

      test(
          'returns null if the value is another expression that is not a WSD constant',
          () async {
        final expression = await getResolvedExpression('identifier',
            otherSource: 'dynamic identifier;');
        final mapped = mapWsdConstant(expression, {
          'ButtonSize.SMALL': 'small',
          'ButtonSize.DEFAULT': 'default',
          'ButtonSize.LARGE': 'large',
        });
        expect(mapped, isNull);
      });
    });

    group('usesWsdFactory', () {
      test(
          'returns true for usages of WSD components with matching factory names',
          () async {
        final usage = await parseAndGetSingleUsage(/*language=dart*/ '''
          content() => Button()();
      ''');
        expect(usesWsdFactory(usage, 'Button'), isTrue);
      });

      test(
          'returns true for namespaced usages of WSD components with matching factory names',
          () async {
        final usage = await parseAndGetSingleUsage(/*language=dart*/ '''
          content() => wsd_v2.Button()();
      ''');
        expect(usesWsdFactory(usage, 'Button'), isTrue);
      });

      test(
          'returns true for both v1 and v2 WSD components with matching factory names',
          () async {
        final v1Usage = await parseAndGetSingleUsage(/*language=dart*/ '''
          content() => wsd_v1.Button()();
      ''');
        final v2usage = await parseAndGetSingleUsage(/*language=dart*/ '''
          content() => wsd_v2.Button()();
      ''');
        expect(usesWsdFactory(v1Usage, 'Button'), isTrue);
        expect(usesWsdFactory(v2usage, 'Button'), isTrue);
      });

      group('returns false for builders not directly using the factory', () {
        test('and instead using a factory variable', () async {
          final usage = await parseAndGetSingleUsage(/*language=dart*/ '''
            content(UiFactory<ButtonProps> buttonFactory) => buttonFactory()();
        ''');
          expect(usesWsdFactory(usage, 'Button'), isFalse);
        });

        test('and instead using a builder', () async {
          final usage = await parseAndGetSingleUsage(/*language=dart*/ '''
            content(ButtonProps buttonBuilder) => buttonBuilder();
        ''');
          expect(usesWsdFactory(usage, 'Button'), isFalse);
        });
      });

      test('returns false for WSD components with different names', () async {
        final usage = await parseAndGetSingleUsage(/*language=dart*/ '''
          content() => Button()();
      ''');
        expect(usesWsdFactory(usage, 'Tooltip'), isFalse);
      });

      test('returns false for non-WSD components with matching factory names',
          () async {
        final usage = await parseAndGetSingleUsage(/*language=dart*/ '''
          // Shadows the WSD Button
          UiFactory Button;
          content() => Button()();
      ''');
        expect(usesWsdFactory(usage, 'Button'), isFalse);
      });

      test('throws when the provided string is not a simple identifier',
          () async {
        final usage = await parseAndGetSingleUsage(/*language=dart*/ '''
            content() => Button()();
        ''');
        final throwsExpectedError = throwsA(isArgumentError.havingToStringValue(
            contains('must be a valid, non-namespaced identifier')));

        expect(() {
          usesWsdFactory(usage, 'prefixed.identifier');
        }, throwsExpectedError);
        expect(() {
          usesWsdFactory(usage, 'not a valid identifier');
        }, throwsExpectedError);
      });
    });

    group('usesWsdPropsClass', () {
      test(
          'returns true for usages of WSD components with matching props names',
          () async {
        final usage = await parseAndGetSingleUsage(/*language=dart*/ '''
          content() => Button()();
      ''');
        expect(usesWsdPropsClass(usage, 'ButtonProps'), isTrue);
      });

      test(
          'returns true for namespaced usages of WSD components with matching props names',
          () async {
        final usage = await parseAndGetSingleUsage(/*language=dart*/ '''
          content() => wsd_v2.Button()();
      ''');
        expect(usesWsdPropsClass(usage, 'ButtonProps'), isTrue);
      });

      test(
          'returns true for both v1 and v2 WSD components with matching props names',
          () async {
        final v1Usage = await parseAndGetSingleUsage(/*language=dart*/ '''
          content() => wsd_v1.Button()();
      ''');
        final v2usage = await parseAndGetSingleUsage(/*language=dart*/ '''
          content() => wsd_v2.Button()();
      ''');
        expect(usesWsdPropsClass(v1Usage, 'ButtonProps'), isTrue);
        expect(usesWsdPropsClass(v2usage, 'ButtonProps'), isTrue);
      });

      group('returns true for indirect usages of WSD props classes', () {
        test('via factory variables', () async {
          final usage = await parseAndGetSingleUsage(/*language=dart*/ '''
            content(UiFactory<ButtonProps> buttonFactory) => buttonFactory()();
        ''');
          expect(usesWsdPropsClass(usage, 'ButtonProps'), isTrue);
        });

        test('via builders', () async {
          final usage = await parseAndGetSingleUsage(/*language=dart*/ '''
            content(ButtonProps buttonBuilder) => buttonBuilder();
        ''');
          expect(usesWsdPropsClass(usage, 'ButtonProps'), isTrue);
        });
      });

      test('returns false for WSD components with different props names',
          () async {
        final usage = await parseAndGetSingleUsage(/*language=dart*/ '''
            content() => Button()();
        ''');
        expect(usesWsdPropsClass(usage, 'TooltipProps'), isFalse);
      });

      group(
          'returns false for usages of non-WSD components with matching props names',
          () {
        test('via top-level factories', () async {
          final usage = await parseAndGetSingleUsage(/*language=dart*/ '''
            // Shadows the WSD Button/ButtonProps
            UiFactory<ButtonProps> Button;
            mixin ButtonProps on UiProps {}
            content() => Button()();
        ''');
          expect(usesWsdPropsClass(usage, 'ButtonProps'), isFalse);
        });

        test('via factory variables', () async {
          final usage = await parseAndGetSingleUsage(/*language=dart*/ '''
            // Shadows the WSD ButtonProps
            mixin ButtonProps on UiProps {}
            content(UiFactory<ButtonProps> buttonFactory) => buttonFactory()();
        ''');
          expect(usesWsdPropsClass(usage, 'ButtonProps'), isFalse);
        });

        test('via builders', () async {
          final usage = await parseAndGetSingleUsage(/*language=dart*/ '''
            // Shadows the WSD ButtonProps
            mixin ButtonProps on UiProps {}
            content(ButtonProps buttonBuilder) => buttonBuilder();
        ''');
          expect(usesWsdPropsClass(usage, 'ButtonProps'), isFalse);
        });
      });

      test('throws when the provided string is not a simple identifier',
          () async {
        final usage = await parseAndGetSingleUsage(/*language=dart*/ '''
            content() => Button()();
        ''');
        final throwsExpectedError = throwsA(isArgumentError.havingToStringValue(
            contains('must be a valid, non-namespaced identifier')));

        expect(() {
          usesWsdPropsClass(usage, 'prefixed.identifier');
        }, throwsExpectedError);
        expect(() {
          usesWsdPropsClass(usage, 'not a valid identifier');
        }, throwsExpectedError);
      });
    });

    group('usesWsdToolbarFactory', () {
      test('returns false for non-toolbar WSD v1 components', () async {
        final usage = await parseAndGetSingleUsage(/*language=dart*/ '''
          content() => wsd_v1.Button()();
      ''');
        expect(usesWsdToolbarFactory(usage), isFalse);
      });

      test('returns false for non-toolbar WSD v2 components', () async {
        final usage = await parseAndGetSingleUsage(/*language=dart*/ '''
          content() => wsd_v2.Button()();
      ''');
        expect(usesWsdToolbarFactory(usage), isFalse);
      });

      test('returns false for toolbar WSD v1 components', () async {
        final usage = await parseAndGetSingleUsage(/*language=dart*/ '''
          content() => toolbars_v1.Button()();
      ''');
        expect(usesWsdToolbarFactory(usage), isTrue);
      });

      test('returns false for toolbar WSD v2 components', () async {
        final usage = await parseAndGetSingleUsage(/*language=dart*/ '''
          content() => toolbars_v2.Button()();
      ''');
        expect(usesWsdToolbarFactory(usage), isTrue);
      });

      test('returns false for non-WSD components', () async {
        final usage = await parseAndGetSingleUsage(/*language=dart*/ '''
          UiFactory Foo;
          content() => Foo()();
      ''');
        expect(usesWsdToolbarFactory(usage), isFalse);
      });
    });

    group('wsdComponentVersionForFactory', () {
      test('returns the correct version for non-toolbar WSD v1 components',
          () async {
        final usage = await parseAndGetSingleUsage(/*language=dart*/ '''
          content() => wsd_v1.Button()();
      ''');
        expect(wsdComponentVersionForFactory(usage), WsdComponentVersion.v1);
      });

      test('returns the correct version for non-toolbar WSD v2 components',
          () async {
        final usage = await parseAndGetSingleUsage(/*language=dart*/ '''
          content() => wsd_v2.Button()();
      ''');
        expect(wsdComponentVersionForFactory(usage), WsdComponentVersion.v2);
      });

      test('returns the correct version for toolbar WSD v1 components',
          () async {
        final usage = await parseAndGetSingleUsage(/*language=dart*/ '''
          content() => toolbars_v1.Button()();
      ''');
        expect(wsdComponentVersionForFactory(usage), WsdComponentVersion.v1);
      });

      test('returns the correct version for toolbar WSD v2 components',
          () async {
        final usage = await parseAndGetSingleUsage(/*language=dart*/ '''
          content() => toolbars_v2.Button()();
      ''');
        expect(wsdComponentVersionForFactory(usage), WsdComponentVersion.v2);
      });

      test('returns `notWsd` for non-WSD components', () async {
        final usage = await parseAndGetSingleUsage(/*language=dart*/ '''
          UiFactory Foo;
          content() => Foo()();
      ''');
        expect(
            wsdComponentVersionForFactory(usage), WsdComponentVersion.notWsd);
      });

      group('returns `notResolved` for usages that', () {
        test('have non-factory builders', () async {
          final usage = await parseAndGetSingleUsage(/*language=dart*/ '''
            content(UiProps builder) => builder();
        ''');
          expect(wsdComponentVersionForFactory(usage),
              WsdComponentVersion.notResolved);
        });

        test('use non-top-level factories', () async {
          final usage = await parseAndGetSingleUsage(/*language=dart*/ '''
            content(UiFactory factory) => factory()();
        ''');
          expect(wsdComponentVersionForFactory(usage),
              WsdComponentVersion.notResolved);
        });
      });
    });
  }, tags: 'wsd');
}

import 'package:analyzer/dart/ast/ast.dart';
import 'package:over_react_codemod/src/util/component_usage_migrator.dart';
import 'package:test/test.dart';

import '../mui_suggestors/components/shared.dart';
import '../resolved_file_context.dart';
import '../util.dart';

void main() {
  final resolvedContext = SharedAnalysisContext.wsd;

  // Warm up analysis in a setUpAll so that if getting the resolved AST times out
  // (which is more common for the WSD context), it fails here instead of failing the first test.
  setUpAll(resolvedContext.warmUpAnalysis);

  // Future<T> getResolvedNodeWithSource<T extends AstNode>(String source,
  //     String file) async {
  //   final context = await sharedContext.resolvedFileContextForTest(file);
  //   final unit = (await context.getResolvedUnit())!.unit!;
  //   return allDescendantsOfType<T>(unit).firstWhere((node) =>
  //   node.toSource() == source);
  // }
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

    group('returns false for expressions containing WSD static constants', () {
      const constant = 'ButtonSize.DEFAULT';

      test('property access on constant', () async {
        final expression = await getResolvedExpression('$constant.className');
        expect(isWsdStaticConstant(expression, constant), isFalse);
      });

      test('method call on constant', () async {
        final expression = await getResolvedExpression('$constant.toString()');
        expect(isWsdStaticConstant(expression, constant), isFalse);
      });

      test('cascade on constant', () async {
        final expression = await getResolvedExpression('$constant..toString()');
        expect(isWsdStaticConstant(expression, constant), isFalse);
      });

      test('other child expression', () async {
        final expression = await getResolvedExpression('doSomething($constant)',
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
        expect(isWsdStaticConstant(expression, 'ButtonSize.DEFAULT'), isFalse);
      });

      test('prefixed identifier', () async {
        final expression = await getResolvedExpression('identifier.property',
            otherSource: 'dynamic identifier;');
        expect(expression, isA<PrefixedIdentifier>(),
            reason: 'test setup check');
        expect(isWsdStaticConstant(expression, 'ButtonSize.DEFAULT'), isFalse);
      });

      test('other property access', () async {
        final expression = await getResolvedExpression(
            'identifier.property.property',
            otherSource: 'dynamic identifier;');
        expect(expression, isA<PropertyAccess>(), reason: 'test setup check');
        expect(isWsdStaticConstant(expression, 'ButtonSize.DEFAULT'), isFalse);
      });

      test('other expressions', () async {
        final expression = await getResolvedExpression('1 + 1');
        expect(isWsdStaticConstant(expression, 'ButtonSize.DEFAULT'), isFalse);
      });
    });

    test('throws when the provided string is not a prefixed identifier',
        () async {
      final expression = await getResolvedExpression('ButtonSize.DEFAULT');
      final throwsExpectedError = throwsA(isArgumentError
          .havingToStringValue(contains("Expected 'ClassName.constantName'")));

      expect(() {
        isWsdStaticConstant(expression, 'notPrefixed');
      }, throwsExpectedError);
      expect(() {
        isWsdStaticConstant(expression, 'prefixed.but not a valid identifier');
      }, throwsExpectedError);
      expect(() {
        isWsdStaticConstant(expression, 'prefixed but not a valid.identifier');
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

    test('returns null if the matching value is not a constant declared in WSD',
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
}

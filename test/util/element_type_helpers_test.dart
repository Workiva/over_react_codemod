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

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:over_react_codemod/src/util.dart';
import 'package:over_react_codemod/src/util/element_type_helpers.dart';
import 'package:test/test.dart';

import '../resolved_file_context.dart';

void main() {
  group('isUriWithinPackage', () {
    /// Calls [isUriWithinPackage] with the parsed [uri] and [package].
    ///
    /// Reduces line wrapping in tests for more readable formatting.
    bool getValue(String uri, String package) =>
        isUriWithinPackage(Uri.parse(uri), package);

    test('returns true for package URIs in the same package', () {
      expect(getValue('package:foo/bar.dart', 'foo'), isTrue);
      expect(getValue('package:foo/lib/src/bar.dart', 'foo'), isTrue);
      expect(getValue('package:foo', 'foo'), isTrue);
    });

    test('returns false for package URIs in the same package', () {
      expect(getValue('package:not_foo/bar.dart', 'foo'), isFalse);
      expect(getValue('package:not_foo/lib/src/bar.dart', 'foo'), isFalse);
      expect(getValue('package:not_foo', 'foo'), isFalse);
    });

    test('returns false for package URIs without a package', () {
      expect(getValue('package:', 'foo'), isFalse);
    });

    test('returns false for non-package URIs', () {
      expect(getValue('file:///foo', 'foo'), isFalse);
      expect(getValue('https://foo', 'foo'), isFalse);
      expect(getValue('foo', 'foo'), isFalse);
      expect(getValue('', 'foo'), isFalse);
    });
  });

  group('element type helpers', () {
    final resolvedContext = SharedAnalysisContext.overReact;

    // Warm up analysis in a setUpAll so that if getting the resolved AST times out
    // (which is more common for the WSD context), it fails here instead of failing the first test.
    setUpAll(resolvedContext.warmUpAnalysis);

    Future<CompilationUnit> parseResolvedUnit(String source) async {
      final context = await resolvedContext.resolvedFileContextForTest(source);
      final result = await context.getResolvedUnit();
      return result!.unit!;
    }

    group('type and element helpers', () {
      late CompilationUnit unit;

      /// Returns the type of the variable with name [name] in [unit].
      DartType variableType(String name) {
        final matchedNodes = <AstNode>[];
        late DartType type;

        for (final node in allDescendants(unit)) {
          if (node is VariableDeclaration && node.name.name == name) {
            type = node.declaredElement!.type;
            matchedNodes.add(node);
          } else if (node is FormalParameter && node.identifier?.name == name) {
            type = node.declaredElement!.type;
            matchedNodes.add(node);
          }
        }

        if (matchedNodes.isEmpty) {
          throw StateError("Could not find variable with name '$name'");
        }
        if (matchedNodes.length != 1) {
          throw StateError(
              "Found more than one variables with name '$name': $matchedNodes");
        }
        return type;
      }

      Element variableTypeElement(String name) => variableType(name).element!;

      setUpAll(() async {
        unit = await parseResolvedUnit(/*language=dart*/ '''
            import 'dart:html';
            import 'package:over_react/over_react.dart';
        
            UiProps uiProps;
            ReactElement reactElement;
            Element element;
            
            CustomProps customProps;
            Map map;
            CustomClass customClass;
            dynamic dynamic_;
            
            class CustomClass {}
            
            mixin CustomProps on UiProps {}
            
            foo1<T extends UiProps>(T uiPropsAsBound) {}
            foo2<T extends CustomProps>(T customPropsAsBound) {}
        ''');
      });

      group('isReactElement', () {
        test('returns true for the ReactElement type', () {
          expect(variableType('reactElement').isReactElement, isTrue);
        });

        test('returns false for other types', () {
          expect(variableType('element').isReactElement, isFalse);
          expect(variableType('uiProps').isReactElement, isFalse);
          expect(variableType('map').isReactElement, isFalse);
          expect(variableType('customClass').isReactElement, isFalse);
        });

        test('returns false for dynamic', () {
          expect(variableType('dynamic_').isReactElement, isFalse);
        });
      });

      group('isPropsClass', () {
        test('returns true for the UiProps type', () {
          expect(variableType('uiProps').isPropsClass, isTrue);
        });

        test('returns true for the UiProps subtypes', () {
          expect(variableType('customProps').isPropsClass, isTrue);
        });

        test('returns true for types bounded by UiProps', () {
          expect(variableType('uiProps').isPropsClass, isTrue);
        });

        test('returns true for types bounded by UiProps subtypes', () {
          expect(variableType('customProps').isPropsClass, isTrue);
        });

        test('returns false for other types', () {
          expect(variableType('element').isReactElement, isFalse);
          expect(variableType('map').isReactElement, isFalse);
          expect(variableType('customClass').isReactElement, isFalse);
        });

        test('returns false for dynamic', () {
          expect(variableType('dynamic_').isReactElement, isFalse);
        });
      });

      group('isOrIsSubtypeOfTypeFromPackage', () {
        test('returns true when the type is an exact match', () {
          expect(
              variableType('uiProps')
                  .isOrIsSubtypeOfClassFromPackage('UiProps', 'over_react'),
              isTrue);
        });

        test('returns true when the type is a subtype', () {
          expect(
              variableType('customProps')
                  .isOrIsSubtypeOfClassFromPackage('UiProps', 'over_react'),
              isTrue);
        });

        test('returns true when the type is bounded by that type', () {
          expect(
              variableType('uiPropsAsBound')
                  .isOrIsSubtypeOfClassFromPackage('UiProps', 'over_react'),
              isTrue);
        });

        test('returns true when the type is bounded by a subtype', () {
          expect(
              variableType('customPropsAsBound')
                  .isOrIsSubtypeOfClassFromPackage('UiProps', 'over_react'),
              isTrue);
        });

        test('returns false when the type name does not match', () {
          expect(
              variableType('uiProps')
                  .isOrIsSubtypeOfClassFromPackage('NotUiProps', 'over_react'),
              isFalse);
        });

        test('returns false when the package name does not match', () {
          expect(
              variableType('uiProps')
                  .isOrIsSubtypeOfClassFromPackage('UiProps', 'not_over_react'),
              isFalse);
        });
      });

      group('isElementFromPackage', () {
        test(
            'returns whether a type is declared in package with the given name',
            () async {
          final uiPropsElement = variableTypeElement('uiProps');
          final mapElement = variableTypeElement('map');
          final customClassElement = variableTypeElement('customClass');

          expect(uiPropsElement.isElementFromPackage('UiProps', 'over_react'),
              isTrue);

          expect(
              uiPropsElement.isElementFromPackage('NotUiProps', 'over_react'),
              isFalse);
          expect(
              uiPropsElement.isElementFromPackage('UiProps', 'not_over_react'),
              isFalse);

          expect(mapElement.isElementFromPackage('Map', 'over_react'), isFalse);
          expect(
              customClassElement.isElementFromPackage(
                  'CustomClass', 'over_react'),
              isFalse);
        });
      });

      group('isDeclaredInPackage', () {
        test(
            'returns whether an element is declared in package with the given name',
            () async {
          final uiPropsElement = variableTypeElement('uiProps');
          final mapElement = variableTypeElement('map');
          final customClassElement = variableTypeElement('customClass');

          expect(uiPropsElement.isDeclaredInPackage('over_react'), isTrue);
          expect(uiPropsElement.isDeclaredInPackage('not_over_react'), isFalse);
          expect(mapElement.isDeclaredInPackage('over_react'), isFalse);
          expect(customClassElement.isDeclaredInPackage('over_react'), isFalse);
        });
      });
    });
  });
}

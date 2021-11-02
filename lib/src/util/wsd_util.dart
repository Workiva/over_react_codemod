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
import 'package:collection/collection.dart' as collection;
import 'package:collection/collection.dart';
import 'package:over_react_codemod/src/util/element_type_helpers.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';

/// Takes in a mapping of WSD constant strings and returns the value
/// corresponding to the key whose value `expression` is equivalent to,
/// or `null` if there is no matching value.
///
/// This uses [isWsdStaticConstant] under the hood, and thus supports matching
/// expressions that don't have identical source to the string keys
/// (e.g., differing whitespace, namespaced imports).
///
/// Allows easy mapping of constant values to new values.
///
/// For example:
/// ```dart
/// final expression1 = parseResolvedExpression('wsd.ButtonSize.SMALL');
/// final newValue = mapWsdConstant(expression1, const {
///   'ButtonSize.SMALL': 'newSmall',
///   'ButtonSize.LARGE': 'newLarge',
/// });
/// print(newValue); // prints: newSmall
/// ```
V? mapWsdConstant<V>(
    Expression expression, Map<String, V> wsdConstantToNewValue) {
  return wsdConstantToNewValue.entries
      .where((element) => isWsdStaticConstant(expression, element.key))
      .map((e) => e.value)
      .firstOrNull;
}

/// Returns whether [expression] represents a reference to a static constant
/// declared in web_skin_dart represented by [constant]
/// (of the form `'ClassName.constantName'`).
///
/// Supports matching expressions that don't have identical source to the string
/// keys (e.g., differing whitespace, namespaced imports).
///
/// For example:
/// ```dart
/// final expression1 = parseResolvedExpression('ButtonSize.SMALL');
/// final expression2 = parseResolvedExpression('wsd.ButtonSize.SMALL');
/// print(isWsdStaticConstant(expression1, 'ButtonSize.SMALL')); // true
/// print(isWsdStaticConstant(expression2, 'ButtonSize.SMALL')); // true
/// print(isWsdStaticConstant(expression2, 'ButtonSize.LARGE')); // false
/// ```
bool isWsdStaticConstant(Expression expression, String constant) =>
    _isStaticConstant(expression, constant, fromPackage: 'web_skin_dart');

bool _isStaticConstant(Expression expression, String constant,
    {String? fromPackage}) {
  final constantParts = constant.split('.');
  if (constantParts.length != 2) {
    throw ArgumentError.value(
        constant, 'constant', "Expected 'ClassName.constantName'");
  }
  if (!constantParts.every(_isValidSimpleIdentifier)) {
    throw ArgumentError.value(constant, 'constant',
        "Expected 'ClassName.constantName', where both parts are valid identifiers");
  }

  final className = constantParts[0];
  final staticFieldName = constantParts[1];

  VariableElement? variableElement;
  {
    Element? staticElement;
    if (expression is PropertyAccess && !expression.isCascaded) {
      staticElement = expression.propertyName.staticElement;
    } else if (expression is PrefixedIdentifier) {
      staticElement = expression.identifier.staticElement;
    }
    if (staticElement is VariableElement) {
      variableElement = staticElement;
    } else if (staticElement is PropertyAccessorElement) {
      variableElement = staticElement.variable;
    }
  }
  if (variableElement == null) return false;

  return variableElement.name == staticFieldName &&
      variableElement.enclosingElement?.name == className &&
      variableElement.isStatic &&
      (fromPackage == null || variableElement.isDeclaredInPackage(fromPackage));
}

/// Returns whether [usage] uses a factory that's declared in web_skin_dart
/// and has the name [wsdFactoryName].
///
/// Returns false if [usage] doesn't use a factory, or if its factory isn't
/// statically a top-level variable (e.g., a closure variable, an argument, or a property).
///
/// Supports matching expressions that don't have identical source to the given
/// factory name (e.g., differing whitespace, namespaced imports).
///
/// Example:
/// ```dart
/// usesWsdFactory(parseResolvedUsage('Button()()'), 'Button'); // true
/// usesWsdFactory(parseResolvedUsage('wsd.Button()()'), 'Button'); // true
/// usesWsdFactory(parseResolvedUsage('not_wsd.Button()()'), 'Button'); // false
/// usesWsdFactory(parseResolvedUsage('buttonBuilder()()'), 'Button'); // false
/// ```
bool usesWsdFactory(FluentComponentUsage usage, String wsdFactoryName) {
  if (!_isValidSimpleIdentifier(wsdFactoryName)) {
    throw ArgumentError.value(wsdFactoryName, 'wsdFactoryName',
        'must be a valid, non-namespaced identifier');
  }

  final factoryElement = usage.factoryTopLevelVariableElement;
  if (factoryElement == null) return false;

  return factoryElement.name == wsdFactoryName &&
      factoryElement.isDeclaredInWsd;
}

const _wsdToolbarPathPatterns = {
  '/src/toolbars/',
  '/src/_deprecated/toolbars_v1/',
};

/// Returns whether [usage] uses a factory that's declared in web_skin_dart's
/// toolbar libraries (either v1 or v2).
///
/// Returns false if [usage] doesn't use a factory, or if its factory isn't
/// statically a top-level variable (e.g., a closure variable, an argument, or a property).
///
/// Supports matching expressions that don't have identical source to the given
/// factory name (e.g., differing whitespace, namespaced imports).
///
/// Example:
/// ```dart
/// usesWsdToolbarFactory(parseResolvedUsage('toolbars.Button()()')); // true
/// usesWsdToolbarFactory(parseResolvedUsage('toolbars_v1.Button()()')); // true
/// usesWsdFactory(parseResolvedUsage('non_toolbars_wsd_import.Button()()'), 'Button'); // false
/// ```
bool usesWsdToolbarFactory(FluentComponentUsage usage) {
  final factoryElement = usage.factoryTopLevelVariableElement;
  if (factoryElement == null) return false;

  if (!factoryElement.isDeclaredInWsd) return false;

  // isDeclaredInWsd implies non-null source
  final uri = factoryElement.source!.uri;
  return _wsdToolbarPathPatterns.any(uri.path.contains);
}

final _isValidSimpleIdentifier = RegExp(r'^[_$a-zA-Z][_$a-zA-Z0-9]*$').hasMatch;

/// Returns whether [usage]'s builder's static type is a props class that's
/// declared in web_skin_dart and has the name [wsdPropsName].
///
/// Returns false if [usage]'s static type is not resolved.
///
/// Supports matching expressions that don't have identical source to the given
/// factory name (e.g., differing whitespace, namespaced imports).
///
/// Example:
/// ```dart
/// usesWsdPropsClass(parseResolvedUsage('Button()()'), 'ButtonProps'); // true
/// usesWsdPropsClass(parseResolvedUsage('wsd.Button()()'), 'ButtonProps'); // true
/// usesWsdPropsClass(parseResolvedUsage('buttonBuilder()'), 'ButtonProps'); // true
/// usesWsdPropsClass(parseResolvedUsage('not_wsd.Button()()'), 'ButtonProps'); // false
/// ```
bool usesWsdPropsClass(FluentComponentUsage usage, String wsdPropsName) {
  if (!_isValidSimpleIdentifier(wsdPropsName)) {
    throw ArgumentError.value(wsdPropsName, 'wsdPropsName',
        'must be a valid, non-namespaced identifier');
  }

  final propsClassElement = usage.propsClassElement;
  if (propsClassElement == null) return false;

  return propsClassElement.name == wsdPropsName &&
      propsClassElement.isDeclaredInWsd;
}

enum WsdComponentVersion {
  /// The component is not declared in web_skin_dart.
  notWsd,

  /// The component is declared in web_skin_dart's deprecated "v1" subdirectories
  /// ("Component1"-based components).
  v1,

  /// The component is declared in web_skin_dart's newer "v2" subdirectories
  /// (Component2-based components).
  v2,
}

/// Returns the WSD component version for a given [usage]'s factory.
///
/// Returns `null` if [usage] doesn't use a factory,
/// or if its factory isn't statically a top-level variable
/// (e.g., a closure variable, an argument, or a property).
WsdComponentVersion? wsdComponentVersionForFactory(FluentComponentUsage usage) {
  final factoryElement = usage.factoryTopLevelVariableElement;
  if (factoryElement == null) {
    return null;
  }

  if (!factoryElement.isDeclaredInWsd) {
    return WsdComponentVersion.notWsd;
  }

  // isDeclaredInWsd implies non-null source
  final fileDeclaringFactory = factoryElement.source!.uri;
  return fileDeclaringFactory.path.contains('/src/_deprecated/')
      ? WsdComponentVersion.v1
      : WsdComponentVersion.v2;
}

extension on Element {
  /// Whether an element is declared in the web_skin_dart package.
  bool get isDeclaredInWsd => isDeclaredInPackage('web_skin_dart');
}

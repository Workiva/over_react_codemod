import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:collection/collection.dart' as collection;
import 'package:collection/collection.dart';
import 'package:over_react_codemod/src/element_type_helpers.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';

V? mapWsdConstant<V>(
    Expression expression, Map<String, V> wsdConstantToNewValue) {
  return wsdConstantToNewValue.entries
      .where((element) => isWsdStaticConstant(expression, element.key))
      .map((e) => e.value)
      .firstOrNull;
}

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

  Element? staticElement;
  if (expression is PropertyAccess && !expression.isCascaded) {
    staticElement = expression.propertyName.staticElement;
  } else if (expression is PrefixedIdentifier) {
    staticElement = expression.identifier.staticElement;
  }
  if (staticElement is! ClassMemberElement) return false;

  return staticElement.name == staticFieldName &&
      staticElement.enclosingElement.name == className &&
      staticElement.isStatic &&
      (fromPackage == null || staticElement.isDeclaredInPackage(fromPackage));
}

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

bool usesWsdToolbarFactory(FluentComponentUsage usage) {
  final factoryElement = usage.factoryTopLevelVariableElement;
  if (factoryElement == null) return false;

  if (!factoryElement.isDeclaredInWsd) return false;

  // isDeclaredInWsd implies non-null source
  final uri = factoryElement.source!.uri;
  return _wsdToolbarPathPatterns.any(uri.path.contains);
}

final _isValidSimpleIdentifier = RegExp(r'^[_$a-zA-Z][_$a-zA-Z0-9]*$').hasMatch;

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
  notResolved,
  notWsd,
  v1,
  v2,
}

WsdComponentVersion wsdComponentVersionForFactory(FluentComponentUsage usage) {
  final factoryElement = usage.factoryTopLevelVariableElement;
  if (factoryElement == null) {
    return WsdComponentVersion.notResolved;
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

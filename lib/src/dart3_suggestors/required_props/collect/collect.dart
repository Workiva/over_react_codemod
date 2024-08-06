// Copyright 2024 Workiva Inc.
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

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:over_react_codemod/src/util.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:over_react_codemod/src/vendor/over_react_analyzer_plugin/get_all_props.dart';

import 'collected_data.sg.dart';
import 'logging.dart';
import 'util.dart';

Future<PackageResults> collectDataForUnits(
  Stream<ResolvedUnitResult> units, {
  required String rootPackageName,
  required bool allowOtherPackageUnits,
}) async {
  final logger = Logger('prop_requiredness.$rootPackageName');

  final otherPackagesProcessed = <String>{};
  final packageVersionDescriptionsByName = <String, String>{};
  final allUsages = <Usage>[];
  final allMixinUsagesByMixinId = <String, Set<String>>{};
  final mixinIdsByVisibilityByPackage =
      <String, Map<Visibility, Set<String>>>{};

  await for (final unitResult in units) {
    if (unitResult.uri.path.endsWith('.over_react.g.dart')) continue;
    if (unitResult.libraryElement.isInSdk) continue;

    logProgress();

    //logger.finest('Processing ${unitResult.uri}');

    final unitElement = unitResult.unit.declaredElement;
    if (unitElement == null) {
      logger.warning('Failed to resolve ${unitResult.uri}');
      continue;
    }

    final packageName = getPackageName(unitResult.uri);
    if (packageName == null) {
      throw Exception('Unexpected non-package URI: ${unitResult.uri}');
    }

    if (packageName != rootPackageName) {
      if (!allowOtherPackageUnits) {
        throw StateError(
            'Expected all units to be part of package $rootPackageName,'
            ' but got one from package $packageName: ${unitResult.uri}');
      }
      otherPackagesProcessed.add(packageName);
    }

    allUsages.addAll(collectUsageDataForUnit(
      unitResult: unitResult,
      packageName: packageName,
    ));

    // We'll get redundant results for libraries with multiple compilation units,
    // but it doesn't matter since we're using a set, and it's not worth optimizing.
    if (_isPublicPackageUri(unitResult.uri)) {
      mixinIdsByVisibilityByPackage
          .putIfAbsent(packageName, () => {})
          .putIfAbsent(Visibility.public, () => {})
          // Add exported props classes.
          .addAll(unitResult.libraryElement.exportNamespace.definedNames.values
              .whereType<InterfaceElement>()
              // Note that this is public relative to the library, not necessarily the package.
              .where((element) => element.isPublic)
              // Filter out non-props classes/mixins so we don't collect too much data.
              .where((element) => element.name.contains('Props'))
              .map(uniqueElementId));

      // Add factories that indirectly expose props classes.
      mixinIdsByVisibilityByPackage
          .putIfAbsent(packageName, () => {})
          .putIfAbsent(Visibility.indirectlyPublic, () => {})
          .addAll(unitResult.libraryElement.exportNamespace.definedNames.values
              .whereType<PropertyAccessorElement>()
              .where((element) => element.isGetter)
              // Note that this is public relative to the library, not necessarily the package.
              .where((element) => element.isPublic)
              // Filter out non-props classes/mixins so we don't collect too much data.
              .map((element) {
            final potentialPropsElement = element.returnType.typeOrBound
                .tryCast<FunctionType>()
                ?.returnType
                .element;
            if (potentialPropsElement != null &&
                (potentialPropsElement.name?.contains('Props') ?? false)) {
              return uniqueElementId(potentialPropsElement);
            }
            return null;
          }).whereNotNull());
    }

    _collectMixinUsagesByMixin(unitElement)
        .forEach((usedMixinId, usedByMixinIds) {
      allMixinUsagesByMixinId
          .putIfAbsent(usedMixinId, () => {})
          .addAll(usedByMixinIds);
    });
  }

  return PackageResults(
    packageName: rootPackageName,
    otherPackageNames: otherPackagesProcessed,
    packageVersionDescriptionsByName: packageVersionDescriptionsByName,
    dataVersion: PackageResults.latestDataVersion,
    usages: allUsages,
    mixinIdsByVisibilityByPackage: mixinIdsByVisibilityByPackage,
    allMixinUsagesByMixinId: allMixinUsagesByMixinId,
  );
}

/// Returns [uri] is a package URI with a public (not under src/) path.
bool _isPublicPackageUri(Uri uri) {
  if (!uri.isScheme('package')) return false;
  // First path segment is the package name
  return uri.pathSegments[1] != 'src';
}

List<Usage> collectUsageDataForUnit({
  required ResolvedUnitResult unitResult,
  required String packageName,
}) {
  final logger = Logger('collectUsageData');

  final allUsages = <Usage>[];

  String uniqueNodeId(AstNode node) {
    // Use line/column instead of the raw offset for easier debugging.
    final location = unitResult.lineInfo.getLocation(node.offset);
    return '${unitResult.uri}#$location';
  }

  unitResult.unit.accept(ComponentUsageVisitor((componentUsage) {
    if (componentUsage.isDom) return;

    final usageId = uniqueNodeId(componentUsage.node);

    BuilderType builderType;
    if (componentUsage.factory == null) {
      builderType = BuilderType.otherBuilder;
    } else if (componentUsage.factoryTopLevelVariableElement != null) {
      builderType = BuilderType.topLevelFactory;
    } else {
      builderType = BuilderType.otherFactory;
    }

    final dynamicPropsCategories = componentUsage.cascadedMethodInvocations
        .map<DynamicPropsCategory?>((c) {
          final methodName = c.methodName.name;
          late final arg = c.node.argumentList.arguments.firstOrNull;

          switch (methodName) {
            case 'addUnconsumedProps':
              return DynamicPropsCategory.forwarded;
            case 'addAll':
            case 'addProps':
              if (arg is MethodInvocation &&
                  (arg.methodName.name == 'getPropsToForward' ||
                      arg.methodName.name == 'copyUnconsumedProps')) {
                return DynamicPropsCategory.forwarded;
              }
              return DynamicPropsCategory.other;
            case 'modifyProps':
              if ((arg is MethodInvocation &&
                      arg.methodName.name == 'addPropsToForward') ||
                  (arg is Identifier && arg.name == 'addUnconsumedProps')) {
                return DynamicPropsCategory.forwarded;
              }
              return DynamicPropsCategory.other;
          }

          return null;
        })
        .whereNotNull()
        .toSet();
    final usageHasOtherDynamicProps =
        dynamicPropsCategories.contains(DynamicPropsCategory.other);
    final usageHasForwardedProps =
        dynamicPropsCategories.contains(DynamicPropsCategory.forwarded);

    final builderPropsType = componentUsage
        .builder.staticType?.typeOrBound.element
        ?.tryCast<InterfaceElement>();
    if (builderPropsType == null) {
      logger
          .warning('Could not resolve props; skipping usage. Usage: $usageId');
      return;
    }

    List<UsageMixinData> mixinData;
    {
      final assignedProps =
          componentUsage.cascadedProps.where((p) => !p.isPrefixed).toSet();
      final assignedPropNames = assignedProps.map((p) => p.name.name).toSet();
      final unaccountedForPropNames = {...assignedPropNames};

      // TODO maybe store mixin metadata separately?

      // [1] Use prop mixin elements and not the props, to account for setters that don't show up as prop fields
      //     (e.g., props that do conversion in getter/setter, props that alias other props).
      final allPropMixins =
          getAllPropsClassesOrMixins(builderPropsType).toSet(); // [1]
      mixinData = allPropMixins.map((mixin) {
        // [1]
        final mixinPropsSet = assignedPropNames
            .where((propName) =>
                mixin.getField(propName) != null ||
                mixin.getSetter(propName) != null)
            .toSet();
        unaccountedForPropNames.removeAll(mixinPropsSet);

        final mixinPackage = getPackageName(mixin.librarySource.uri);
        if (mixinPackage == null) {
          throw Exception('Unexpected non-package URI: ${unitResult.uri}');
        }

        return UsageMixinData(
          mixinPackage: mixinPackage,
          mixinId: uniqueElementId(mixin),
          mixinName: mixin.name,
          // Note that for overridden props, they'll show up in multiple mixins
          mixinPropsSet: mixinPropsSet,
        );
      }).toList();

      final unaccountedForProps = assignedProps
          .where((p) => unaccountedForPropNames.contains(p.name.name));
      for (final prop in unaccountedForProps) {
        final propsMixin = prop.staticElement?.enclosingElement;
        if (propsMixin == null) continue;

        if (const {
          'ReactPropsMixin',
          'UbiquitousDomPropsMixin',
          'CssClassPropsMixin'
        }.contains(propsMixin.name)) {
          continue;
        }

        // Edge-case: the deprecated FluxUiProps isn't picked up as a normal props class.
        // We don't care about those for this script, so just bail.
        if (propsMixin.name == 'FluxUiProps') {
          continue;
        }

        logger.warning(
            'Could not find corresponding mixin for prop ${prop.node.toSource()} for $usageId.'
            ' enclosingElement from usage: ${uniqueElementId(propsMixin)},'
            ' allPropsMixins from usage: ${allPropMixins.map(uniqueElementId).toList()}');
      }
    }

    allUsages.add(Usage(
      usageId: usageId,
      usageUri: unitResult.uri.toString(),
      usageDebugInfo: UsageDebugInfo(
        usageBuilderSource: componentUsage.builder.toSource(),
      ),
      usagePackage: packageName,
      usageHasOtherDynamicProps: usageHasOtherDynamicProps,
      usageHasForwardedProps: usageHasForwardedProps,
      usageBuilderType: builderType,
      mixinData: mixinData,
    ));
  }));

  return allUsages;
}

Map<String, List<String>> _collectMixinUsagesByMixin(
    CompilationUnitElement unitElement) {
  final mixinUsagesByMixin = <String, List<String>>{};

  for (final cl in [unitElement.classes, unitElement.mixins].expand((i) => i)) {
    final id = uniqueElementId(cl);
    for (final mixin in getAllPropsClassesOrMixins(cl)) {
      mixinUsagesByMixin.putIfAbsent(uniqueElementId(mixin), () => []).add(id);
    }
  }

  return mixinUsagesByMixin;
}

extension ConditionalFunctionExtension1<R, A extends Object> on R Function(A) {
  R? callIfNotNull(A? arg) => arg == null ? null : this(arg);
}

enum DynamicPropsCategory {
  other,
  forwarded,
}

import 'package:analyzer/dart/element/element.dart';

import 'aggregated_data.sg.dart';

/// A class that can provide recommendations for prop requiredness based on
/// [PropRequirednessResults] data.
class PropRequirednessRecommender {
  final PropRequirednessResults _propRequirednessResults;

  final num privateRequirednessThreshold;
  final num privateMaxAllowedSkipRate;
  final num publicRequirednessThreshold;
  final num publicMaxAllowedSkipRate;

  PropRequirednessRecommender(
    this._propRequirednessResults, {
    required this.privateRequirednessThreshold,
    required this.privateMaxAllowedSkipRate,
    required this.publicRequirednessThreshold,
    required this.publicMaxAllowedSkipRate,
  }) {
    ({
      'privateRequirednessThreshold': privateRequirednessThreshold,
      'privateMaxAllowedSkipRate': privateMaxAllowedSkipRate,
      'publicRequirednessThreshold': publicRequirednessThreshold,
      'publicMaxAllowedSkipRate': publicMaxAllowedSkipRate,
    }).forEach((name, value) {
      _validateWithinRange(value, name: name, min: 0, max: 1);
    });
  }

  PropRecommendation? getRecommendation(FieldElement propField) {
    final propName = propField.name;

    final mixinResults = _getMixinResult(propField.enclosingElement);
    if (mixinResults == null) return null;

    final propResults = mixinResults.propResultsByName[propName];
    if (propResults == null) return null;

    final skipRateReason = _getMixinSkipRateReason(mixinResults);
    if (skipRateReason != null) {
      return PropRecommendation.optional(skipRateReason);
    }

    final totalRequirednessRate = propResults.totalRate;

    final isPublic = mixinResults.visibility.isPublicForUsages;
    final requirednessThreshold =
        isPublic ? publicRequirednessThreshold : privateRequirednessThreshold;

    if (totalRequirednessRate < requirednessThreshold) {
      final reason = RequirednessThresholdOptionalReason();
      return PropRecommendation.optional(reason);
    } else {
      return const PropRecommendation.required();
    }
  }

  MixinResult? _getMixinResult(Element propsElement) {
    final packageName = getPackageName(propsElement.source!.uri);
    final propsId = uniqueElementId(propsElement);
    return _propRequirednessResults.mixinResultsByIdByPackage[packageName]
        ?[propsId];
  }

  SkipRateOptionalReason? _getMixinSkipRateReason(MixinResult mixinResults) {
    final skipRate = mixinResults.usageSkipRate;

    final isPublic = mixinResults.visibility.isPublicForUsages;
    final maxAllowedSkipRate =
        isPublic ? publicMaxAllowedSkipRate : privateMaxAllowedSkipRate;

    return skipRate > maxAllowedSkipRate
        ? SkipRateOptionalReason(
            skipRate: skipRate,
            maxAllowedSkipRate: maxAllowedSkipRate,
            isPublic: isPublic)
        : null;
  }

  SkipRateOptionalReason? getMixinSkipRateReasonForElement(
      Element propsElement) {
    final mixinResults = _getMixinResult(propsElement);
    if (mixinResults == null) return null;

    return _getMixinSkipRateReason(mixinResults);
  }
}

String? getPackageName(Uri uri) {
  if (uri.scheme == 'package') return uri.pathSegments[0];
  return null;
}

String uniqueElementId(Element element) {
  // Use element.location so that we consolidate elements across different contexts
  final location = element.location;
  if (location != null) {
    // Remove duplicate package URI
    final components = {...location.components}.toList();
    // Move the package to the end so that the class shows up first, which is easier to read.
    final pathIndex = components.indexWhere((c) => c.startsWith('package:'));
    final path = pathIndex == -1 ? null : components.removeAt(pathIndex);
    return [components.join(';'), if (path != null) path].join(' - ');
  }

  return 'root:${element.session?.analysisContext.contextRoot},id:${element.id},${element.source?.uri},${element.name}';
}


void _validateWithinRange(num value,
    {required num min, required num max, required String name}) {
  if (value < min || value > max) {
    throw ArgumentError.value(
        value, name, 'must be between $min and $max (inclusive)');
  }
}

extension on Visibility {
  bool get isPublicForUsages {
    switch (this) {
      case Visibility.public:
      case Visibility.indirectlyPublic:
      case Visibility.unknown:
        return true;
      case Visibility.private:
        return false;
    }
  }

  // ignore: unused_element
  bool get isPublicForMixingIn {
    switch (this) {
      case Visibility.public:
      case Visibility.unknown:
        return true;
      case Visibility.indirectlyPublic:
      case Visibility.private:
        return false;
    }
  }
}

class PropRecommendation {
  final bool isRequired;
  final OptionalReason? reason;

  const PropRecommendation.required()
      : isRequired = true,
        reason = null;

  const PropRecommendation.optional(this.reason) : isRequired = false;
}

abstract class OptionalReason {}

class SkipRateOptionalReason extends OptionalReason {
  final num skipRate;
  final num maxAllowedSkipRate;
  final bool isPublic;

  SkipRateOptionalReason({
    required this.skipRate,
    required this.maxAllowedSkipRate,
    required this.isPublic,
  });
}

class RequirednessThresholdOptionalReason extends OptionalReason {
  RequirednessThresholdOptionalReason();
}

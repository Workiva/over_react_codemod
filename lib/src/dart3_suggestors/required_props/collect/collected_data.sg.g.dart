// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: implicit_dynamic_parameter

part of 'collected_data.sg.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PackageResults _$PackageResultsFromJson(Map<String, dynamic> json) =>
    PackageResults(
      dataVersion: json['dataVersion'] as String,
      packageName: json['packageName'] as String,
      otherPackageNames: (json['otherPackageNames'] as List<dynamic>)
          .map((e) => e as String)
          .toSet(),
      packageVersionDescriptionsByName: Map<String, String>.from(
          json['packageVersionDescriptionsByName'] as Map),
      usages: (json['usages'] as List<dynamic>)
          .map((e) => Usage.fromJson(e as Map<String, dynamic>))
          .toList(),
      mixinIdsByVisibilityByPackage:
          (json['mixinIdsByVisibilityByPackage'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(
            k,
            (e as Map<String, dynamic>).map(
              (k, e) => MapEntry($enumDecode(_$VisibilityEnumMap, k),
                  (e as List<dynamic>).map((e) => e as String).toSet()),
            )),
      ),
      stateMixinIdsByVisibilityByPackage:
          (json['stateMixinIdsByVisibilityByPackage'] as Map<String, dynamic>)
              .map(
        (k, e) => MapEntry(
            k,
            (e as Map<String, dynamic>).map(
              (k, e) => MapEntry($enumDecode(_$VisibilityEnumMap, k),
                  (e as List<dynamic>).map((e) => e as String).toSet()),
            )),
      ),
      allMixinUsagesByMixinId:
          (json['allMixinUsagesByMixinId'] as Map<String, dynamic>).map(
        (k, e) =>
            MapEntry(k, (e as List<dynamic>).map((e) => e as String).toSet()),
      ),
    );

Map<String, dynamic> _$PackageResultsToJson(PackageResults instance) =>
    <String, dynamic>{
      'dataVersion': instance.dataVersion,
      'packageName': instance.packageName,
      'otherPackageNames': instance.otherPackageNames.toList(),
      'packageVersionDescriptionsByName':
          instance.packageVersionDescriptionsByName,
      'usages': instance.usages,
      'mixinIdsByVisibilityByPackage': instance.mixinIdsByVisibilityByPackage
          .map((k, e) => MapEntry(k,
              e.map((k, e) => MapEntry(_$VisibilityEnumMap[k]!, e.toList())))),
      'stateMixinIdsByVisibilityByPackage':
          instance.stateMixinIdsByVisibilityByPackage.map((k, e) => MapEntry(k,
              e.map((k, e) => MapEntry(_$VisibilityEnumMap[k]!, e.toList())))),
      'allMixinUsagesByMixinId': instance.allMixinUsagesByMixinId
          .map((k, e) => MapEntry(k, e.toList())),
    };

const _$VisibilityEnumMap = {
  Visibility.public: 'public',
  Visibility.indirectlyPublic: 'indirectlyPublic',
  Visibility.private: 'private',
  Visibility.unknown: 'unknown',
};

Usage _$UsageFromJson(Map<String, dynamic> json) => Usage(
      usageId: json['usageId'] as String,
      usageUri: json['usageUri'] as String,
      usagePackage: json['usagePackage'] as String,
      usageDebugInfo: json['usageDebugInfo'] == null
          ? null
          : UsageDebugInfo.fromJson(
              json['usageDebugInfo'] as Map<String, dynamic>),
      usageHasOtherDynamicProps: json['usageHasOtherDynamicProps'] as bool,
      usageHasForwardedProps: json['usageHasForwardedProps'] as bool,
      usageBuilderType:
          $enumDecode(_$BuilderTypeEnumMap, json['usageBuilderType']),
      mixinData: (json['mixinData'] as List<dynamic>)
          .map((e) => UsageMixinData.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$UsageToJson(Usage instance) => <String, dynamic>{
      'usageId': instance.usageId,
      'usageUri': instance.usageUri,
      'usagePackage': instance.usagePackage,
      'usageDebugInfo': instance.usageDebugInfo,
      'usageHasOtherDynamicProps': instance.usageHasOtherDynamicProps,
      'usageHasForwardedProps': instance.usageHasForwardedProps,
      'usageBuilderType': _$BuilderTypeEnumMap[instance.usageBuilderType]!,
      'mixinData': instance.mixinData,
    };

const _$BuilderTypeEnumMap = {
  BuilderType.topLevelFactory: 'topLevelFactory',
  BuilderType.otherFactory: 'otherFactory',
  BuilderType.otherBuilder: 'otherBuilder',
};

UsageDebugInfo _$UsageDebugInfoFromJson(Map<String, dynamic> json) =>
    UsageDebugInfo(
      usageBuilderSource: json['usageBuilderSource'] as String,
    );

Map<String, dynamic> _$UsageDebugInfoToJson(UsageDebugInfo instance) =>
    <String, dynamic>{
      'usageBuilderSource': instance.usageBuilderSource,
    };

UsageMixinData _$UsageMixinDataFromJson(Map<String, dynamic> json) =>
    UsageMixinData(
      mixinPackage: json['mixinPackage'] as String,
      mixinId: json['mixinId'] as String,
      mixinName: json['mixinName'] as String,
      mixinPropsSet: (json['mixinPropsSet'] as List<dynamic>)
          .map((e) => e as String)
          .toSet(),
    );

Map<String, dynamic> _$UsageMixinDataToJson(UsageMixinData instance) =>
    <String, dynamic>{
      'mixinPackage': instance.mixinPackage,
      'mixinId': instance.mixinId,
      'mixinName': instance.mixinName,
      'mixinPropsSet': instance.mixinPropsSet.toList(),
    };

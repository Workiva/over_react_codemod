// Copyright 2020 Workiva Inc.
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

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:logging/logging.dart';
import 'package:over_react_codemod/src/util.dart';

typedef YieldPatch = void Function(String replacement, int startingOffset,
    [int? endingOffset]);

const semverReportNotAvailable =
    'Semver report not avgit cheailable; this class is assumed to be public and thus will not be updated.';

final logger = Logger('over_react_codemod.boilerplate_upgrade.semver_helper');

/// Returns a [SemverHelper] using the file at [path].
///
/// If the file at [path] does not exist, the returned [SemverHelper] assumes
/// all classes passed to [getPublicExportLocations] are public
/// (see: [SemverHelper.alwaysPublic] constructor).
///
/// If [shouldTreatAllComponentsAsPrivate] is true, the returned [SemverHelper]
/// assumes all classes passed to [getPublicExportLocations] are private
/// (see: [SemverHelper.alwaysPrivate] constructor).
SemverHelper getSemverHelper(String path,
    {bool shouldTreatAllComponentsAsPrivate = false}) {
  if (shouldTreatAllComponentsAsPrivate) {
    return SemverHelper.alwaysPrivate();
  } else {
    final file = File(path);
    if (file.existsSync()) {
      try {
        final jsonReport = jsonDecode(file.readAsStringSync());
        if (jsonReport['exports'] != null) {
          final helper = SemverHelper(jsonReport['exports']);
          logger.info('Successfully loaded semver report');
          return helper;
        }
        // If the map doesn't have exports, duck-type it to see if it's
        // the exports map itself, which can be the case when semver_audit
        // output is piped directly to the console.
        if (jsonReport is Map && jsonReport.values.isNotEmpty) {
          final firstValue = jsonReport.values.first;
          if (firstValue is Map &&
              ['key', 'parent_key'].every(firstValue.containsKey)) {
            final helper = SemverHelper(jsonReport);
            logger.info('Successfully loaded semver report as exports map');
            return helper;
          }
        }
        throw Exception('Could not find exports list in semver_report.json.');
      } catch (e, st) {
        throw Exception('Could not parse semver_report.json.\n$e\n$st');
      }
    }

    const warning = 'Could not find semver_report.json.';
    logger.warning(warning);
    return SemverHelper.alwaysPublic(warning);
  }
}

/// Returns whether or not [node] is publicly exported.
bool isPublic(
  ClassDeclaration node,
  SemverHelper semverHelper,
  String path,
) {
  return semverHelper.getPublicExportLocations(node, path).isNotEmpty;
}

class SemverHelper {
  final Map? _exportList;
  final bool _isAlwaysPrivate;

  /// A warning message if semver report cannot be found.
  String? warning;

  SemverHelper(this._exportList) : _isAlwaysPrivate = false;

  /// Used to ensure [getPublicExportLocations] always returns an empty list,
  /// treating all components as private.
  SemverHelper.alwaysPrivate()
      : _exportList = null,
        _isAlwaysPrivate = true;

  /// Used to ensure [getPublicExportLocations] always returns a non-empty list,
  /// treating all components as public.
  SemverHelper.alwaysPublic(this.warning)
      : _exportList = null,
        _isAlwaysPrivate = false;

  /// Returns a list of locations where [node] is publicly exported.
  ///
  /// If [node] is not publicly exported, returns an empty list.
  List<String> getPublicExportLocations(
    ClassDeclaration node,
    String path,
  ) {
    final className = stripPrivateGeneratedPrefix(node.name.lexeme);

    if (!path.startsWith('lib/')) {
      // The member is not inside of lib/ - so its inherently private.
      return [];
    }

    if (_exportList == null) {
      return _isAlwaysPrivate ? [] : [semverReportNotAvailable];
    }

    final locations = <String>[];
    _exportList!.forEach((key, value) {
      if (value['type'] == 'class' && value['grammar']['name'] == className) {
        locations.add(key);
      }
    });
    return locations;
  }
}

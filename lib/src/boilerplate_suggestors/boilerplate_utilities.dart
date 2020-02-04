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

import 'package:analyzer/dart/ast/ast.dart';

class SemverHelper {
  Map _exportList;

  SemverHelper(Map jsonReport) {
    _exportList = jsonReport['exports'];
  }

  /// Returns semver report information for [node] if it is publicly exported.
  ///
  /// If [node] is not publicly exported, returns `null`.
  Map<String, dynamic> getPublicExportLocations(ClassDeclaration node) {
    final className = node?.name?.name;
    String classKey;

    if (className == null || _exportList == null) return null;

    _exportList.forEach((key, value) {
      if (value['type'] == 'class' && value['grammar']['name'] == className) {
        classKey = key;
      }
    });

    return _exportList[classKey];
  }
}

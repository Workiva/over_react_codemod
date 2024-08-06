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

import 'package:analyzer/dart/element/element.dart';

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

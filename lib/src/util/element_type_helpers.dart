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

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:over_react_codemod/src/util.dart';

extension TypeHelpers on DartType {
  bool get isReactElement =>
      isOrIsSubtypeOfClassFromPackage('ReactElement', 'react');

  bool get isPropsClass =>
      isOrIsSubtypeOfClassFromPackage('UiProps', 'over_react');

  bool isOrIsSubtypeOfClassFromPackage(String typeName, String packageName) {
    final element = typeOrBound.element;
    return element is ClassElement &&
        (element.isElementFromPackage(typeName, packageName) ||
            element.allSupertypes.any((type) =>
                type.element.isElementFromPackage(typeName, packageName)));
  }
}

// Adapted from https://github.com/dart-lang/sdk/blob/279024d823707f1f4d5edc05c374ca813edbd73e/pkg/analysis_server/lib/src/utilities/flutter.dart#L560
//
// Copyright 2014, the Dart project authors. All rights reserved.
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
//
//     * Redistributions of source code must retain the above copyright
//       notice, this list of conditions and the following disclaimer.
//     * Redistributions in binary form must reproduce the above
//       copyright notice, this list of conditions and the following
//       disclaimer in the documentation and/or other materials provided
//       with the distribution.
//     * Neither the name of Google Inc. nor the names of its
//       contributors may be used to endorse or promote products derived
//       from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

extension ElementPackageUtils on Element {
  bool isElementFromPackage(String typeName, String packageName) =>
      name == typeName && isDeclaredInPackage(packageName);

  bool isDeclaredInPackage(String packageName) {
    final uri = source?.uri;
    return uri != null && isUriWithinPackage(uri, packageName);
  }
}

bool isUriWithinPackage(Uri uri, String packageName) =>
    uri.isScheme('package') &&
    uri.pathSegments.isNotEmpty &&
    uri.pathSegments[0] == packageName;

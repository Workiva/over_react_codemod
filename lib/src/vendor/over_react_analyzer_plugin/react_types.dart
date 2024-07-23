import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

extension ReactTypes$DartType on DartType {
  bool get isComponentClass => element?.isComponentClass ?? false;

  bool get isReactElement => element?.isReactElement ?? false;

  bool get isPropsClass => element?.isPropsClass ?? false;

  bool get isRefObject => element?.isRefObject ?? false;
}

extension DartHtmlTypes$DartType on DartType {
  bool get isDartHtmlEvent => element!.isDartHtmlEvent;
}

extension ReactTypes$Element on Element {
  bool get isComponentClass => isOrIsSubtypeOfTypeFromPackage('Component', 'react');

  bool get isReactElement => isOrIsSubtypeOfTypeFromPackage('ReactElement', 'react');

  bool get isPropsClass => isOrIsSubtypeOfTypeFromPackage('UiProps', 'over_react');

  bool get isRefObject => isOrIsSubtypeOfTypeFromPackage('Ref', 'react');
}

extension DartHtmlTypes$Element on Element {
  bool get isDartHtmlEvent => isOrIsSubtypeOfTypeFromPackage('Event', 'html', PackageType.dartCore);
}

// Adapted from https://github.com/dart-lang/sdk/blob/279024d823707f1f4d5edc05c374ca813edbd73e/pkg/analysis_server/lib/src/utilities/flutter.dart#L279
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
extension ElementSubtypeUtils on Element {
  bool isOrIsSubtypeOfTypeFromPackage(String typeName, String packageName,
      [PackageType packageType = PackageType.package]) {
    final that = this;
    return that is InterfaceElement &&
        (that.isTypeFromPackage(typeName, packageName, packageType) ||
            that.allSupertypes
                .any((type) => type.element.isTypeFromPackage(typeName, packageName, packageType)));
  }

  bool isTypeFromPackage(String typeName, String packageName,
      [PackageType packageType = PackageType.package]) =>
      name == typeName && isDeclaredInPackage(packageName, packageType);
}

extension ElementPackageUtils on Element {
  bool isDeclaredInPackage(String packageName, [PackageType packageType = PackageType.package]) =>
      isUriWithinPackage(source!.uri, packageName, packageType);
}

bool isUriWithinPackage(Uri uri, String packageName,
    [PackageType packageType = PackageType.package]) {
  switch (packageType) {
    case PackageType.dartCore:
      return uri.isScheme('dart') &&
          uri.pathSegments.isNotEmpty &&
          uri.pathSegments[0] == packageName;
    case PackageType.package:
      return uri.isScheme('package') &&
          uri.pathSegments.isNotEmpty &&
          uri.pathSegments[0] == packageName;
  }
}

enum PackageType {
  dartCore,
  package,
}

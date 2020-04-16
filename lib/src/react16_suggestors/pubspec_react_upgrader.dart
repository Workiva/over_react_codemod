// Copyright 2019 Workiva Inc.
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

import 'package:over_react_codemod/src/util/pubspec_upgrader.dart';
import 'package:pub_semver/pub_semver.dart';

/// Suggestor that attempts to update `pubspec.yaml` files to ensure a safe
/// minimum bound on the `react` dependency.
///
/// If `react` is already listed, but the minimum bound is not high enough,
/// the version constraint will be updated. If `react` is missing from
/// the file, it will be added.
class PubspecReactUpdater extends PubspecUpgrader {
  PubspecReactUpdater(
    VersionRange targetConstraint, {
    bool shouldAddDependencies = true,
  }) : super(
          'react',
          targetConstraint,
          shouldAddDependencies: shouldAddDependencies,
        );
}

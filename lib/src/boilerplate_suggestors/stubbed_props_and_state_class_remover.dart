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
import 'package:codemod/codemod.dart';
import 'package:over_react_codemod/src/boilerplate_suggestors/boilerplate_utilities.dart';
import 'package:over_react_codemod/src/dart2_suggestors/props_and_state_companion_class_remover.dart';

import '../util.dart';
import 'boilerplate_utilities.dart';

/// Suggestor that removes every companion class for props and state classes, as
/// they were only temporarily required for backwards-compatibility with Dart 1.
class StubbedPropsAndStateClassRemover
    extends PropsAndStateCompanionClassRemover implements Suggestor {
  final SemverHelper semverHelper;

  StubbedPropsAndStateClassRemover(this.semverHelper);

  @override
  bool shouldRemoveCompanionClassFor(ClassDeclaration candidate,
      ClassDeclaration companion, CompilationUnit node) {
    if (shouldAddPublicExportLocationsStubbedClassComment(
        candidate, companion, semverHelper)) {
      addPublicExportLocationsComment(
          companion, sourceFile, semverHelper, yieldPatch);
    }

    return super.shouldRemoveCompanionClassFor(candidate, companion, node) &&
        isAssociatedWithComponent2(candidate) &&
        isAPropsOrStateClass(candidate) &&
        // Do not remove companion class if it is public.
        !isPublic(companion, semverHelper);
  }
}

bool shouldAddPublicExportLocationsStubbedClassComment(
        ClassDeclaration candidate,
        ClassDeclaration companion,
        SemverHelper semverHelper) =>
    isAssociatedWithComponent2(candidate) &&
    isAPropsOrStateClass(candidate) &&
    isPublic(companion, semverHelper);

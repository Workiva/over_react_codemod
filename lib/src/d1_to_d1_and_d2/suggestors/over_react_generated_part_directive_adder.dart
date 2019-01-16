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

import 'package:analyzer/analyzer.dart';
import 'package:codemod/codemod.dart';
import 'package:path/path.dart' as p;

import '../../constants.dart';
import '../../util.dart';
import 'needs_over_react_library_collector.dart';

/// Suggestor that uses the set of libraries that need the over_react generated
/// part directive (collected via [NeedsOverReactLibraryCollector]) and adds the
/// directive to every library that needs it and does not already have it.
class OverReactGeneratedPartDirectiveAdder extends SimpleAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  final NeedsOverReactLibraryCollector _libraryCollector;

  OverReactGeneratedPartDirectiveAdder(this._libraryCollector);

  @override
  visitCompilationUnit(CompilationUnit node) {
    bool needsGeneratedPartDirective = false;

    final canonicalizedPath = p.canonicalize(sourceFile.url.path);
    if (_libraryCollector.byPath.contains(canonicalizedPath)) {
      needsGeneratedPartDirective = true;
    }

    for (final member in node.sortedDirectivesAndDeclarations) {
      if (member is LibraryDirective) {
        if (member.name != null &&
            _libraryCollector.byName.contains(member.name.name)) {
          needsGeneratedPartDirective = true;
          break;
        }
      }
    }

    if (!needsGeneratedPartDirective) {
      return;
    }

    final generatedPartUri = p.setExtension(
      p.basename(sourceFile.url.path),
      overReactGeneratedExtension,
    );
    Directive lastDirective;
    for (final member in node.sortedDirectivesAndDeclarations) {
      if (member is Directive) {
        lastDirective = member;
      }
      if (member is PartDirective) {
        if (member.uri.stringValue == generatedPartUri) {
          return;
        }
      }
    }

    final ignoreComment = buildIgnoreComment(uriHasNotBeenGenerated: true);
    yieldPatch(
      lastDirective.end,
      lastDirective.end,
      "\n$ignoreComment\npart '$generatedPartUri';",
    );
  }
}

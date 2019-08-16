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

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:codemod/codemod.dart';
import 'package:path/path.dart' as p;

import '../util.dart';
import 'generated_part_directive_adder.dart';

/// Suggestor that collects the set of libraries that need an over_react
/// generated part file.
///
/// This suggestor is intended to be used in conjunction with the
/// [GeneratedPartDirectiveAdder]; this collector should run first
/// across the entire set of Dart files in a project and then the directive
/// adder should run second (using [runInteractiveCodemodSequence]).
class NeedsOverReactLibraryCollector extends RecursiveAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  /// Libraries (by name) that need the over_react generated part directive.
  Iterable<String> get byName => List.unmodifiable(_byName);
  final Set<String> _byName = Set<String>();

  /// Libraries (by path) that need the over_react generated part directive.
  Iterable<String> get byPath => List.unmodifiable(_byPath);
  final Set<String> _byPath = Set<String>();

  bool _hasPartOfDirective;

  @override
  visitCompilationUnit(CompilationUnit node) {
    // Reset this flag, as it is specific to each source file/compilation unit.
    _hasPartOfDirective = false;

    // Only collect libraries that need the over_react generated part.
    if (doesNotUseOverReact(sourceFile.getText(0))) {
      return;
    }

    // Recurse here so that the library and part of directives can be visited
    // (if present).
    super.visitCompilationUnit(node);

    // If no `part of` directive was visited, then this file is its own library.
    if (!_hasPartOfDirective) {
      _byPath.add(p.canonicalize(sourceFile.url.path));
    }
  }

  @override
  visitLibraryDirective(LibraryDirective node) {
    _byName.add(node.name.name);
  }

  @override
  visitPartOfDirective(PartOfDirective node) {
    _hasPartOfDirective = true;
    if (node.libraryName != null) {
      _byName.add(node.libraryName.name);
    } else if (node.uri != null) {
      _byPath.add(convertPartOfUriToRelativePath(
          sourceFile.url.path, Uri.parse(node.uri.stringValue)));
    }
  }
}

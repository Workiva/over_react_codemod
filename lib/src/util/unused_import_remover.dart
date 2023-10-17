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

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/syntactic_entity.dart';
import 'package:codemod/codemod.dart';
import 'package:logging/logging.dart';

final _log = Logger('unusedWsdImportRemover');

/// Creates a suggestor that removes unused [package] imports.
Suggestor unusedImportRemoverSuggestorBuilder(String package) {
  return (context) async* {
    final unitResult = await context.getResolvedUnit();
    if (unitResult == null) {
      // Most likely a part and not a library.
      return;
    }
    final unusedImportErrors = unitResult.errors
        .where((error) => error.errorCode.name.toLowerCase() == 'unused_import')
        .toList();

    final allImports =
        unitResult.unit.directives.whereType<ImportDirective>().toList();

    for (final error in unusedImportErrors) {
      final matchingImport = allImports
          .singleWhere((import) => import.containsOffset(error.offset));
      final importUri = matchingImport.uri.stringValue;
      if (importUri != null && importUri.startsWith('package:$package/')) {
        final prevTokenEnd = matchingImport.beginToken.previous?.end;
        // Try to take the newline before the import, but watch out
        // for prevToken's offset/end being -1 if it's this import has the
        // first token in the file.
        final startOffset = prevTokenEnd != null && prevTokenEnd != -1
            ? prevTokenEnd
            : matchingImport.offset;
        yield Patch('', startOffset, matchingImport.end);
      }
    }
  };
}

extension on SyntacticEntity {
  bool containsOffset(int offset) => offset >= this.offset && offset < end;
}

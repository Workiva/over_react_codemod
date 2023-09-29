// Copyright 2023 Workiva Inc.
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
import 'package:analyzer/dart/ast/visitor.dart';

import 'constants.dart';

/// Suggestor that updates imports from [oldPackageName] to [newPackageName].
class ImportRenamer extends RecursiveAstVisitor<void> with AstVisitingSuggestor {
  final String oldPackageName;
  final String newPackageName;

  ImportRenamer({required this.oldPackageName, required this.newPackageName});

  @override
  void visitImportDirective(ImportDirective node) {
    super.visitImportDirective(node);

    final importUri = node.uri.stringValue;
    if (importUri != null && importUri.startsWith('package:$oldPackageName/')) {
      final specialCaseRmuiImport = importsToUpdate.where((import) => importUri == import.rmuiUri);
      if (specialCaseRmuiImport.isNotEmpty) {
        if (specialCaseRmuiImport.single.possibleMuiNamespaces?.contains(node.prefix?.name) ??
            false) {
          // Do nothing if the import prefix is the old RMUI prefix - a new import with a new
          // namespace should have already been added by [importerSuggestorBuilder] in `unify_package_rename.dart`.
          return;
        }
        yieldPatch('\'${specialCaseRmuiImport.single.uri}\'', node.uri.offset, node.uri.end);
      } else {
        yieldPatch(
            '\'${importUri.replaceFirst('package:$oldPackageName/', 'package:$newPackageName/')}\'',
            node.uri.offset,
            node.uri.end);
      }
    }
  }
}

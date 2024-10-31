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

import 'dart:io';

import 'package:args/args.dart';
import 'package:codemod/codemod.dart';
import 'package:over_react_codemod/src/executables/mui_migration.dart';
import 'package:over_react_codemod/src/rmui_bundle_update_suggestors/constants.dart';
import 'package:over_react_codemod/src/rmui_bundle_update_suggestors/dart_script_updater.dart';
import 'package:over_react_codemod/src/rmui_bundle_update_suggestors/html_script_updater.dart';
import 'package:over_react_codemod/src/unify_package_rename_suggestors/import_renamer.dart';
import 'package:over_react_codemod/src/unify_package_rename_suggestors/unify_rename_suggestor.dart';
import 'package:over_react_codemod/src/util.dart';

import '../util/unused_import_remover.dart';

const _changesRequiredOutput = """
  To update your code, run the following commands in your repository:
  dart pub global activate over_react_codemod
  dart pub global run over_react_codemod:unify_package_rename
""";

class CodemodInfo {
  CodemodInfo({required this.paths, required this.sequence});
  Iterable<String> paths;
  Iterable<Suggestor> sequence;
}

void main(List<String> args) async {
  final parser = ArgParser.allowAnything();

  final parsedArgs = parser.parse(args);

  /// Runs a list of codemods one after the other and returns exit code 0 if any fail.
  Future<int> runCodemods(
    Iterable<CodemodInfo> codemods,
  ) async {
    for (final sequence in codemods) {
      final exitCode = await runInteractiveCodemodSequence(
        sequence.paths,
        sequence.sequence,
        defaultYes: true,
        args: parsedArgs.rest,
        additionalHelpOutput: parser.usage,
        changesRequiredOutput: _changesRequiredOutput,
      );
      if (exitCode != 0) return exitCode;
    }

    return 0;
  }

  exitCode = await runCodemods([
    // Update RMUI bundle script in all HTML files (and templates) to Unify bundle.
    CodemodInfo(paths: allHtmlPathsIncludingTemplates(), sequence: [
      HtmlScriptUpdater(rmuiBundleDevUpdated, unifyBundleDev),
      HtmlScriptUpdater(rmuiBundleProdUpdated, unifyBundleProd),
    ]),
    // Update RMUI bundle script in all Dart files to Unify bundle.
    CodemodInfo(paths: allDartPathsExceptHidden(), sequence: [
      DartScriptUpdater(rmuiBundleDevUpdated, unifyBundleDev),
      DartScriptUpdater(rmuiBundleProdUpdated, unifyBundleProd),
    ]),
  ]);

  if (exitCode != 0) return;

  final dartPaths = dartFilesToMigrate().toList();
  // Work around parts being unresolved if you resolve them before their libraries.
  // TODO - reference analyzer issue for this once it's created
  sortPartsLast(dartPaths);

  await pubGetForAllPackageRoots(dartPaths);
  exitCode = await runCodemods([
    // Make main rename updates.
    CodemodInfo(paths: dartPaths, sequence: [UnifyRenameSuggestor()]),
    // Update rmui imports to unify.
    CodemodInfo(paths: dartPaths, sequence: [
      importRenamerSuggestorBuilder(
        oldPackageName: 'react_material_ui',
        newPackageName: 'unify_ui',
      )
    ]),
    // Remove any left over unused imports.
    CodemodInfo(paths: dartPaths, sequence: [
      unusedImportRemoverSuggestorBuilder('react_material_ui'),
      unusedImportRemoverSuggestorBuilder('unify_ui'),
    ]),
  ]);
  if (exitCode != 0) return;
}

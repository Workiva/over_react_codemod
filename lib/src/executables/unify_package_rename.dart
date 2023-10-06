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
import 'package:over_react_codemod/src/ignoreable.dart';
import 'package:over_react_codemod/src/rmui_bundle_update_suggestors/constants.dart';
import 'package:over_react_codemod/src/rmui_bundle_update_suggestors/dart_script_updater.dart';
import 'package:over_react_codemod/src/rmui_bundle_update_suggestors/html_script_updater.dart';
import 'package:over_react_codemod/src/unify_package_rename_suggestors/constants.dart';
import 'package:over_react_codemod/src/unify_package_rename_suggestors/import_renamer.dart';
import 'package:over_react_codemod/src/unify_package_rename_suggestors/namespace_usage_updater.dart';
import 'package:over_react_codemod/src/util.dart';
import 'package:over_react_codemod/src/util/pubspec_upgrader.dart';

import '../unify_package_rename_suggestors/package_rename_component_usage_migrator.dart';
import '../util/importer.dart';
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
    // todo can we also remove rmui dependency here???
    // Add unify_ui dependency.
    CodemodInfo(paths: pubspecYamlPaths(), sequence: [
      aggregate(
        [
          // todo update version:
          PubspecUpgrader('unify_ui', parseVersionRange('^1.89.1'),
              hostedUrl: 'https://pub.workiva.org', shouldAddDependencies: true),
        ].map((s) => ignoreable(s)),
      )
    ]),
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
    // todo add comments
    CodemodInfo(paths: dartPaths, sequence: [NamespaceUsageUpdater()]),
    // CodemodInfo(paths: dartPaths, sequence: [PackageRenameComponentUsageMigrator()]),
    // CodemodInfo(
    //     paths: dartPaths,
    //     sequence: importsToUpdate.where((import) => import.namespace != null).map((import) =>
    //         importerSuggestorBuilder(importUri: import.uri, importNamespace: import.namespace!))),
    // CodemodInfo(
    //     paths: dartPaths,
    //     sequence: [unusedImportRemoverSuggestorBuilder(packageName: 'react_material_ui')]),
    // CodemodInfo(
    //     paths: dartPaths,
    //     sequence: [ImportRenamer(oldPackageName: 'react_material_ui', newPackageName: 'unify_ui')])
  ]);
  if (exitCode != 0) return;
}

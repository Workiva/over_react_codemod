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

import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:args/args.dart';
import 'package:codemod/codemod.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:over_react_codemod/src/intl_suggestors/intl_importer.dart';
import 'package:over_react_codemod/src/intl_suggestors/intl_messages.dart';
import 'package:over_react_codemod/src/intl_suggestors/utils.dart';
import 'package:path/path.dart' as p;

typedef Migrator = Stream<Patch> Function(FileContext);

final FileSystem fs = const LocalFileSystem();

final parser = ArgParser()
  ..addFlag(
    'help',
    abbr: 'h',
    negatable: false,
    help: 'Prints this help output.',
  )
  ..addFlag(
    'verbose',
    abbr: 'v',
    negatable: false,
    help: 'Outputs all logging to stdout/stderr.',
  );

late ArgResults parsedArgs;

void main(List<String> args) async {
  parsedArgs = parser.parse(args);
  if (parsedArgs['help'] as bool) {
    printUsage();
    return;
  }

  if (parsedArgs.rest.isEmpty) {
    print('You have to specify a file');
    exit(1);
  }
  var intlPath = p.canonicalize(p.absolute((parsedArgs.rest.first)));

  await migratePackage(fs.currentDirectory.path, intlPath);
}

void printUsage() {
  stderr.writeln('Migrates a particular string to an intl message.');
  stderr.writeln();
  stderr.writeln('Usage:');
  stderr.writeln('    intl_quick [arguments]');
  stderr.writeln();
  stderr.writeln('Options:');
  stderr.writeln(parser.usage);
}

/// Migrate files included in [paths] within [packagePath].
///
/// We expect [paths] to be absolute.
Future<void> migratePackage(String packagePath, String path) async {
  final packageName = p.basename(packagePath);

  final IntlMessages messages = IntlMessages(packageName,
      directory: fs.currentDirectory, packagePath: packagePath);

  exitCode = await runMigrators([path], [], messages, packageName);

  messages.write(force: false);
  // This will leave the intl.dart file unformatted, but that takes too long, so we'll just leave it out.
}

Future<int> runMigrators(List<String> packageDartPaths,
    List<String> codemodArgs, IntlMessages messages, String packageName) async {
  final constantStringMigrator = SingleStringMigrator(messages, 1, 1);
  final importMigrator = (FileContext context) =>
      intlImporter(context, packageName, messages.className);

  var result = await runInteractiveCodemodSequence(
      packageDartPaths, [constantStringMigrator, importMigrator],
      defaultYes: true);
  return result;
}

class SingleStringMigrator extends GeneralizingAstVisitor
    with AstVisitingSuggestor {
  final IntlMessages _messages;
  int startPosition;
  int endPosition;

  SingleStringMigrator(this._messages, this.startPosition, this.endPosition);

  @override
  visitStringLiteral(StringLiteral node) {
    // Assume this is a single character position and just check if it's within the string for now.
    if (node.offset <= startPosition && node.end >= startPosition) {
      migrateStringExpression(node);
    }
    super.visitStringLiteral(node);
  }

  void migrateStringExpression(StringLiteral node) {
    var stringForm = stringContent(node);
    if (stringForm != null && stringForm.isNotEmpty) {
      final functionCall =
          _messages.syntax.getterCall(node, _messages.className);
      final functionDef =
          _messages.syntax.getterDefinition(node, _messages.className);
      yieldPatch(functionCall, node.offset, node.end);
      addMethodToClass(_messages, functionDef);
    } else {
      if (isValidStringInterpolationNode(node)) {
        var interpolation = node as StringInterpolation;
        final functionCall = _messages.syntax
            .functionCall(interpolation, _messages.className, '');
        final functionDef = _messages.syntax
            .functionDefinition(interpolation, _messages.className, '');
        yieldPatch(functionCall, interpolation.offset, interpolation.end);
        addMethodToClass(_messages, functionDef);
      }
    }
  }
}

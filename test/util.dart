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

import 'dart:io';

import 'package:codemod/codemod.dart';
import 'package:codemod/test.dart';
import 'package:dart_style/dart_style.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'resolved_file_context.dart';

final _patchesPattern = RegExp(r'\(patches (\d+)\)');
final _pathPattern = RegExp(r'\(path ([\w./]+)\)');
final _dartfmtOutputPattern = RegExp(r'\s*@dartfmt_output');
final _idempotentPattern = RegExp(r'\s*@idempotent');

final formatter = DartFormatter();

// This testing approach is similar to what dart_style does for their formatting
// tests since it is pretty much entirely input >> output.
// https://github.com/dart-lang/dart_style/blob/master/test/utils.dart#L55
void testSuggestorsDir(Map<String, Suggestor> suggestorMap, String testDir) {
  final testFiles =
      Directory(testDir).listSync(followLinks: false, recursive: true);
  testFiles.sort((a, b) => a.path.compareTo(b.path));

  for (var testFile in testFiles) {
    if (!testFile.path.endsWith('.suggestor_test')) {
      continue;
    }
    _testSuggestor(suggestorMap, testFile.path);
  }
}

void _testSuggestor(Map<String, Suggestor> suggestorMap, String testFilePath) {
  group(p.basenameWithoutExtension(testFilePath), () {
    final lines = File(testFilePath).readAsLinesSync();

    // First line selects the suggestor to use.
    var suggestorName = lines[0];

    // Let the test specify whether to format expected and actual output
    // before comparing them.
    var dartfmtOutputAll = false;
    suggestorName =
        suggestorName.replaceAllMapped(_dartfmtOutputPattern, (match) {
      dartfmtOutputAll = true;
      return '';
    });

    // Let the test specify whether to test for idempotency by re-running the
    // suggestor on the suggestor's output.
    var testIdempotencyAll = false;
    suggestorName = suggestorName.replaceAllMapped(_idempotentPattern, (match) {
      testIdempotencyAll = true;
      return '';
    });

    final suggestor = suggestorMap[suggestorName];
    if (suggestor == null) {
      throw Exception('Unknown suggestor: $suggestorName');
    }

    var i = 1;

    // Let the test specify some opening comments.
    while (lines[i].startsWith('#')) {
      i++;
    }

    while (i < lines.length) {
      var description = lines[i++].replaceAll('>>>', '');

      // Let the test specify how many patches should be generated.
      int? expectedNumPatches;
      description = description.replaceAllMapped(_patchesPattern, (match) {
        expectedNumPatches = int.parse(match.group(1)!);
        return '';
      });

      // Let the test specify whether to format expected and actual output
      // before comparing them.
      var shouldDartfmtOutput = dartfmtOutputAll;
      description =
          description.replaceAllMapped(_dartfmtOutputPattern, (match) {
        shouldDartfmtOutput = true;
        return '';
      });

      var testIdempotency = testIdempotencyAll;
      description = description.replaceAllMapped(_idempotentPattern, (match) {
        testIdempotency = true;
        return '';
      });

      // Let the test specify a file path, as the suggestor may use it.
      String? path;
      description = description.replaceAllMapped(_pathPattern, (match) {
        path = match.group(1);
        return '';
      });

      description = description.trim();
      description =
          description.isEmpty ? 'line ${i + 1}' : 'line ${i + 1}: $description';

      var input = '';
      while (!lines[i].startsWith('<<<')) {
        input += lines[i++] + '\n';
      }
      if (input.isEmpty) {
        input = '\n';
      }

      var expectedOutput = '';
      while (++i < lines.length && !lines[i].startsWith('>>>')) {
        expectedOutput += lines[i] + '\n';
      }
      // Trim trailing whitespace (except a single newline) as it is not
      // critical to the suggestor outputs and allows for spacing between test
      // cases for better readability.
      input = input.trimRight() + '\n';
      expectedOutput = expectedOutput.trimRight() + '\n';

      test(description, () async {
        await testSuggestor(
          suggestor: suggestor,
          input: input,
          expectedOutput: expectedOutput,
          expectedPatchCount: expectedNumPatches,
          shouldDartfmtOutput: shouldDartfmtOutput,
          testIdempotency: testIdempotency,
          inputUrl: path,
        );
      });
    }
  });
}

typedef SuggestorTester = Future<void> Function({
  required String input,
  String? expectedOutput,
  int? expectedPatchCount,
  bool shouldDartfmtOutput,
  bool testIdempotency,
  SharedAnalysisContext? resolvedContext,
  IsExpectedError? isExpectedError,
  void Function(String contents)? validateContents,
});

const defaultSuggestorTesterInputUrl = 'lib/src/input';

/// Returns a version of [testSuggestor] with [suggestor] curried.
SuggestorTester getSuggestorTester(
  Suggestor suggestor, {
  String? inputUrl,
  SharedAnalysisContext? resolvedContext,
}) {
  final defaultResolvedContext = resolvedContext;
  return ({
    required String input,
    String? expectedOutput,
    int? expectedPatchCount,
    bool shouldDartfmtOutput = true,
    bool testIdempotency = true,
    SharedAnalysisContext? resolvedContext,
    IsExpectedError? isExpectedError,
    void Function(String contents)? validateContents,
  }) =>
      testSuggestor(
        suggestor: suggestor,
        input: input,
        expectedOutput: expectedOutput,
        expectedPatchCount: expectedPatchCount,
        shouldDartfmtOutput: shouldDartfmtOutput,
        testIdempotency: testIdempotency,
        resolvedContext: resolvedContext ?? defaultResolvedContext,
        isExpectedError: isExpectedError,
        validateContents: validateContents,
        inputUrl: inputUrl,
      );
}

String _formatWithBetterFailureOutput(String input, {required String uri}) {
  try {
    return formatter.format(input, uri: uri);
  } catch (_) {
    print('Contents that failed to format ($uri):\n---------------\n$input');
    rethrow;
  }
}

Future<void> testSuggestor({
  required Suggestor suggestor,
  required String input,
  String? expectedOutput,
  int? expectedPatchCount,
  bool shouldDartfmtOutput = true,
  bool testIdempotency = true,
  SharedAnalysisContext? resolvedContext,
  IsExpectedError? isExpectedError,
  void Function(String contents)? validateContents,
  String? inputUrl,
}) async {
  inputUrl ??=
      resolvedContext?.nextFilename() ?? defaultSuggestorTesterInputUrl;
  expectedOutput ??= input;

  if (isExpectedError != null && resolvedContext == null) {
    throw ArgumentError(
        'resolvedContext must be non-null to specify isExpectedError');
  }

  Future<FileContext> getFileContext({
    required String contents,
    required String path,
  }) =>
      resolvedContext != null
          ? resolvedContext.resolvedFileContextForTest(contents,
              filename: path,
              includeTestDescription: false,
              isExpectedError: isExpectedError)
          : fileContextForTest(path, contents);

  if (validateContents != null) {
    expect(() => validateContents(input), returnsNormally,
        reason: 'input is invalid');
  }

  if (shouldDartfmtOutput) {
    expectedOutput =
        _formatWithBetterFailureOutput(expectedOutput, uri: 'expectedOutput');
  }

  String modifiedInput;
  {
    final context = await getFileContext(contents: input, path: inputUrl);
    final patches = await suggestor(context).toList();
    if (expectedPatchCount != null && patches.length != expectedPatchCount) {
      fail('Incorrect number of patches generated '
          '(expected: $expectedPatchCount, actual: ${patches.length})\n'
          'Patches:\n$patches');
    }
    try {
      modifiedInput =
          applyPatches(context.sourceFile, patches).trimRight() + '\n';
    } catch (_) {
      print('Patches:\n${patches.map((p) {
        return '<Patch: from ${p.startOffset} to ${p.endOffset} with text "${p.updatedText}">';
      }).join('\n')}\n');
      rethrow;
    }
    if (validateContents != null) {
      expect(() => validateContents(modifiedInput), returnsNormally,
          reason: 'output is invalid');
    }
    if (shouldDartfmtOutput) {
      modifiedInput = _formatWithBetterFailureOutput(modifiedInput,
          uri: '$inputUrl.modifiedInput');
    }
    expect(modifiedInput, expectedOutput,
        reason: 'Original input:\n---------------\n$input');
  }

  if (testIdempotency) {
    final context =
        await getFileContext(contents: input, path: '$inputUrl.modifiedInput');
    final patches = await suggestor(context).toList();
    var doubleModifiedInput =
        applyPatches(context.sourceFile, patches).trimRight() + '\n';
    if (shouldDartfmtOutput) {
      doubleModifiedInput = _formatWithBetterFailureOutput(doubleModifiedInput,
          uri: '$inputUrl.doubleModifiedInput');
    }
    expect(doubleModifiedInput, expectedOutput,
        reason: 'Should be idempotent, but changed in the second run.\n\n'
            'Original input:\n---------------\n$input');
  }
}

/// Throws if [yaml] is an invalid pubspec, either due to:
///
/// - being unparseable
/// - having incorrect structure (this check is not comprehensive)
void validatePubspecYaml(String yaml) {
  final yamlDoc = loadYamlDocument(yaml);

  expect(yamlDoc.contents, isA<YamlMap>());
  final extraTopLevelKeys =
      (yamlDoc.contents as YamlMap).keys.toSet().difference(const {
    'name',
    'version',
    'author',
    'executables',
    'description',
    'dependencies',
    'dev_dependencies',
    'dependency_overrides',
  });
  expect(extraTopLevelKeys, isEmpty,
      reason: 'unexpected top-level keys in pubspec.yaml;'
          ' could the dependencies be missing indentation?');
}

Func1<T, A> boundExpectAsync1<T, A>(T Function(A) callback,
        {int count = 1, int max = 0, String? id, String? reason}) =>
    expectAsync1(callback, count: count, max: max, id: id, reason: reason);

Func2<T, A, B> boundExpectAsync2<T, A, B>(T Function(A, B) callback,
        {int count = 1, int max = 0, String? id, String? reason}) =>
    expectAsync2(callback, count: count, max: max, id: id, reason: reason);

extension PatchMatchers on TypeMatcher<Patch> {
  Matcher havingText(dynamic matcher) =>
      having((p) => p.updatedText, 'updatedText', matcher);
}

Matcher hasPatchText(dynamic matcher) => isA<Patch>().havingText(matcher);

Matcher isMuiMigrationFixmeCommentPatch({String withMessage = ''}) =>
    hasPatchText(matches(
      RegExp(r'// FIXME\(mui_migration\) - .+ - ' + RegExp.escape(withMessage)),
    ));

extension ObjectMatchers on TypeMatcher<Object> {
  Matcher havingToStringValue(dynamic matcher) =>
      having((p) => p.toString(), 'toString() value', matcher);
}

extension ArgumentErrorMatchers on TypeMatcher<ArgumentError> {
  Matcher havingMessage(dynamic matcher) =>
      having((e) => e.message, 'message', matcher);
}

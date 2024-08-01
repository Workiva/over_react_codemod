import 'dart:io';
import 'dart:math';

import 'package:logging/logging.dart';
import 'package:over_react_codemod/src/util/command.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import './spec.dart';

Future<PackageSpec> gitRefPackageSpec(String repoUrl, String gitRef) async {
  final cloneDirectory = await gitClone(repoUrl);

  Future<void> runGitInheritStdio(List<String> args) =>
      runCommandAndThrowIfFailedInheritIo('git', args,
          workingDirectory: cloneDirectory.path);

  Future<String> runGit(List<String> args) =>
      runCommandAndThrowIfFailed('git', args,
          workingDirectory: cloneDirectory.path);

  // Clear any local changes, such as a pubspec.lock that got updated upon pub get.
  await runGit(['reset', '--hard']);
  await runGitInheritStdio(['fetch', 'origin', gitRef]);
  await runGit(['checkout', '--detach', 'FETCH_HEAD']);

  final commit = await runGit(['rev-parse', 'HEAD']);
  final description = await
      // Try using a tag first
      runGit(['describe', '--exact-match', '--tags', 'HEAD'])
          // then fall back to the commit
          .onError((_, __) => commit);

  final packageName = (loadYamlNode(
          File(p.join(cloneDirectory.path, 'pubspec.yaml')).readAsStringSync())
      as YamlMap)['name'] as String;

  return PackageSpec(
    packageName: packageName,
    versionId: commit,
    sourceDescription: 'Git ref $gitRef: $description',
    getDirectory: () async => cloneDirectory,
  );
}

Future<Directory> gitClone(String repoUrl) async {
  // 'git@example.com/foo/bar.git' -> ['foo', 'bar.git']
  // 'https://example.com/foo/bar.git' -> ['foo', 'bar.git']
  final cloneSubdirectory =
      p.joinAll(repoUrl.split(':').last.split('/').takeLast(2));

  final cloneDirectory =
      Directory(p.join('.package-cache/clones', cloneSubdirectory));
  if (!cloneDirectory.existsSync()) {
    cloneDirectory.parent.createSync(recursive: true);
    Logger('gitClone').fine('Cloning $repoUrl...');
    await runCommandAndThrowIfFailedInheritIo(
        'git', ['clone', repoUrl, cloneDirectory.path]);
  }

  return cloneDirectory;
}

extension<E> on List<E> {
  List<E> takeLast(int amount) {
    RangeError.checkNotNegative(amount);
    return sublist(max(length - amount, 0));
  }
}

// Copyright 2024 Workiva Inc.
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

import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'transport.dart';

Future<String> getLatestVersionOfPackage(String packageName,
    {required String host}) async {
  final packageInfo =
      await getPackageInfo(packageName: packageName, host: host);
  final latestVersion = (packageInfo['latest'] as Map)['version'] as String;
  return latestVersion;
}

// Fetch pub packages from a pub server
// Adapted from https://github.com/Workiva/cp_labs/blob/3c436d14cfaf958820dcf0a7ae44425f155c2bdb/tool/nsdash/bin/src/pub.dart#L10
Future<List<String>> fetchAllPackageNames(String host) async {
  final logger = Logger('fetchPackages');
  logger.fine('Loading list of all packages from $host...');

  Uri? uri = Uri.parse('$host/api/packages');
  var page = 0;

  final packageNames = <String>[];
  // Get ALL packages from a server
  while (uri != null) {
    if (page != 0) {
      logger.finer('Fetching additional page $page: $uri');
    }

    page++;
    // request the url
    var response = await httpClient.newRequest().get(uri: uri);
    if (response.status != 200) {
      throw HttpException('${response.status} ${response.statusText}',
          uri: uri);
    }
    final json = response.body.asJson() as Map;

    // get the next_url top level property if it exists, set url
    final nextUrl = json['next_url'] as String?;
    uri = nextUrl == null ? null : Uri.parse(nextUrl);

    for (final p in json['packages'] as List) {
      final name = p['name'] as String;
      packageNames.add(name);
    }
  }
  logger.finer('Done. Loaded ${packageNames.length} packages from $page pages');
  return packageNames;
}

Future<Map> getPackageInfo(
    {required String packageName, required String host}) async {
  final uri = Uri.parse(p.url.join(host, 'api/packages', packageName));
  final response = await httpClient.newRequest().get(uri: uri);
  return (await response.body.asJson()) as Map;
}

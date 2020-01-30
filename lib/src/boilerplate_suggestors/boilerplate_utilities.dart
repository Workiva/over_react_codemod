// Copyright 2020 Workiva Inc.
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

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';

class SemverHelper {
  static Map _exportList;

  void fromReport(String path) async {
    var fileContents;
    await File(path).readAsString().then((String contents) {
      fileContents = contents;
    });

    Map decoded = jsonDecode(fileContents);
    _exportList = decoded['exports'];
  }

  //Future<List<String>> getPublicExportLocations(ClassDeclaration node) async {
  Map getPublicExportLocations(ClassDeclaration node) {
      final className = node.name.name;

    return _exportList;
  }
}

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

String withOverReactAndWsdImports(String source) => /*language=dart*/ '''
    import 'package:over_react/over_react.dart';
    import 'package:web_skin_dart/component2/all.dart';
    import 'package:web_skin_dart/component2/all.dart' as wsd_v2;
    import 'package:web_skin_dart/ui_components.dart' as wsd_v1;
    import 'package:web_skin_dart/component2/toolbars.dart' as toolbars_v2;
    import 'package:web_skin_dart/toolbars.dart' as toolbars_v1;
    
    $source
''';

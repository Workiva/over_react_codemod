// TODO move to shared file
String withOverReactAndWsdImports(String source) => /*language=dart*/ '''
    import 'package:over_react/over_react.dart';
    import 'package:web_skin_dart/component2/all.dart';
    import 'package:web_skin_dart/component2/all.dart' as wsd_v2;
    import 'package:web_skin_dart/ui_components.dart' as wsd_v1;
    
    $source
''';

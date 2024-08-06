import 'package:dart_dev/dart_dev.dart';
import 'package:glob/glob.dart';

final config = {
  'format': FormatTool()
    ..exclude = [
      Glob('test/test_fixtures/**'),
    ]
};

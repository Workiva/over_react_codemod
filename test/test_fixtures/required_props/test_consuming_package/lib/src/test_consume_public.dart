import 'package:test_package/entrypoint.dart';

usages() {
  // 4 usages in source package, 1 in this package
  (TestPublic()
    ..set100percent = ''
    ..set20percent = '')();
}

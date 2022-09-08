import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:over_react_codemod/src/intl_suggestors/intl_messages.dart';
import 'package:test/test.dart';

void main() {
  final FileSystem fs = MemoryFileSystem();

  late IntlMessages messages;

  group('basic', () {
    test('Find method names via RegExp', () {
      var matches = sampleMethods
          .map((each) => IntlMessages.methodMatcher.matchAsPrefix(each));
      var names = [for (var m in matches) m?.group(m.groupCount)];
      expect(names, ['orange', 'aquamarine', 'long', 'function']);
    });

    test('methodName', () {
      var names = [
        for (var method in sampleMethods) IntlMessages.methodName(method)
      ];
      expect(names, ['orange', 'aquamarine', 'long', 'function']);
    });
  });
  group('round-trip', () {
    setUp(() async {
      final Directory tmp = await fs.systemTempDirectory.createTemp();
      var intlFile = tmp.childFile('foo_intl.dart');
      intlFile.createSync(recursive: true);
      intlFile.writeAsStringSync(
          "${IntlMessages.prologueFor('TestClassIntl')}\n${sampleMethods.join('\n')}\n}\n");
      messages = IntlMessages('TestClass', tmp, '', output: intlFile);
    });

    test('messages found', () {
      expect(messages.methods.length, 4);
      expect(
          messages.methods.keys, ['orange', 'aquamarine', 'long', 'function']);
      expect(messages.methods.values, sampleMethods);
    });
  });
}

List<String> sampleMethods = [
  "  static String get orange => Intl.message('orange', name: 'TestProjectIntl_orange', desc: 'The color.',);",
  "  static String get aquamarine => Intl.message('aquamarine', name: 'TestProjectIntl_aquamarine', desc: 'The color', meaning: 'blueish',);",
  """  static String get long => Intl.message('''multi
line 
string''', name: 'TestProjectIntl_long',);""",
  """  static String function(String x) => Intl.message('abc\${x}def'), name: 'TestProjectIntl_function',);""",
];

// A test utility to be invoked from the debug console to see where subtly-different long strings differ.
void firstDifference(String a, String b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      print(a.substring(i));
      return;
    }
  }
}

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
    test('Tabs instead of spaces', () {
      var tabbed =
          '''\tstatic String get activateTheSelectedNode => Intl.message(
        'Activate the selected node',
        name: 'WOutlineIntl_activateTheSelectedNode',
      );
\tstatic String get addChild => Intl.message(
        'Add Child',
        name: 'WOutlineIntl_addChild',
      );''';
      var split = tabbed
          .split(IntlMessages.methodSplitter)
          .where((each) => each.isNotEmpty);
      expect(split.length, 2);
      expect(split.first, startsWith('activateTheSelectedNode'));
      expect(split.last, startsWith('addChild'));
    });
  });

  group('Create with no messages', () {
    late Directory tmp;
    late File intlFile;
    setUp(() async {
      tmp = await fs.systemTempDirectory.createTemp();
      intlFile = tmp.childFile('foo_intl.dart');
      intlFile.createSync(recursive: true);
    });

    test('empty', () {
      messages = IntlMessages('TestClass', tmp, '', output: intlFile);
      messages.write();
      expect(messages.outputFile.readAsStringSync(), expectedFile(''));
    });
  });
  group('round-trip', () {
    late Directory tmp;
    late File intlFile;

    writeExisting(List<String> methods) {
      intlFile.writeAsStringSync(
          "${IntlMessages.prologueFor('TestClassIntl')}\n${methods.join('\n')}\n}\n");
      messages = IntlMessages('TestClass', tmp, '', output: intlFile);
    }

    setUp(() async {
      tmp = await fs.systemTempDirectory.createTemp();
      intlFile = tmp.childFile('foo_intl.dart');
      intlFile.createSync(recursive: true);
      writeExisting(sampleMethods);
    });

    test('messages found', () {
      expect(messages.methods.length, 4);
      expect(
          messages.methods.keys, ['orange', 'aquamarine', 'long', 'function']);
      expect(messages.methods.values, sampleMethods);
    });

    test('messages written as expected', () {
      messages.write();
      expect(messages.outputFile.readAsStringSync(),
          expectedFile(sortedSampleMethods.join('\n')));
    });

    test('annotated messages rewritten properly when new ones are added', () {
      // Add an extra method. Name it so that it is sorted last without us needing to make the test sorting
      // more sophisticated.
      var extra =
          "  static String get zzNewMessage => Intl.message('new', name: 'TestProjectIntl_zzNewMessage',);";
      messages.addMethod(extra);
      messages.write();
      expect(messages.outputFile.readAsStringSync(),
          expectedFile([...sortedSampleMethods, extra].join('\n')));
    });

    test('duplicate names with different content throw', () {
      var tweaked = sampleMethods.last.replaceFirst('def', 'zzzz');
      expect(() => messages.addMethod(tweaked), throwsA(isA<AssertionError>()));
    });
  });
}

String expectedFile(String methods) => '''
import 'package:intl/intl.dart';

//ignore: avoid_classes_with_only_static_members
//ignore_for_file: unnecessary_brace_in_string_interps

class TestClassIntl {${methods.isNotEmpty ? '\n' : ''}$methods
}''';

List<String> sampleMethods = [
  "  static String get orange => Intl.message('orange', name: 'TestProjectIntl_orange', desc: 'The color.',);",
  "  static String get aquamarine => Intl.message('aquamarine', name: 'TestProjectIntl_aquamarine', desc: 'The color', meaning: 'blueish',);",
  """  static String get long => Intl.message('''multi
line 
string''', name: 'TestProjectIntl_long',);""",
  """  static String function(String x) => Intl.message('abc\${x}def'), name: 'TestProjectIntl_function',);""",
];

// The sample methods in a hard-coded sorted order.
List<String> get sortedSampleMethods => [
      sampleMethods[1],
      sampleMethods[3],
      sampleMethods[2],
      sampleMethods[0],
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

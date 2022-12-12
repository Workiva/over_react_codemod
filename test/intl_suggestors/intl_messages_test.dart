import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:over_react_codemod/src/intl_suggestors/intl_messages.dart';
import 'package:over_react_codemod/src/intl_suggestors/message_parser.dart';
import 'package:test/test.dart';

void main() {
  final FileSystem fs = MemoryFileSystem();

  late IntlMessages messages;

  group('basic', () {
    test('methodName', () {
      var names = [
        for (var method in sampleMethods)
          MessageParser.forMethod(method).methods.first.name
      ];
      expect(names, [
        'orange',
        'aquamarine',
        'long',
        'function',
        'aPlural',
        'formatted',
        'someSelect'
      ]);
    });
    test('Tabs instead of spaces', () {
      var tabbed =
          '''\tstatic String get activateTheSelectedNode => Intl.message(
        'Activate the selected node',
        name: 'TestProjectIntl_activateTheSelectedNode',
      );
      ''';
      expect(MessageParser.forMethod(tabbed).methods.first.name,
          'activateTheSelectedNode');
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
      messages = IntlMessages('TestProject', output: intlFile);
      messages.write();
      expect(messages.outputFile.readAsStringSync(), expectedFile(''));
    });

    test('name for adjacent string', () {
      // TODO: Adjacent strings are messy for finding the name.
      // TODO: This test is awkward because we've hidden away the parsing.
      var method = """  static String get adjacent => Intl.message('Adjacent'
        ' strings' ' on' ' two ' 'lines' ' eh' , name: 'TestProjectIntl_adjacentStringsOnTwoLines');""";
      var classSource = 'class Foo { $method }';
      var parsed = parseString(content: classSource);
      var intlClass = parsed.unit.declarations.first as ClassDeclaration;
      var methodDeclarations =
          intlClass.members.toList().cast<MethodDeclaration>();
      var argument = ((methodDeclarations.first.body.childEntities.toList()[1]
              as MethodInvocation)
          .argumentList
          .arguments
          .first as StringLiteral);
      messages = IntlMessages('TestProject', output: intlFile);
      var derivedName = messages.syntax.nameForNode(argument);
      expect(derivedName, 'adjacentStringsOnTwoLines');
    });
  });

  group('round-trip', () {
    late Directory tmp;
    late File intlFile;

    writeExisting(List<String> methods) {
      intlFile.writeAsStringSync(
          "${IntlMessages.prologueFor('TestProjectIntl')}\n${methods.join('\n')}\n}\n");
      messages = IntlMessages('TestProject', output: intlFile);
    }

    setUp(() async {
      tmp = await fs.systemTempDirectory.createTemp();
      intlFile = tmp.childFile('foo_intl.dart');
      intlFile.createSync(recursive: true);
      writeExisting(sampleMethods);
    });

    test('messages found', () {
      expect(messages.methods.length, 7);
      expect(messages.methods.keys, [
        'orange',
        'aquamarine',
        'long',
        'function',
        'aPlural',
        'formatted',
        'someSelect'
      ]);
      expect(messages.methods.values.map((each) => each.source).toList(),
          sampleMethods);
    });

    test('messages written as expected', () {
      messages.write(force: true);
      expect(messages.outputFile.readAsStringSync(),
          expectedFile(sortedSampleMethods.join('\n')));
    });

    test('annotated messages rewritten properly when new ones are added', () {
      // Add an extra method. Name it so that it is sorted last without us needing to make the test sorting
      // more sophisticated.
      var extra =
          "  static String get zzNewMessage => Intl.message('new', name: 'TestProjectIntl_zzNewMessage');";
      messages.addMethod(extra);
      messages.write();
      expect(messages.outputFile.readAsStringSync(),
          expectedFile([...sortedSampleMethods, extra].join('\n')));
    });

    test('duplicate names with different content throw in addMethod', () {
      var tweaked = sampleMethods[3].replaceFirst('def', 'zzzz');
      expect(() => messages.addMethod(tweaked), throwsA(isA<AssertionError>()));
    });

    test('duplicate names with different content give a valid name if asked',
        () {
      /// Modify the message text, but also change the name so that when it parses the function it will
      /// find it. So we're really exercising the nameForString more than the addMethod.
      var tweaked = sampleMethods[3].replaceFirst('def', 'zzzz');
      var name = messages.nameForString('function', r'abc${x}zzzz');
      tweaked = tweaked.replaceFirst('function', name);
      messages.addMethod(tweaked);
      var tweakedMore = sampleMethods[3].replaceFirst('abc', 'www');
      var otherName = messages.nameForString('function', r'www${x}def');
      tweakedMore = tweakedMore.replaceFirst('function', otherName);
      messages.addMethod(tweakedMore);
      expect(messages.methods.length, 9);
      expect(messages.methods['function']?.source, sampleMethods[3]);
      expect(messages.methods['function1']?.source, tweaked);
      expect(messages.methods['function2']?.source, contains(r'www${x}def'));
    });
  });
}

String wIntl = 'w_intl';
String expectedFile(String methods) => '''
import 'package:${wIntl}/intl_wrapper.dart';

//ignore_for_file: avoid_classes_with_only_static_members
//ignore_for_file: unnecessary_brace_in_string_interps

class TestProjectIntl {${methods.isNotEmpty ? '\n' : ''}$methods
}''';

List<String> sampleMethods = [
  "  static String get orange => Intl.message('orange', name: 'TestProjectIntl_orange', desc: 'The color.');",
  "  static String get aquamarine => Intl.message('aquamarine', name: 'TestProjectIntl_aquamarine', desc: 'The color', meaning: 'blueish');",
  """  static String get long => Intl.message('''multi
line 
string''', name: 'TestProjectIntl_long');""",
  """  static String function(String x) => Intl.message('abc\${x}def', name: 'TestProjectIntl_function');""",
  """  static String aPlural(int n) => Intl.plural(n, zero: 'zero', other: 'other', name: 'aPlural', args: [n]);""",
  """  static List<Object> formatted(Object f) => Intl.formattedMessage([f, 'foo'], name: 'formatted', args: [f]);""",
  """  static String someSelect(Object choice) => Intl.select(choice, {'a' : 'b'}, name: 'someSelect', args: [choice]);"""
];

// The sample methods in a hard-coded sorted order.
List<String> get sortedSampleMethods =>
    [4, 1, 5, 3, 2, 0, 6].map((i) => sampleMethods[i]).toList();

// A test utility to be invoked from the debug console to see where subtly-different long strings differ.
void firstDifference(String a, String b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      print(a.substring(i));
      return;
    }
  }
}

import 'dart:convert';

main() {
  final str = code_boilerplatePublicApi.summaryWithDetailsLink({
    'nodeName': 'FooProps',
    'locations': ['location1', 'location2'],
  }).asFixmeComment();

  print('Comment: ');
  print(str);

}

const code_boilerplateExternalSuperclassOrMixin = CodedMessage(
  '`%{nodeName}` could not be auto-migrated to the new over_react boilerplate because it %{inheritanceReasonPortion}: %{superclassOrMixinNames} - which come(s) from an external library.',
  // <editor-fold>
  '''
To complete the migration, you should:
  1. Check on the boilerplate migration status of the library %{superclassOrMixinNames} come(s) from.
  
  2. Once the library has released a version that includes updated boilerplate,
     bump the lower bound of your dependency to that version in your `pubspec.yaml`, and run `pub get`.
     
  3. Re-run the migration script with the following flag:
  
       pub global run over_react_codemod:boilerplate_upgrade --convert-classes-with-external-superclasses
     
  4. Once the migration is complete, you should notice that %{superclassOrMixinNames} has/have been deprecated. 
     Follow the deprecation instructions to consume the %{superclassOrMixinNames} replacement(s) by either updating your usage to
     the new %{mixinOrClass} %{superclassOrMixinNames} name(s) and/or updating to a different entrypoint that exports the version(s) of 
     %{superclassOrMixinNames} that %{superclassOrMixinNames} is/are compatible with the new over_react boilerplate.
  ''',
  // </editor-fold>
);

const code_boilerplatePublicApi = CodedMessage(
  '`%{nodeName}` could not be auto-migrated to the new over_react boilerplate because it is exported from the following libraries in this repo: %{locations}',
  // <editor-fold>
  '''
Upgrading it would be considered a breaking change since consumers in other repos can no longer extend from the props class.

To complete the migration, you should:
  1. Deprecate `%{nodeName}`.
  
  2. Make a copy of it, renaming it something like `%{nodeName}V2`.
  
  3. Replace all your current usage of the deprecated `%{nodeName}` with `%{nodeName}V2`.
  
  4. Add a `hide %{nodeName}V2` clause to all places where it is exported, and then run:
  
       pub global run over_react_codemod:boilerplate_upgrade
       
  5a. If `%{nodeName}` had consumers outside this repo, and it was intentionally made public,
      remove the `hide` clause you added in step 4 so that the new mixin created from `%{nodeName}V2`
      will be a viable replacement for `%{nodeName}`.
      
  5b. If `%{nodeName}` had no consumers outside this repo, and you have no reason to make the new
      "V2" class / mixin public, update the `hide` clause you added in step 4 to include both the
      concrete class and the newly created mixin.
      
  6. Remove this FIX-ME comment.
  ''',
  // </editor-fold>
);

const code_boilerplateUnmigratedSuperclass = CodedMessage(
  '`%{nodeName}` could not be auto-migrated to the new over_react boilerplate because it extends from `%{superclassName}`, which was not able to be migrated.',
  // <editor-fold>
  '''
To complete the migration, you should:
  1. Look at the FIX-ME comment that has been added to `%{superclassName}` - 
     and follow the steps outlined there to complete the migration.
     
  2. Re-run the migration script:
     pub global run over_react_codemod:boilerplate_upgrade
  ''',
  // </editor-fold>
);

const code_boilerplateNoSemverReport = CodedMessage(
  'A Workiva Semver report was not found. `%{nodeName}` is assumed to be exported from a library in this repo and thus was not auto-migrated to the new over_react boilerplate.',
  // <editor-fold>
  '''
--------- If you are migrating an OSS library outside of Workiva ---------
You do not have access to Workiva's internal Semver audit tool. 
To complete the migration, you should:

  1. Revert all changes to remove this FIX-ME comment
  
  2. Re-run the migration script with the following flag:    

       pub global run over_react_codemod:boilerplate_upgrade --treat-all-components-as-private

  NOTE: The changes made to props / state classes by the codemod constitute breaking changes
  if you publicly export them from your library. We strongly recommend that you release 
  the subsequent changes in a major version.

--------- If you are migrating a Workiva library ---------
To complete the migration, you should:
  1. Revert all changes to remove this FIX-ME comment
  
  2. Generate a semver report by running the following script:

       pub global activate semver_audit --hosted-url=https://pub.workiva.org
       pub global run semver_audit generate 2> semver_report.json

  3. Re-run the migration script:

       pub global run over_react_codemod:boilerplate_upgrade
  ''',
  // </editor-fold>
);

// These codes must remain the same, as they'll be committed to consumer source
// code and not updated.
const _messagesByCode = {
  1: code_boilerplateExternalSuperclassOrMixin,
  2: code_boilerplatePublicApi,
  3: code_boilerplateUnmigratedSuperclass,
  4: code_boilerplateNoSemverReport,
};

const _detailsBaseUrl = 'https://workiva.github.io/over_react_codemod/error_code/';

extension SourceHelpers on String {
  String asFixmeComment() => 'FIXME: $this'.commented();

  String commented() => splitMapJoin('\n', onNonMatch: (line) => '// $line');

  String indented([String indent = '  ']) =>
      splitMapJoin('\n', onNonMatch: (line) => '$indent$line');
}

class CodedMessage {
  final String summary;
  final String details;

  const CodedMessage(this.summary, this.details);

  factory CodedMessage.fromCode(int code) {
    final message = _messagesByCode[code];
    if (message == null) throw ArgumentError.value(code, 'code', 'Code does not exist');
    return message;
  }

  int get code => _messagesByCode.entries.firstWhere((e) => e.value == this).key;

  @override
  toString() => 'CodedMessage:\n\nsummary: $summary\n\ndetails: $details';

  String summaryString(Map<String, Object> args) => _formatStr(summary, args);
  String detailsString(Map<String, Object> args) => _formatStr(details, args);

  String summaryAndDetailsString(Map<String, Object> args) =>
      '${summaryString(args)}\n\n${detailsString(args)}';

  String summaryWithDetailsLink(Map<String, Object> args) {
    final summaryStr = _formatStr(summary, args);
    final detailsLink = Uri.parse(_detailsBaseUrl).replace(queryParameters: {
      'code': code.toString(),
      'args': jsonAndBase64Encode(args),
    });

    return '$summaryStr\n\n'
        'For more details/instructions, see: $detailsLink';
  }

  static String summaryAndDetailsStringFromQueryParams(Map<String, String> queryParams) {
    int code;
    Map<String, Object> args;
    CodedMessage message;

    try {
      code = int.parse(queryParams['code']);
      args = (base64ndJsonDecode(queryParams['args']) as Map).cast();
      message = CodedMessage.fromCode(code);
      return message.summaryAndDetailsString(args);
    } catch (e) {
      throw Exception('Error reconstructing message.'
          '\n\ncode: $code'
          '\n\nargs: $args'
          '\n\nmessage: $message'
          '\n\nexception: $e');
    }
  }
}

final base64JsonFusedCodec = json.fuse(utf8).fuse(base64Url);
final jsonAndBase64Encode = base64JsonFusedCodec.encode;
final base64ndJsonDecode = base64JsonFusedCodec.decode;

final _formatPattern = RegExp(r'%\{(\w+)\}');
String _formatStr(String format, Map<String, Object> data) {
  return format.splitMapJoin(_formatPattern, onMatch: (match) {
    final key = match[1];
    if (!data.containsKey(key)) {
      throw ArgumentError('Invalid string substitution: key `$key` does not exist within data: $data');
    }
    return data[key].toString();
  });
}

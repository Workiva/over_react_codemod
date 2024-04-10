import 'package:analyzer/dart/ast/ast.dart';
import 'package:over_react_codemod/src/util.dart';

/// Whether the nullability hint already exists after [type].
bool nullableHintAlreadyExists(TypeAnnotation type) {
  // The nullability hint will follow the type so we need to check the next token to find the comment if it exists.
  final commentsPrecedingType = type.endToken.next?.precedingComments?.value();
  return commentsPrecedingType?.contains(nullableHint) ?? false;
}

const nullableHint = '/*?*/';

/// Whether the non-nullable hint already exists after [type].
bool nonNullableHintAlreadyExists(TypeAnnotation type) {
  // The nullability hint will follow the type so we need to check the next token to find the comment if it exists.
  final commentsPrecedingType = type.endToken.next?.precedingComments?.value();
  return commentsPrecedingType?.contains(nonNullableHint) ?? false;
}

const nonNullableHint = '/*!*/';

/// Whether the late hint already exists before [type]
bool requiredHintAlreadyExists(TypeAnnotation type) {
  // Since the `/*late*/` comment is possibly adjacent to the prop declaration's doc comments,
  // we have to recursively traverse the `precedingComments` in order to determine if the `/*late*/`
  // comment actually exists.
  return allComments(type.beginToken).any((t) => t.value() == '/*late*/');
}

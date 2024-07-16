// Copyright 2024 Workiva Inc.
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
  return allCommentsForNode(type).any((t) => t.value() == '/*late*/');
}

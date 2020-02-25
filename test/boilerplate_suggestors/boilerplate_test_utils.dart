// Copyright 2020 Workiva Inc.
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

String publiclyExportedFixmeComment(String className) => '''
// FIXME: `$className` could not be auto-migrated to the new over_react boilerplate
// because doing so would be a breaking change since `$className` is exported from a
// library in this repo.
//
// To complete the migration, you should: 
//   1. Deprecate `$className`.
//   2. Make a copy of it, renaming it something like `${className}V2`.
//   3. Replace all your current usage of the deprecated `$className` with `${className}V2`.
//   4. Add a `hide ${className}V2` clause to all places where it is exported, and then run:
//        pub run over_react_codemod:boilerplate_upgrade
//   5a. If `$className` had consumers outside this repo, and it was intentionally made public,
//       remove the `hide` clause you added in step 4 so that the new mixin created from `${className}V2`
//       will be a viable replacement for `$className`.
//   5b. If `$className` had no consumers outside this repo, and you have no reason to make the new
//       "V2" class / mixin public, update the `hide` clause you added in step 4 to include both the 
//       concrete class and the newly created mixin.
//   6. Remove this FIXME comment.''';

String externalSuperclassComment(String className, String superClassName) => '''
// FIXME: `$className` could not be auto-migrated to the new over_react boilerplate 
// because it extends from: $superClassName - which comes from an external library.
//
// To complete the migration, you should:
//   1. Check on the boilerplate migration status of the library it comes from.
//   2. Once the library has released a version that includes updated boilerplate,
//      bump the lower bound of your dependency to that version in your `pubspec.yaml`, and run `pub get`.
//   3. Re-run the migration script with the following flag:
//      pub run over_react_codemod:boilerplate_upgrade --convert-classes-with-external-superclasses
//   4. Once the migration is complete, you should notice that $superClassName has been deprecated. 
//      Follow the deprecation instructions to consume the replacement by either updating your usage to
//      the new class name and/or updating to a different entrypoint that exports the version(s) of 
//      $superClassName that is compatible with the new over_react boilerplate.''';

# boilerplate_upgrade FIXME Instructions

This page contains detailed follow-up instructions for FIXMEs added by the `boilerplate_upgrade` executable.


### External Superclass

> FIXME: `FooProps` could not be auto-migrated to the new over_react boilerplate because it extends from `BarProps`, which comes from from an external library.

To address:
1. Check on the boilerplate migration status of the library it comes from.
2. Once the library has released a version that includes updated boilerplate,
   bump the lower bound of your dependency to that version in your `pubspec.yaml`, and run `pub get`.
3. Re-run the migration script with the following flag:
   pub global run over_react_codemod:boilerplate_upgrade --convert-classes-with-external-superclasses
4. Once the migration is complete, you should notice that $superclassName has been deprecated. 
   Follow the deprecation instructions to consume the replacement by either updating your usage to
   the new class name and/or updating to a different entrypoint that exports the version(s) of 
   $superclassName that is compatible with the new over_react boilerplate.


### Public API

> FIXME: `FooProps could not be auto-migrated to the new over_react boilerplate because it is exported from the following library in this repo:
> lib/foo.dart
> Upgrading it would be considered a breaking change since consumer components can no longer extend from it. 

To complete the migration (for instance, for a class named `FooProps`), you can: 
1. Deprecate `FooProps`.
2. Make a copy of it, renaming it to something like `FooPropsV2`.
3. Replace all your current usage of the deprecated `FooProps` with `FooPropsV2`.
4. Add a `hide FooPropsV2` clause to all places where it is exported, and then run:
     pub global run over_react_codemod:boilerplate_upgrade
5a. If `FooProps` had consumers outside this repo, and it was intentionally made public,
    remove the `hide` clause you added in step 4 so that the new mixin created from `FooPropsV2` 
    will be a viable replacement for `FooProps`.
5b. If `FooProps` had no consumers outside this repo, and you have no reason to make the new
    "V2" class / mixin public, update the `hide` clause you added in step 4 to include both the 
    concrete class and the newly created mixin.
6. Remove this FIX-ME comment.

If are migrating a Workiva library and have questions, or want to discuss alternative solutions, 
please reach out in the #support-ui-platform Slack room. 


### Unmigrated Superclass
> FIXME: `FooProps` could not be auto-migrated to the new over_react boilerplate because it extends from `$superclassName`, which was not able to be migrated.

To complete the migration, you should:
  1. Look at the FIX-ME comment that has been added to `$superclassName` - 
     and follow the steps outlined there to complete the migration.
  2. Re-run the migration script:
     
        pub global run over_react_codemod:boilerplate_upgrade

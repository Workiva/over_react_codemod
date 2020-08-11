# boilerplate_upgrade FIXME Instructions

This page contains detailed follow-up instructions for FIXMEs added by the `boilerplate_upgrade` executable.


## External Superclass

> FIXME: `FooProps` could not be auto-migrated to the new over_react boilerplate because it extends from `BarProps`, which comes from from an external library.

To address:
1. Check on the boilerplate migration status of the library it comes from.
2. Once the library has released a version that includes updated boilerplate,
   bump the lower bound of your dependency to that version in your `pubspec.yaml`, and run `pub get`.
3. Re-run the migration script with the following flag:
   
       pub global run over_react_codemod:boilerplate_upgrade --convert-classes-with-external-superclasses

       You can specify one or more paths or globs to run the codemod on only some files:
       pub global run over_react_codemod:boilerplate_upgrade path/to/your/file.dart another/file.dart --convert-classes-with-external-superclasses
       pub global run over_react_codemod:boilerplate_upgrade lib/**.dart --convert-classes-with-external-superclasses
   
4. Once the migration is complete, you should notice that $superclassName has been deprecated. 
   Follow the deprecation instructions to consume the replacement by either updating your usage to
   the new class name and/or updating to a different entrypoint that exports the version(s) of 
   `BarProps` that is compatible with the new over_react boilerplate.


## Public API

> FIXME: `FooProps could not be auto-migrated to the new over_react boilerplate because it is exported from the following library in this repo:
> lib/foo.dart
> Upgrading it would be considered a breaking change since consumer components can no longer extend from it. 

If are migrating a Workiva library and have questions, or want to discuss alternative solutions, 
please reach out in the #support-ui-platform Slack room. 

There are a couple different options for this:

#### Option 1: create a versioned API

To complete the migration (for instance, for a class named `FooProps`), you can: 
1. Deprecate `FooProps`.
2. Make a copy of it, renaming it to something like `FooPropsV2`.
3. Replace all your current usage of the deprecated `FooProps` with `FooPropsV2`.
4. Add a `hide FooPropsV2` clause to all places where it is exported, and then run:
     
       pub global run over_react_codemod:boilerplate_upgrade

       You can specify one or more paths or globs to run the codemod on only some files:
       pub global run over_react_codemod:boilerplate_upgrade path/to/your/file.dart another/file.dart
       pub global run over_react_codemod:boilerplate_upgrade lib/**.dart
     
5.
    1. If `FooProps` had consumers outside this repo, and it was intentionally made public, remove the `hide` clause you added in step 4 so that the new mixin created from `FooPropsV2` will be a viable replacement for `FooProps`.
    2. If `FooProps` had no consumers outside this repo, and you have no reason to make the new "V2" class / mixin public, update the `hide` clause you added in step 4 to include both the concrete class and the newly created mixin.
6. Remove this FIXME comment.


#### Option 2: retain and deprecate a backwards-compatible concrete props clas
This will allow the public copy to still be extended by external legacy boilerplate components and otherwise used by external libraries without breaking changes, while still allowing the component to be upgraded.
 
However, it has the drawback of having to keep deprecated code up to date.

To complete the migration (for instance, for a class named `FooProps`), you can: 
1. Remove the fixme comment and perform the migration as if the component were private:     

    pub global run over_react_codemod:boilerplate_upgrade --treat-all-components-as-private

    You can specify one or more paths or globs to run the codemod on only some files:
    pub global run over_react_codemod:boilerplate_upgrade path/to/your/file.dart another/file.dart --treat-all-components-as-private
    pub global run over_react_codemod:boilerplate_upgrade lib/**.dart --treat-all-components-as-private

1. Make the concrete props class (`FooProps`) private, and make a public copy of it. In the public copy, mix in all generated classes, and expose the meta constant.

    ```dart
    // Before migration
    @Factory
    UiFactory<FooProps> Foo = ...;
    
    @Props()
    class _$FooProps extends UiProps with BarPropsMixin {
       ...
    }
    ```

    ```dart
    // After migration 
    
    // Ensure all mixins used by FooProps exist in superclass constraints 
    // or implements clauses if `FooProps` is used to type variables externally
    // since FooPropsMixin will be its replacement.
    //
    // Alternatively, a separate interface could be created and used for typing.
    mixin FooPropsMixin on UiProps, BarPropsMixin { ... }
    
    UiFactory<FooProps> Foo = ...;
    
    class FooProps = UiProps with FooPropsMixin, BarPropsMixin;
    ```

    ```dart
    // Make concrete class private
    UiFactory<_FooProps> Foo = ...;
    
    class _FooProps = UiProps with FooPropsMixin, BarPropsMixin;
    ```
    
    ```dart
    // Make a copy and implement the public class
    UiFactory<_FooProps> Foo = ...;
    
    class _FooProps = UiProps with FooPropsMixin, BarPropsMixin implements FooProps;
    
    @Deprecated('Use FooPropsMixin instead')
    class FooProps = UiProps with FooPropsMixin, $FooPropsMixin, BarPropsMixin, $BarPropsMixin {
      static const PropsMeta = _$metaForFooPropsMixin;
    }
    ```
    
#### Option 3?
If you have a special case, unique constraints, or have other ideas, please let us know!

Like we said above:
> If are migrating a Workiva library and have questions, or want to discuss alternative solutions, 
please reach out in the #support-ui-platform Slack room. 
    
## Unmigrated Superclass
> FIXME: `FooProps` could not be auto-migrated to the new over_react boilerplate because it extends from `BarProps`, which was not able to be migrated.

To complete the migration, you should:
1. Look at the FIXME comment that has been added to `BarProps` - 
   and follow the steps outlined there to complete the migration.
2. Re-run the migration script:
   
       pub global run over_react_codemod:boilerplate_upgrade

       You can specify one or more paths or globs to run the codemod on only some files:
       pub global run over_react_codemod:boilerplate_upgrade path/to/your/file.dart another/file.dart
       pub global run over_react_codemod:boilerplate_upgrade lib/**.dart

## Non-Component2
> FIXME: `FooProps` could not be auto-migrated to the new over_react boilerplate because `FooComponent` does not extend from `UiComponent2`.

To complete the migration, you should:
1. [Convert the component to extend from UiComponent2](https://github.com/Workiva/over_react/blob/master/doc/ui_component2_transition.md)
1. Re-run the boilerplate migration script:
    
       pub global run over_react_codemod:boilerplate_upgrade 

       You can specify one or more paths or globs to run the codemod on only some files:
       pub global run over_react_codemod:boilerplate_upgrade path/to/your/file.dart another/file.dart
       pub global run over_react_codemod:boilerplate_upgrade lib/**.dart
## General Codemod Resources and Best Practices

See [the "Authoring codemods" section][authoring-codemods] of the main readme.

## Component Usage Codemods

### Design Principles

- Only migrate WSD component references that render the WSD component via a factory and immediately-invoked children.

    For example:
    ```dart
    Button()('Click me');
    (Button()
      ..skin = ButtonSkin.ALTERNATE
      ..addTestId('myButton')
    )('Click me');
    ```
  
    These usages comprise the majority of WSD component usages, and lend themselves well to automated migration
    (with some manual verification when needed).

    Other references to WSD components are less common and difficult to migrate automatically, so we won't attempt to migrate them with codemods. These cases include:
    - Creation of builders or map views

        For example:
        ```dart
        getButtonBuilder() => Button();
        ```
        ```dart
        final buttonProps = Button(getProps(someElement));
        ```
    - Other usages of factories

        For example: 
        ```dart
        isComponentOfType(type, Button);
        ```
    - Invocation of builders not using factories

        For example: 
        ```dart
        buttonBuilder();
        ```
    - Extension of component classes and props classes
    - Use of component refs
    
- When in doubt, flag for manual verification, even if you were able to migrate.

    If there's a potential issue that a migrated usage might be affected by, it's preferable to flag it for manual verification as opposed to silently ignoring the issue and hoping it's caught by testing.

    Many manual checks don't take much time or effort, and can help reduce the risk of regressions introduced during the migration.

### Coding Best Practices

(In addition to the general best practices linked [above](#general-codemod-resources-and-best-practices))

- Be conservative when computing patch ranges; replace only the code you need to.

     This helps prevent conflicting ("overlapping") patches, especially when there are multiple places in the code making replacements on the same usage.

- Watch out for `dynamic` expressions.

    Some expressions, such as the value being assigned to a prop, may have a static type of `dynamic`, and may not cause analysis errors if they're assigned to different props.

    For instance, just changing
    ```diff
    -  ..skin = dynamicTypedSkinValue
    +  ..color = dynamicTypedSkinValue
    ```
    for a `Button` component, without any other changes, would pass analysis but likely throw at runtime.

[authoring-codemods]: ../../../../README.md#authoring-codemods

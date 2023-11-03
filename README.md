# Over React Codemods

[![Pub](https://img.shields.io/pub/v/over_react_codemod.svg)](https://pub.dartlang.org/packages/over_react_codemod)
[![Build Status](https://github.com/Workiva/over_react_codemod/workflows/Dart%20CI/badge.svg?branch=master)](https://github.com/Workiva/over_react_codemod/actions?query=workflow%3A%22Dart+CI%22+branch%3Amaster)

> **Built with [dart_codemod][dart_codemod].**

Codemods to help consumers of [over_react][over_react] automate the migration of
UI component code. 

## Installation

> Note: this package requires Dart SDK version 2.1.0 to run, but the codemods
> themselves are designed to run on code that is written for Dart 1.x or 2.x.

```bash
dart pub global activate over_react_codemod
```

Once you've activated this package, you should be able to run whichever codemods
you need via `pub global run`.


## Internationalization Codemod

This package provides a `intl_message_migration` codemod that will modify existing UI component code to make them available for internationalization.

For more information, please see the [INTL Message Codemod Readme](docs/intl_message.md)

## Dart 1 to Dart 2 Codemod

The `dart2_upgrade` codemod that used to be provided by this package is no longer available.

To use it, activate over_react_codemod 1.12.1 instead of the latest:
```sh
dart pub global activate over_react_codemod ^1.12.1
```
and see its documentation: https://github.com/Workiva/over_react_codemod/tree/1.12.1#dart-1-to-dart-2-codemod

## Checking for Regressions

Especially in the case where a forwards- and backwards-compatible version of
your code is necessary, it can be helpful to be able to check automatically for
regressions after having initially migrated your code. Doing so will help
prevent accidentally merging code that doesn't meet your compatability
expectations.

Each of these codemods can be run in a `--fail-on-changes` mode that will count
the number of changes that _would_ have been suggested and exit with a non-zero
exit code if that number is greater than 0.

As an example, adding the following command to your CI process or pre-merge
checklist will prevent merging code that is not in the form that is compatible
with both Dart 1 and Dart 2:

```bash
dart pub global run over_react_codemod:dart2_upgrade --fail-on-changes
```

## Ignoring Codemod Suggestions

Some of the changes provided by the codemods in this package are based on
imperfect heuristics (e.g. looking for a specific naming convention) and
consequently may be susceptible to false positives. If you hit such a case in
your codebase, you can tell the codemod to ignore a certain line by attaching an
ignore comment either on the same line or the immediately preceding line.

For example, consider a mixin usage that happens to match the naming convention
of ending with `StateMixin`, but isn't actually an over_react state mixin:

```dart
class Foo extends Object with BarStateMixin {}
```

As is, the `dart2_upgrade --backwards-compat` codemod would find this code and
attempt to change it to:

```dart
class Foo extends Object
    with
        BarStateMixin,
        // ignore: mixin_of_non_class, undefined_class
        $BarStateMixin {}
```

But if `BarStateMixin` isn't actually an over_react state mixin, then this
updated code will fail. To avoid this problem, simply add an `// orcm_ignore`
comment to the mixin type that should be ignored:

```dart
class Foo extends Object
    with
        // orcm_ignore
        BarStateMixin {}
```

This ignore mechanism works with any of the changes that the codemods in this
package will try to suggest.


## Authoring codemods

### Resources

- Analyzer package
    - [AST documentation](https://github.com/dart-lang/sdk/blob/master/pkg/analyzer/doc/tutorial/ast.md)
    - [Element model documentation](https://github.com/dart-lang/sdk/blob/master/pkg/analyzer/doc/tutorial/element.md)
      - (the element model is only accessible from "resolved AST")
    - In general, the various `AstNode` and `Element` subclasses are well-documented, and are very helpful in describing the relationships between different types of nodes/elements and pointing to other classes. Reading those and clicking through the references is a good way to learn about specific structures, and help get your bearings.
- [codemod][dart_codemod] package

### Best practices

- Code defensively for edge-cases, and avoid assumptions about the AST or Element model.

    Some codemods process a lot of code, especially when identifying code that should be operated on, and some of that code may have structures you don't expect.

    That doesn't necessarily mean your codemod should handle every single edge-case, but generally it shouldn't break with uncaught exceptions when it encounters certain code.

    Things to avoid assumptions about:

    - The types or nullability of child/parent nodes
        - Prefer type checks over casts
          - `tryCast()` and `ancestorOfType()` can be handy in certain cases.
        - Prefer null-checks over `!`
    - The number of child nodes or other items in collections
        - When using `.first`/`.last`/`.single` on iterables, either check the length of the iterable first, or switch to something more conditional like `.firstWhere()` or `.firstOrNull`

- Avoid using `childEntities`

    Most AST node classes have getters for their different child nodes. Using these helps make code easier to read, and also provide typing (and nullability) which helps with static analysis and autocomplete.

    If you're manually traversing the AST trying to find a certain descendant, consider whether a visitor-based implementation would be better.

- Avoid using `AstNode.toSource()` (or `.toString()`) outside of tests

    - To identify relevant code. There may be different syntax variations (either current or in future Dart versions) of code that unintentionally wouldn't be a match.

        For example, if we were doing `expression.toSource() == 'foo.bar()'`, we would miss the following cases:
        ```dart
        foo..bar();
        foo?.bar();
        namespaced_import.foo.bar();
        foo.bar(optionalArgAddedInSubclass: true);
        ```

        Instead, we could check for the method name via:
        ```dart
        expression is MethodInvocation && expression.methodName.name == 'bar'
        ```
        and change the foo check to something else, depending on the use-case:
        ```dart
        // Check whether the target is a "foo" identifier
        // (though this doesn't handle prefixed cases)
        expression.realTarget?.tryCast<Identifier>()?.name == 'foo'
        // Check whether it statically points to a `foo` variable
        expression.realTarget?.tryCast<Identifier>()?.staticElement?.name == 'foo');
        // Or, Check whether it's a `Foo` object:
        isFooType(expression.realTarget?.staticType);
        // (Or, something else)
        ```

        For cases where the syntax seems simple enough where variations shouldn't be a problem, there are usually APIs that provide the value you're looking for.

        ```dart
        final identifier = parseIdentifier('foo');
        identifier.name; // 'foo'

        final boolean = parseBooleanLiteral('false');
        boolean.value; // false

        final import = parseImportDirective('import "package:foo/foo.dart";');
        import.uriContent; // 'package:foo/foo.dart'
        ```

    - For building patch strings (such as when moving code from one place to another).

        `toSource()` provides an approximation of the source, and may be missing comments or have different whitespace. If needed, use the `context.sourceFile` to get the original source for a given node.

- Don't make assumptions about existing whitespace and line breaks.

    There are different ways code can be formatted with dartfmt, and some code may not be formatted at all, so it's unsafe to make assumptions.

    For instance, if you'd like to yield a patch that deletes a newline with some code, either check for its existence first by getting the source or line number of that offset in `context.sourceFile`. Or, instead of deleting from `node.offset`, delete from the end of the previous token (`node.prevToken?.end ?? node.offset`) to take any whitespace between those nodes with it.

[dart_codemod]: https://github.com/Workiva/dart_codemod
[over_react]: https://github.com/Workiva/over_react
[over_react_dart2]: https://github.com/Workiva/over_react/blob/master/doc/dart2_migration.md

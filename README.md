# Over React Codemods

> **Built with [dart_codemod][dart_codemod].**

Codemods to help consumers of [over_react][over_react] automate the migration of
UI component code. Currently, the only use cases are around upgrading from Dart
1 to Dart 2.

## Installation

> Note: this package requires Dart SDK version 2.1.0 to run, but the codemods
> themselves are designed to run on code that is written for Dart 1.x or 2.x.

```bash
pub global activate over_react_codemod
```

Once you've activated this package, you should be able to run whichever codemods
you need via `pub global run`.

## Dart 1 to Dart 2 Codemods

Depending on your needs, you may be able to upgrade directly from Dart 1 to
Dart 2, or you may need to take an intermediary step and provide a version of
your codebase that is both forwards- and backwards-compatible.

This package provides three codemod executables:

- `pub global run over_react_codemod:dart1_to_dart2`

    Use this codemod if you want to migrate directly from Dart 1 compatibile
    code to Dart 2 compatible code and do not need to provide a version that is
    compatible with both.

    _Still in progress; coming soon._

- `pub global run over_react_codemod:dart1_to_dart1_and_dart2`

    Use this codemod to migrate your over_react code to a format that is both
    forwards-compatible with Dart 2 and backwards-compatible with Dart 1.

- `pub global run over_react_codemod:dart1_and_dart2_to_dart2`

    Use this codemod to migrate over_react code that has previously been
    migrated via the `dart1_to_dart1_and_dart2` codemod to the form that is only
    compatible with Dart 2. In other words, use this when you're ready to drop
    Dart 1 support.

    _Still in progress; coming soon._

For more information on the transition from Dart 1 to Dart 2 and how it affects
over_react, check out the [over_react Dart 2 migration guide](over_react_dart2).
It includes sample diffs of the changes that these codemods will introduce.

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
pub global run over_react_codemod:dart1_to_dart1_and_dart2 --fail-on-changes
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

As is, the `dart1_to_dart1_and_dart2` codemod would find this code and attempt
to change it to:

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

[dart_codemod]: https://github.com/Workiva/dart_codemod
[over_react]: https://github.com/Workiva/over_react
[over_react_dart2]: https://github.com/Workiva/over_react/blob/master/doc/dart2_migration.md

# INTL Message Codemod

The `intl_message_migration` codemod is one that helps prepare UI component code for internationalization.

## Codemod Usage

### help

Usage: `dart pub global run over_react_codemod:intl_message_migration --help`

Displays information on the command options available

### Running On A Specific directory

You may run this codemod on a specific directory by specifying them as arguments:

`dart pub global run over_react_codemod:intl_message_migration lib/src/myFolder --yes-to-all --migrate-constants --prune-unused
`

### Ignoring Codemod Suggestions

Some of the changes provided by the codemods in this package are based on imperfect heuristics (e.g. looking for a specific naming convention) and consequently may be susceptible to false positives. If you hit such a case in your codebase, you can tell the codemod to ignore a certain line by attaching an ignore comment either on the same line, the immediately preceding line or you can specify that an entire file should be ignored.

#### Example of Ignoring Specific Lines

```javascript
// ignore_statement: intl_message_migration
const String createBtnAutomationId = 'Shell.Drawer.Assessments.Header.Ribbon.CreateBtn';
// ignore_statement: intl_message_migration
const String createModalAutomationId = 'Shell.Drawer.Assessments.Modal.Create';
```

#### Example of Ignoring Entire File

```javascript
// ignore_file: intl_message_migration
import 'package:built_collection/built_collection.dart';
import 'package:graph_template_creation_api/publishing_data_types/f_artifact_identifier.dart' as gtcs;
import 'package:graph_template_creation_api/publishing_data_types/f_sem_ver.dart';
```

#### Code Reviewer's Guide

This codemod is capable of producing undesired changes that should be corrected prior to merge.

The most common issues found when reviewing the output from this codemod are:

- The naming of a lookup field may not be as clear as possible
- The codemod may attempt to modify a string that should not be changed, like a string used as an identifier
- The codemod may attempt to take a multi-line string segment and collapse it down to a single one

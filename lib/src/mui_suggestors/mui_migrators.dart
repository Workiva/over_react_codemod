import 'package:codemod/codemod.dart';
import 'package:over_react_codemod/src/mui_suggestors/mui_button_group_migrator.dart';
import 'package:over_react_codemod/src/mui_suggestors/mui_button_migrator.dart';
import 'package:over_react_codemod/src/mui_suggestors/mui_button_toolbar_migrator.dart';

final muiMigrators = <String, Suggestor>{
  'Button': MuiButtonMigrator(),
  'ButtonGroup': MuiButtonGroupMigrator(),
  'ButtonToolbar': MuiButtonToolbarMigrator(),
};

// Copyright 2021 Workiva Inc.
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

import 'package:over_react_codemod/src/util/unused_import_remover.dart';
import 'package:test/test.dart';

import '../resolved_file_context.dart';
import '../util.dart';

void main() {
  group('unusedWsdImportRemover', () {
    final resolvedContext = SharedAnalysisContext.wsd;

    // Warm up analysis in a setUpAll so that if getting the resolved AST times out
    // (which is more common for the WSD context), it fails here instead of failing the first test.
    setUpAll(resolvedContext.warmUpAnalysis);

    final testSuggestor = getSuggestorTester(
      unusedImportRemoverSuggestorBuilder('web_skin_dart'),
      resolvedContext: resolvedContext,
    );

    test('does nothing when there are no imports', () async {
      await testSuggestor(input: '');
    });

    test('does nothing for unused non-WSD imports', () async {
      await testSuggestor(
        input: /*language=dart*/ '''
            import 'package:over_react/over_react.dart';
        ''',
      );
    });

    group('removes unused WSD imports in a file', () {
      test('when there are imports before it', () async {
        await testSuggestor(
          input: /*language=dart*/ '''
              import 'package:over_react/over_react.dart';
              import 'package:web_skin_dart/ui_components.dart';
          
              content() => Dom.div()();
          ''',
          expectedOutput: /*language=dart*/ '''
              import 'package:over_react/over_react.dart';
          
              content() => Dom.div()();
          ''',
        );
      });

      test('when it is the first import and token', () async {
        await testSuggestor(
          input: /*language=dart*/ '''
              import 'package:web_skin_dart/ui_components.dart';
              import 'package:over_react/over_react.dart';
          
              content() => Dom.div()();
          ''',
          expectedOutput: /*language=dart*/ '''
              import 'package:over_react/over_react.dart';
          
              content() => Dom.div()();
          ''',
        );
      });

      test('when it is the first import', () async {
        await testSuggestor(
          input: /*language=dart*/ '''
              library lib;
          
              import 'package:web_skin_dart/ui_components.dart';
              import 'package:over_react/over_react.dart';
          
              content() => Dom.div()();
          ''',
          expectedOutput: /*language=dart*/ '''
              library lib;
              
              import 'package:over_react/over_react.dart';
          
              content() => Dom.div()();
          ''',
        );
      });

      test('unless they are in use', () async {
        await testSuggestor(
          input: /*language=dart*/ '''
              import 'package:over_react/over_react.dart';
              import 'package:web_skin_dart/ui_components.dart';
          
              content() => Button()();
          ''',
        );
      });

      test('when only some are unused', () async {
        await testSuggestor(
          input: /*language=dart*/ '''
              import 'package:over_react/over_react.dart';
              import 'package:web_skin_dart/ui_components.dart';
               import 'package:web_skin_dart/component2/action_group.dart'; import 'package:web_skin_dart/component2/alert.dart'; import 'package:web_skin_dart/component2/autosize_textarea.dart'; import 'package:web_skin_dart/component2/avatar.dart'; import 'package:web_skin_dart/component2/badge.dart'; import 'package:web_skin_dart/component2/block.dart'; import 'package:web_skin_dart/component2/block_content.dart'; import 'package:web_skin_dart/component2/breadcrumb.dart'; import 'package:web_skin_dart/component2/breadcrumb_nav.dart'; import 'package:web_skin_dart/component2/breadcrumb_nav_collapse.dart'; import 'package:web_skin_dart/component2/button_toolbar.dart'; import 'package:web_skin_dart/component2/callout_modal.dart'; import 'package:web_skin_dart/component2/card.dart'; import 'package:web_skin_dart/component2/card_block.dart'; import 'package:web_skin_dart/component2/card_collapse.dart'; import 'package:web_skin_dart/component2/card_deck.dart'; import 'package:web_skin_dart/component2/card_group.dart'; import 'package:web_skin_dart/component2/card_header.dart'; import 'package:web_skin_dart/component2/card_header_actions.dart'; import 'package:web_skin_dart/component2/checkbox_input.dart'; import 'package:web_skin_dart/component2/checkbox_input_group.dart'; import 'package:web_skin_dart/component2/checkbox_input_primitive.dart'; import 'package:web_skin_dart/component2/checkbox_select_option.dart'; import 'package:web_skin_dart/component2/close_button.dart'; import 'package:web_skin_dart/component2/collapsible.dart'; import 'package:web_skin_dart/component2/color_picker.dart'; import 'package:web_skin_dart/component2/color_picker_swatch.dart'; import 'package:web_skin_dart/component2/color_swatch_indicator.dart'; import 'package:web_skin_dart/component2/combo_box.dart'; import 'package:web_skin_dart/component2/datepicker.dart'; import 'package:web_skin_dart/component2/datepicker_input.dart'; import 'package:web_skin_dart/component2/dialog.dart'; import 'package:web_skin_dart/component2/dialog_trigger.dart'; import 'package:web_skin_dart/component2/direct_mentions.dart'; import 'package:web_skin_dart/component2/dnd.dart'; import 'package:web_skin_dart/component2/drop_target_file_input.dart'; import 'package:web_skin_dart/component2/drop_target_indicator.dart'; import 'package:web_skin_dart/component2/drop_target_trigger.dart'; import 'package:web_skin_dart/component2/dropdown_box.dart'; import 'package:web_skin_dart/component2/dropdown_breadcrumb.dart'; import 'package:web_skin_dart/component2/dropdown_menu.dart';  import 'package:web_skin_dart/component2/dropdown_typeahead_select.dart'; import 'package:web_skin_dart/component2/empty_view.dart'; import 'package:web_skin_dart/component2/file_drop_target.dart'; import 'package:web_skin_dart/component2/file_input.dart'; import 'package:web_skin_dart/component2/filterable_dropdown_menu.dart'; import 'package:web_skin_dart/component2/footer_block.dart'; import 'package:web_skin_dart/component2/form.dart'; import 'package:web_skin_dart/component2/form_group.dart'; import 'package:web_skin_dart/component2/form_layout.dart'; import 'package:web_skin_dart/component2/grid_container.dart'; import 'package:web_skin_dart/component2/grid_frame.dart'; import 'package:web_skin_dart/component2/hint.dart'; import 'package:web_skin_dart/component2/hitarea.dart'; import 'package:web_skin_dart/component2/icon.dart'; import 'package:web_skin_dart/component2/label.dart'; import 'package:web_skin_dart/component2/lightbox.dart'; import 'package:web_skin_dart/component2/lightbox_trigger.dart'; import 'package:web_skin_dart/component2/list_group.dart'; import 'package:web_skin_dart/component2/loading_message.dart'; import 'package:web_skin_dart/component2/menu_item.dart'; import 'package:web_skin_dart/component2/modal.dart'; import 'package:web_skin_dart/component2/multi_color_picker.dart'; import 'package:web_skin_dart/component2/nav.dart'; import 'package:web_skin_dart/component2/nav_collection.dart'; import 'package:web_skin_dart/component2/nav_item.dart'; import 'package:web_skin_dart/component2/navbar.dart'; import 'package:web_skin_dart/component2/overlay_trigger.dart'; import 'package:web_skin_dart/component2/page_item.dart'; import 'package:web_skin_dart/component2/pager.dart'; import 'package:web_skin_dart/component2/popover.dart'; import 'package:web_skin_dart/component2/popover_menu.dart'; import 'package:web_skin_dart/component2/progress_bar.dart'; import 'package:web_skin_dart/component2/progress_pie.dart'; import 'package:web_skin_dart/component2/progress_spinner.dart'; import 'package:web_skin_dart/component2/radio_input.dart'; import 'package:web_skin_dart/component2/radio_input_primitive.dart'; import 'package:web_skin_dart/component2/radio_select_option.dart'; import 'package:web_skin_dart/component2/region.dart'; import 'package:web_skin_dart/component2/region_collapse.dart'; import 'package:web_skin_dart/component2/region_header.dart'; import 'package:web_skin_dart/component2/region_header_actions.dart'; import 'package:web_skin_dart/component2/search_input.dart'; import 'package:web_skin_dart/component2/select_input.dart'; import 'package:web_skin_dart/component2/select_option.dart'; import 'package:web_skin_dart/component2/shared.dart'; import 'package:web_skin_dart/component2/submenu.dart'; import 'package:web_skin_dart/component2/subnav.dart'; import 'package:web_skin_dart/component2/switch.dart'; import 'package:web_skin_dart/component2/tab_pane.dart'; import 'package:web_skin_dart/component2/tabbable_area.dart'; import 'package:web_skin_dart/component2/table.dart'; import 'package:web_skin_dart/component2/text_area.dart'; import 'package:web_skin_dart/component2/text_input.dart'; import 'package:web_skin_dart/component2/toolbar.dart'; import 'package:web_skin_dart/component2/tooltip.dart';
          
              content() => wsd2.Button()();
          ''',
          expectedOutput: /*language=dart*/ '''
              import 'package:over_react/over_react.dart';
               import 'package:web_skin_dart/component2/action_group.dart'; import 'package:web_skin_dart/component2/alert.dart'; import 'package:web_skin_dart/component2/autosize_textarea.dart'; import 'package:web_skin_dart/component2/avatar.dart'; import 'package:web_skin_dart/component2/badge.dart'; import 'package:web_skin_dart/component2/block.dart'; import 'package:web_skin_dart/component2/block_content.dart'; import 'package:web_skin_dart/component2/breadcrumb.dart'; import 'package:web_skin_dart/component2/breadcrumb_nav.dart'; import 'package:web_skin_dart/component2/breadcrumb_nav_collapse.dart'; import 'package:web_skin_dart/component2/button_toolbar.dart'; import 'package:web_skin_dart/component2/callout_modal.dart'; import 'package:web_skin_dart/component2/card.dart'; import 'package:web_skin_dart/component2/card_block.dart'; import 'package:web_skin_dart/component2/card_collapse.dart'; import 'package:web_skin_dart/component2/card_deck.dart'; import 'package:web_skin_dart/component2/card_group.dart'; import 'package:web_skin_dart/component2/card_header.dart'; import 'package:web_skin_dart/component2/card_header_actions.dart'; import 'package:web_skin_dart/component2/checkbox_input.dart'; import 'package:web_skin_dart/component2/checkbox_input_group.dart'; import 'package:web_skin_dart/component2/checkbox_input_primitive.dart'; import 'package:web_skin_dart/component2/checkbox_select_option.dart'; import 'package:web_skin_dart/component2/close_button.dart'; import 'package:web_skin_dart/component2/collapsible.dart'; import 'package:web_skin_dart/component2/color_picker.dart'; import 'package:web_skin_dart/component2/color_picker_swatch.dart'; import 'package:web_skin_dart/component2/color_swatch_indicator.dart'; import 'package:web_skin_dart/component2/combo_box.dart'; import 'package:web_skin_dart/component2/datepicker.dart'; import 'package:web_skin_dart/component2/datepicker_input.dart'; import 'package:web_skin_dart/component2/dialog.dart'; import 'package:web_skin_dart/component2/dialog_trigger.dart'; import 'package:web_skin_dart/component2/direct_mentions.dart'; import 'package:web_skin_dart/component2/dnd.dart'; import 'package:web_skin_dart/component2/drop_target_file_input.dart'; import 'package:web_skin_dart/component2/drop_target_indicator.dart'; import 'package:web_skin_dart/component2/drop_target_trigger.dart'; import 'package:web_skin_dart/component2/dropdown_box.dart'; import 'package:web_skin_dart/component2/dropdown_breadcrumb.dart'; import 'package:web_skin_dart/component2/dropdown_menu.dart';  import 'package:web_skin_dart/component2/dropdown_typeahead_select.dart'; import 'package:web_skin_dart/component2/empty_view.dart'; import 'package:web_skin_dart/component2/file_drop_target.dart'; import 'package:web_skin_dart/component2/file_input.dart'; import 'package:web_skin_dart/component2/filterable_dropdown_menu.dart'; import 'package:web_skin_dart/component2/footer_block.dart'; import 'package:web_skin_dart/component2/form.dart'; import 'package:web_skin_dart/component2/form_group.dart'; import 'package:web_skin_dart/component2/form_layout.dart'; import 'package:web_skin_dart/component2/grid_container.dart'; import 'package:web_skin_dart/component2/grid_frame.dart'; import 'package:web_skin_dart/component2/hint.dart'; import 'package:web_skin_dart/component2/hitarea.dart'; import 'package:web_skin_dart/component2/icon.dart'; import 'package:web_skin_dart/component2/label.dart'; import 'package:web_skin_dart/component2/lightbox.dart'; import 'package:web_skin_dart/component2/lightbox_trigger.dart'; import 'package:web_skin_dart/component2/list_group.dart'; import 'package:web_skin_dart/component2/loading_message.dart'; import 'package:web_skin_dart/component2/menu_item.dart'; import 'package:web_skin_dart/component2/modal.dart'; import 'package:web_skin_dart/component2/multi_color_picker.dart'; import 'package:web_skin_dart/component2/nav.dart'; import 'package:web_skin_dart/component2/nav_collection.dart'; import 'package:web_skin_dart/component2/nav_item.dart'; import 'package:web_skin_dart/component2/navbar.dart'; import 'package:web_skin_dart/component2/overlay_trigger.dart'; import 'package:web_skin_dart/component2/page_item.dart'; import 'package:web_skin_dart/component2/pager.dart'; import 'package:web_skin_dart/component2/popover.dart'; import 'package:web_skin_dart/component2/popover_menu.dart'; import 'package:web_skin_dart/component2/progress_bar.dart'; import 'package:web_skin_dart/component2/progress_pie.dart'; import 'package:web_skin_dart/component2/progress_spinner.dart'; import 'package:web_skin_dart/component2/radio_input.dart'; import 'package:web_skin_dart/component2/radio_input_primitive.dart'; import 'package:web_skin_dart/component2/radio_select_option.dart'; import 'package:web_skin_dart/component2/region.dart'; import 'package:web_skin_dart/component2/region_collapse.dart'; import 'package:web_skin_dart/component2/region_header.dart'; import 'package:web_skin_dart/component2/region_header_actions.dart'; import 'package:web_skin_dart/component2/search_input.dart'; import 'package:web_skin_dart/component2/select_input.dart'; import 'package:web_skin_dart/component2/select_option.dart'; import 'package:web_skin_dart/component2/shared.dart'; import 'package:web_skin_dart/component2/submenu.dart'; import 'package:web_skin_dart/component2/subnav.dart'; import 'package:web_skin_dart/component2/switch.dart'; import 'package:web_skin_dart/component2/tab_pane.dart'; import 'package:web_skin_dart/component2/tabbable_area.dart'; import 'package:web_skin_dart/component2/table.dart'; import 'package:web_skin_dart/component2/text_area.dart'; import 'package:web_skin_dart/component2/text_input.dart'; import 'package:web_skin_dart/component2/toolbar.dart'; import 'package:web_skin_dart/component2/tooltip.dart';
          
              content() => wsd2.Button()();
          ''',
        );
      });

      test('for a different package name', () async {
        final testSuggestor = getSuggestorTester(
          unusedImportRemoverSuggestorBuilder('over_react'),
          resolvedContext: resolvedContext,
        );
        await testSuggestor(
          input: /*language=dart*/ '''
              import 'package:over_react/over_react.dart';
              import 'package:web_skin_dart/ui_components.dart';
               import 'package:web_skin_dart/component2/action_group.dart'; import 'package:web_skin_dart/component2/alert.dart'; import 'package:web_skin_dart/component2/autosize_textarea.dart'; import 'package:web_skin_dart/component2/avatar.dart'; import 'package:web_skin_dart/component2/badge.dart'; import 'package:web_skin_dart/component2/block.dart'; import 'package:web_skin_dart/component2/block_content.dart'; import 'package:web_skin_dart/component2/breadcrumb.dart'; import 'package:web_skin_dart/component2/breadcrumb_nav.dart'; import 'package:web_skin_dart/component2/breadcrumb_nav_collapse.dart'; import 'package:web_skin_dart/component2/button_toolbar.dart'; import 'package:web_skin_dart/component2/callout_modal.dart'; import 'package:web_skin_dart/component2/card.dart'; import 'package:web_skin_dart/component2/card_block.dart'; import 'package:web_skin_dart/component2/card_collapse.dart'; import 'package:web_skin_dart/component2/card_deck.dart'; import 'package:web_skin_dart/component2/card_group.dart'; import 'package:web_skin_dart/component2/card_header.dart'; import 'package:web_skin_dart/component2/card_header_actions.dart'; import 'package:web_skin_dart/component2/checkbox_input.dart'; import 'package:web_skin_dart/component2/checkbox_input_group.dart'; import 'package:web_skin_dart/component2/checkbox_input_primitive.dart'; import 'package:web_skin_dart/component2/checkbox_select_option.dart'; import 'package:web_skin_dart/component2/close_button.dart'; import 'package:web_skin_dart/component2/collapsible.dart'; import 'package:web_skin_dart/component2/color_picker.dart'; import 'package:web_skin_dart/component2/color_picker_swatch.dart'; import 'package:web_skin_dart/component2/color_swatch_indicator.dart'; import 'package:web_skin_dart/component2/combo_box.dart'; import 'package:web_skin_dart/component2/datepicker.dart'; import 'package:web_skin_dart/component2/datepicker_input.dart'; import 'package:web_skin_dart/component2/dialog.dart'; import 'package:web_skin_dart/component2/dialog_trigger.dart'; import 'package:web_skin_dart/component2/direct_mentions.dart'; import 'package:web_skin_dart/component2/dnd.dart'; import 'package:web_skin_dart/component2/drop_target_file_input.dart'; import 'package:web_skin_dart/component2/drop_target_indicator.dart'; import 'package:web_skin_dart/component2/drop_target_trigger.dart'; import 'package:web_skin_dart/component2/dropdown_box.dart'; import 'package:web_skin_dart/component2/dropdown_breadcrumb.dart'; import 'package:web_skin_dart/component2/dropdown_menu.dart';  import 'package:web_skin_dart/component2/dropdown_typeahead_select.dart'; import 'package:web_skin_dart/component2/empty_view.dart'; import 'package:web_skin_dart/component2/file_drop_target.dart'; import 'package:web_skin_dart/component2/file_input.dart'; import 'package:web_skin_dart/component2/filterable_dropdown_menu.dart'; import 'package:web_skin_dart/component2/footer_block.dart'; import 'package:web_skin_dart/component2/form.dart'; import 'package:web_skin_dart/component2/form_group.dart'; import 'package:web_skin_dart/component2/form_layout.dart'; import 'package:web_skin_dart/component2/grid_container.dart'; import 'package:web_skin_dart/component2/grid_frame.dart'; import 'package:web_skin_dart/component2/hint.dart'; import 'package:web_skin_dart/component2/hitarea.dart'; import 'package:web_skin_dart/component2/icon.dart'; import 'package:web_skin_dart/component2/label.dart'; import 'package:web_skin_dart/component2/lightbox.dart'; import 'package:web_skin_dart/component2/lightbox_trigger.dart'; import 'package:web_skin_dart/component2/list_group.dart'; import 'package:web_skin_dart/component2/loading_message.dart'; import 'package:web_skin_dart/component2/menu_item.dart'; import 'package:web_skin_dart/component2/modal.dart'; import 'package:web_skin_dart/component2/multi_color_picker.dart'; import 'package:web_skin_dart/component2/nav.dart'; import 'package:web_skin_dart/component2/nav_collection.dart'; import 'package:web_skin_dart/component2/nav_item.dart'; import 'package:web_skin_dart/component2/navbar.dart'; import 'package:web_skin_dart/component2/overlay_trigger.dart'; import 'package:web_skin_dart/component2/page_item.dart'; import 'package:web_skin_dart/component2/pager.dart'; import 'package:web_skin_dart/component2/popover.dart'; import 'package:web_skin_dart/component2/popover_menu.dart'; import 'package:web_skin_dart/component2/progress_bar.dart'; import 'package:web_skin_dart/component2/progress_pie.dart'; import 'package:web_skin_dart/component2/progress_spinner.dart'; import 'package:web_skin_dart/component2/radio_input.dart'; import 'package:web_skin_dart/component2/radio_input_primitive.dart'; import 'package:web_skin_dart/component2/radio_select_option.dart'; import 'package:web_skin_dart/component2/region.dart'; import 'package:web_skin_dart/component2/region_collapse.dart'; import 'package:web_skin_dart/component2/region_header.dart'; import 'package:web_skin_dart/component2/region_header_actions.dart'; import 'package:web_skin_dart/component2/search_input.dart'; import 'package:web_skin_dart/component2/select_input.dart'; import 'package:web_skin_dart/component2/select_option.dart'; import 'package:web_skin_dart/component2/shared.dart'; import 'package:web_skin_dart/component2/submenu.dart'; import 'package:web_skin_dart/component2/subnav.dart'; import 'package:web_skin_dart/component2/switch.dart'; import 'package:web_skin_dart/component2/tab_pane.dart'; import 'package:web_skin_dart/component2/tabbable_area.dart'; import 'package:web_skin_dart/component2/table.dart'; import 'package:web_skin_dart/component2/text_area.dart'; import 'package:web_skin_dart/component2/text_input.dart'; import 'package:web_skin_dart/component2/toolbar.dart'; import 'package:web_skin_dart/component2/tooltip.dart';
          
              content() => wsd2.Button()();
          ''',
          expectedOutput: /*language=dart*/ '''
              import 'package:web_skin_dart/ui_components.dart';
               import 'package:web_skin_dart/component2/action_group.dart'; import 'package:web_skin_dart/component2/alert.dart'; import 'package:web_skin_dart/component2/autosize_textarea.dart'; import 'package:web_skin_dart/component2/avatar.dart'; import 'package:web_skin_dart/component2/badge.dart'; import 'package:web_skin_dart/component2/block.dart'; import 'package:web_skin_dart/component2/block_content.dart'; import 'package:web_skin_dart/component2/breadcrumb.dart'; import 'package:web_skin_dart/component2/breadcrumb_nav.dart'; import 'package:web_skin_dart/component2/breadcrumb_nav_collapse.dart'; import 'package:web_skin_dart/component2/button_toolbar.dart'; import 'package:web_skin_dart/component2/callout_modal.dart'; import 'package:web_skin_dart/component2/card.dart'; import 'package:web_skin_dart/component2/card_block.dart'; import 'package:web_skin_dart/component2/card_collapse.dart'; import 'package:web_skin_dart/component2/card_deck.dart'; import 'package:web_skin_dart/component2/card_group.dart'; import 'package:web_skin_dart/component2/card_header.dart'; import 'package:web_skin_dart/component2/card_header_actions.dart'; import 'package:web_skin_dart/component2/checkbox_input.dart'; import 'package:web_skin_dart/component2/checkbox_input_group.dart'; import 'package:web_skin_dart/component2/checkbox_input_primitive.dart'; import 'package:web_skin_dart/component2/checkbox_select_option.dart'; import 'package:web_skin_dart/component2/close_button.dart'; import 'package:web_skin_dart/component2/collapsible.dart'; import 'package:web_skin_dart/component2/color_picker.dart'; import 'package:web_skin_dart/component2/color_picker_swatch.dart'; import 'package:web_skin_dart/component2/color_swatch_indicator.dart'; import 'package:web_skin_dart/component2/combo_box.dart'; import 'package:web_skin_dart/component2/datepicker.dart'; import 'package:web_skin_dart/component2/datepicker_input.dart'; import 'package:web_skin_dart/component2/dialog.dart'; import 'package:web_skin_dart/component2/dialog_trigger.dart'; import 'package:web_skin_dart/component2/direct_mentions.dart'; import 'package:web_skin_dart/component2/dnd.dart'; import 'package:web_skin_dart/component2/drop_target_file_input.dart'; import 'package:web_skin_dart/component2/drop_target_indicator.dart'; import 'package:web_skin_dart/component2/drop_target_trigger.dart'; import 'package:web_skin_dart/component2/dropdown_box.dart'; import 'package:web_skin_dart/component2/dropdown_breadcrumb.dart'; import 'package:web_skin_dart/component2/dropdown_menu.dart';  import 'package:web_skin_dart/component2/dropdown_typeahead_select.dart'; import 'package:web_skin_dart/component2/empty_view.dart'; import 'package:web_skin_dart/component2/file_drop_target.dart'; import 'package:web_skin_dart/component2/file_input.dart'; import 'package:web_skin_dart/component2/filterable_dropdown_menu.dart'; import 'package:web_skin_dart/component2/footer_block.dart'; import 'package:web_skin_dart/component2/form.dart'; import 'package:web_skin_dart/component2/form_group.dart'; import 'package:web_skin_dart/component2/form_layout.dart'; import 'package:web_skin_dart/component2/grid_container.dart'; import 'package:web_skin_dart/component2/grid_frame.dart'; import 'package:web_skin_dart/component2/hint.dart'; import 'package:web_skin_dart/component2/hitarea.dart'; import 'package:web_skin_dart/component2/icon.dart'; import 'package:web_skin_dart/component2/label.dart'; import 'package:web_skin_dart/component2/lightbox.dart'; import 'package:web_skin_dart/component2/lightbox_trigger.dart'; import 'package:web_skin_dart/component2/list_group.dart'; import 'package:web_skin_dart/component2/loading_message.dart'; import 'package:web_skin_dart/component2/menu_item.dart'; import 'package:web_skin_dart/component2/modal.dart'; import 'package:web_skin_dart/component2/multi_color_picker.dart'; import 'package:web_skin_dart/component2/nav.dart'; import 'package:web_skin_dart/component2/nav_collection.dart'; import 'package:web_skin_dart/component2/nav_item.dart'; import 'package:web_skin_dart/component2/navbar.dart'; import 'package:web_skin_dart/component2/overlay_trigger.dart'; import 'package:web_skin_dart/component2/page_item.dart'; import 'package:web_skin_dart/component2/pager.dart'; import 'package:web_skin_dart/component2/popover.dart'; import 'package:web_skin_dart/component2/popover_menu.dart'; import 'package:web_skin_dart/component2/progress_bar.dart'; import 'package:web_skin_dart/component2/progress_pie.dart'; import 'package:web_skin_dart/component2/progress_spinner.dart'; import 'package:web_skin_dart/component2/radio_input.dart'; import 'package:web_skin_dart/component2/radio_input_primitive.dart'; import 'package:web_skin_dart/component2/radio_select_option.dart'; import 'package:web_skin_dart/component2/region.dart'; import 'package:web_skin_dart/component2/region_collapse.dart'; import 'package:web_skin_dart/component2/region_header.dart'; import 'package:web_skin_dart/component2/region_header_actions.dart'; import 'package:web_skin_dart/component2/search_input.dart'; import 'package:web_skin_dart/component2/select_input.dart'; import 'package:web_skin_dart/component2/select_option.dart'; import 'package:web_skin_dart/component2/shared.dart'; import 'package:web_skin_dart/component2/submenu.dart'; import 'package:web_skin_dart/component2/subnav.dart'; import 'package:web_skin_dart/component2/switch.dart'; import 'package:web_skin_dart/component2/tab_pane.dart'; import 'package:web_skin_dart/component2/tabbable_area.dart'; import 'package:web_skin_dart/component2/table.dart'; import 'package:web_skin_dart/component2/text_area.dart'; import 'package:web_skin_dart/component2/text_input.dart'; import 'package:web_skin_dart/component2/toolbar.dart'; import 'package:web_skin_dart/component2/tooltip.dart';
          
              content() => wsd2.Button()();
          ''',
        );
      });
    });
  }, tags: 'wsd');
}

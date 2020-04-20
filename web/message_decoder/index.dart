import 'dart:html';

import 'package:over_react_codemod/src/coded_messages.dart';

main() {
  String contents;
  String error;

  final contentNode = querySelector('#content');

  try {
    final queryParameters = Uri.parse(window.location.href).queryParameters;
    if (queryParameters.isEmpty) {
      return;
    } else {
      contents =
          CodedMessage.summaryAndDetailsStringFromQueryParams(queryParameters);
    }
  } catch (e) {
    error = e.toString();
  }

  if (contents != null) {
    contentNode
      ..classes.add('jumbotron')
      ..append(HeadingElement.h4()..appendText('Decoded message:'))
      ..append(
        Element.pre()
          ..append(
            Element.tag('code')
              ..appendText(contents),
          ),
      );
  } else {
    contentNode.append(
      Element.div()
        ..className = 'alert alert-danger decode-error-message'
        ..attributes['role'] = 'alert'
        ..appendText(error),
    );
  }
}

import "package:react/react.dart" as react;
import "package:react/react_dom.dart" as react_dom;
import "package:react/react_client.dart";
import "dart:html";

void main() {
  setClientConfiguration();

  var instance = react_dom.render(react.div()(
    "Hello!"
  ), querySelector('#content'));
}
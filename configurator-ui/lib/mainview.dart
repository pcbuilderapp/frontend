import 'dart:html';
import 'package:uilib/view.dart';
import 'pcbuilder.dart';
import 'package:pcbuilder.api/transport/configuration.dart';
import 'package:pcbuilder.api/transport/componentitem.dart';

class MainView extends View {
  static String get id => "mainview";

  MainView() {
    _view = querySelector("#mainview");
    Element template = _view.querySelector(".componentItem");
    _componentItem = template.clone(true);
    template.remove();

    // maak component types
    Element componentContainer = querySelector("#pcconfiglist");
    List<String> components = [
      "Motherboard",
      "CPU",
      "GPU",
      "Memory",
      "Storage",
      "PSU",
      "Case"
    ];
    for (String component in components) {
      Element e = _componentItem.clone(true);

      e.querySelector(".type").text = component;
      e.onClick.listen((_) async {
        ComponentItem c = await pcbuilder.selectComponentView
            .selectComponent(component, _configuration);
        pcbuilder.setView(MainView.id);

        if (component == "Motherboard") {
          _configuration.motherboard = c;
        } else if (component == "CPU") {
          _configuration.cpu = c;
        } else if (component == "GPU") {
          _configuration.gpu = c;
        } else if (component == "Memory") {
          _configuration.memory = c;
        } else if (component == "Storage") {
          _configuration.storage = c;
        } else if (component == "PSU") {
          _configuration.psu= c;
        } else if (component == "Case") {
          _configuration.casing = c;
        }

        e.querySelector(".name").text = c.name;
        e.querySelector(".price p").text = "€ ${c.price}";
        e.querySelector(".image").style.backgroundImage = "url(${c.image})";

        // update price
        double price = _configuration.priceTotal();
        if (price == 0.0) {
          querySelector("#pricetotal span").text = "0.-";
        } else {
          querySelector("#pricetotal span").text = price.toStringAsFixed(2);
        }
      });

      componentContainer.append(e);
    }
  }

  Element get element => _view;

  Element _view;
  Element _componentItem;
  Map<String, Element> _components;
  Configuration _configuration = new Configuration();
}

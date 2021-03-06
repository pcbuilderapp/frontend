import 'package:uilib/view.dart';
import 'dart:html';
import 'dart:async';
import 'package:pcbuilder.api/config.dart';
import 'package:pcbuilder.api/transport/productsearch.dart';
import 'package:pcbuilder.api/transport/productsresponse.dart';
import 'package:pcbuilder.api/domain/product.dart';
import 'package:pcbuilder.api/backend.dart';
import 'package:uilib/util.dart';
import 'package:uilib/charts.dart';
import 'package:pcbuilder.api/transport/pricehistoryresponse.dart';
import 'package:pcbuilder.api/transport/pricehistoryrequest.dart';

/// The product view lists all the products crawled.

class ProductView extends View {
  Element _viewElement = querySelector("#productview");
  Element _productItem;
  Element _productList;
  Element _productInfo;
  Element _pager;
  InputElement _filterField;
  String _currentFilter="";
  String _currentSort;
  int _currentPage;
  int _pageCount;
  int pageWidth = config["page-width"] ?? 5;

  /// Get view id.
  ///
  /// Get the identifier for this view.

  static String get id => "productview";

  /// Product view constructor.
  ///
  /// Initializes the view.

  ProductView() {
    Element template = _viewElement.querySelector(".productItem");
    _productItem = template.clone(true);
    template.remove();
    _filterField = _viewElement.querySelector(".searchbar input") as InputElement;
    _filterField.onSearch.listen((_) {
      filter(_filterField.value);
    });

    _productInfo = _viewElement.querySelector(".productInfo");

    _productList = _viewElement.querySelector("#productList");
    (_viewElement.querySelector(".searchbar form") as FormElement)
        .onSubmit
        .listen((Event e) {
      filter(_filterField.value);
      e.preventDefault();
    });
    
    _viewElement.querySelector("thead .name").onClick.listen((MouseEvent e) {
      setSort("name");
    });
    _viewElement.querySelector("thead .shop").onClick.listen((MouseEvent e) {
      setSort("shop");
    });
    _viewElement.querySelector("thead .type").onClick.listen((MouseEvent e) {
      setSort("type");
    });
    _viewElement.querySelector("thead .price").onClick.listen((MouseEvent e) {
      setSort("price");
    });

    _pager = _viewElement.querySelector(".pager");
    _pager.querySelector(".previous").onClick.listen((_) {
      if (_currentPage <= 1) return;
      loadProducts(_currentPage - 1);
    });

    _pager.querySelector(".next").onClick.listen((_) {
      if (_currentPage >= _pageCount) return;
      loadProducts(_currentPage + 1);
    });

    loadProducts(0);
  }

  /// onShow event
  ///
  /// Event triggered when this view becomes the active view.

  void onShow() {
    querySelector("#productsNav").classes.add("active");
  }

  /// onHide event
  ///
  /// Event triggered when this view is no longer active.

  void onHide() {
    querySelector("#productsNav").classes.remove("active");
  }

  /// Load products.
  ///
  /// Get all the products with set filters for page [page].

  Future loadProducts(int page) async {
    // show load indicator
    _viewElement.querySelector(".content").style.display = "none";
    _viewElement.querySelector(".loading").style.display = "block";

    ProductSearch productSearch = new ProductSearch();
    productSearch.filter = _currentFilter;
    productSearch.page = page;
    productSearch.maxItems = config["max-items"] ?? 30;
    productSearch.sort = _currentSort;

    ProductsResponse productSearchResponse =
    await backend.getProducts(productSearch);

    _productList.innerHtml = "";

    // generate product list
    for (Product p in productSearchResponse.products) {
      _productList.append(createProductElement(p));
    }

    // set paging
    _currentPage = productSearchResponse.page;
    _pageCount = productSearchResponse.pageCount;
    createPaging(productSearchResponse);

    // hide load indicator
    _viewElement.querySelector(".content").style.display = "block";
    _viewElement.querySelector(".loading").style.display = "none";
  }

  /// Create paging
  ///
  /// Update the pager with the current page index and count.

  void createPaging(ProductsResponse productSearchResponse) {
    Element pages = _pager.querySelector(".pages");
    pages.innerHtml = "";

    bool lastAddedPoints = false;

    for (int i = 0; i < productSearchResponse.pageCount; i++) {
      if (showpage(i, productSearchResponse.page, pageWidth,
          productSearchResponse.pageCount - 1)) {
        Element pagebtn = new Element.div();
        pagebtn.text = "${i + 1}";
        pagebtn.classes.add("pagebtn");

        if (i == productSearchResponse.page) {
          pagebtn.classes.add("current");
        } else {
          pagebtn.onClick.listen((_) {
            loadProducts(i);
          });
        }

        pages.append(pagebtn);
        lastAddedPoints = false;
      } else {
        if (!lastAddedPoints) {
          pages.append(points());
          lastAddedPoints = true;
        }
      }
    }
  }

  /// Create product element.
  ///
  /// Create DOM element for the given [item].

  Element createProductElement(Product item) {
    Element e = _productItem.clone(true);

    // product row
    e.querySelector(".name").text = item.component.name;
    e.querySelector(".type").text = "${item.component.type}";
    e.querySelector(".shop").text = item.shop.name;
    e.querySelector(".price").text = formatCurrency(item.currentPrice);

    // actions
    e.onClick.listen((_) {
      // load details
      loadProductDetail(item);
    });

    return e;
  }

  /// Load product details
  ///
  /// Load the details for product [p] and display them.

  Future loadProductDetail(Product p) async {

    _productInfo.querySelector("h1").text = p.component.name;

    // product detail view
    _productInfo.querySelector(".info .ean-nr").text =
        p.component.europeanArticleNumber;
    _productInfo.querySelector(".info .mpn-nr").text =
        p.component.manufacturerPartNumber;
    _productInfo.querySelector(".image").style.backgroundImage =
    "url(${p.component.pictureUrl})";

    Element priceHistory = _productInfo.querySelector(".pricehistory");
    priceHistory.style.display = "block";
    priceHistory.innerHtml = "";

    PriceHistoryRequest priceHistoryRequest = new PriceHistoryRequest();
    priceHistoryRequest.componentId = p.component.id;
    priceHistoryRequest.fromDate = new DateTime.now().subtract(new Duration(days: 30));
    priceHistoryRequest.toDate = new DateTime.now();

    priceHistoryRequest.min = true;
    PriceHistoryResponse minDailyPriceViewResponse =
      await backend.getPriceHistory(priceHistoryRequest);

    priceHistoryRequest.min = false;
    PriceHistoryResponse maxDailyPriceViewResponse =
      await backend.getPriceHistory(priceHistoryRequest);

    drawPriceHistoryChart(minDailyPriceViewResponse.priceHistory, maxDailyPriceViewResponse.priceHistory, priceHistory);

    /*if (p.component.connectors.length != 0) {
      Element connectorsElement = _productInfo.querySelector(".connectors");

      for (Connector c in p.component.connectors) {
        Element connectorSpan = new Element.span()..classes.add("connector");

        Element connectorImg = new Element.span()
          ..classes.add("connector-icon-${c.type.toLowerCase()}");

        Element connectorSpanText = new Element.span()
          ..classes.add("connector-text");
        connectorSpanText.text = "${c.name} ";

        connectorSpan.append(connectorImg);
        connectorSpan.append(connectorSpanText);
        connectorsElement.append(connectorSpan);
        connectorsElement.appendText(" "); // for wraping
      }
    }*/

  }

  /// Set filter
  ///
  /// Set the current filter and fetch a new list of products
  /// filtered by [filter].

  void filter(String filter) {
    if (filter == _currentFilter) return;
    _currentFilter = filter;
    loadProducts(0);
  }

  /// Set sorting
  ///
  /// Set the current sorting and fetch a new list of products
  /// sorted by [filter].

  void setSort(String sortColumn) {
    if (sortColumn == _currentSort) return;
    _currentSort = sortColumn;
    _viewElement.querySelectorAll(".header-selected").classes.remove("header-selected");
    _viewElement.querySelector(".$sortColumn-header").classes.add("header-selected");
    loadProducts(0);
  }

  /// Get view element
  ///
  /// Get the DOM element for this view.

  Element get element => _viewElement;
}

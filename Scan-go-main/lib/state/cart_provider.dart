import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/constants/app_constants.dart';
import '../models/cart_item.dart';
import '../models/cv_event.dart';
import '../models/product.dart';
import '../services/cart_api_service.dart';
import '../services/computer_vision_service.dart';
import '../services/socket_service.dart';

class CartProvider extends ChangeNotifier {
  final ComputerVisionService? _cvService;
  final CartApiService? _cartApi;
  final ScanGoSocketService? _socket;
  StreamSubscription<CvEvent>? _cvSubscription;

  final Map<String, CartItem> _items = {};
  String? _cartCode;
  String? _sessionId;
  bool _faceVerified = false;
  double? _serverSubtotal;
  double? _serverTax;
  double? _serverTotal;
  String? _errorMessage;
  bool _loading = false;

  CartProvider({
    ComputerVisionService? cvService,
    CartApiService? cartApi,
    ScanGoSocketService? socket,
  })  : _cvService = cvService,
        _cartApi = cartApi,
        _socket = socket {
    if (_cvService != null) {
      _subscribeToCvEvents();
    }
  }

  String? get cartCode => _cartCode;
  String? get sessionId => _sessionId;
  bool get faceVerified => _faceVerified;
  bool get isPaired => _sessionId != null && _sessionId!.isNotEmpty;
  bool get isLoading => _loading;
  String? get errorMessage => _errorMessage;

  List<CartItem> get items => _items.values.toList();

  int get totalItemCount {
    return _items.values.fold(0, (sum, item) => sum + item.quantity);
  }

  bool get isEmpty => _items.isEmpty;

  double get subtotal => _serverSubtotal ?? _items.values.fold(0.0, (sum, item) => sum + item.totalPrice);

  double get tax => _serverTax ?? subtotal * AppConstants.taxRate;

  double get total => _serverTotal ?? (subtotal + tax);

  void _subscribeToCvEvents() {
    _cvSubscription = _cvService?.eventStream.listen((event) {
      switch (event.type) {
        case CvEventType.productDetected:
          if (event.product != null) {
            _addProductFromCv(event.product!);
          }
          break;
        case CvEventType.productRemoved:
          if (event.productId != null) {
            _removeProductFromCv(event.productId!);
          }
          break;
        case CvEventType.cartCleared:
          _clearCart();
          break;
      }
    });
  }

  void applySnapshot(CartSnapshot snapshot) {
    _sessionId = snapshot.sessionId;
    _cartCode = snapshot.cartCode;
    _faceVerified = snapshot.faceVerified;
    _serverSubtotal = snapshot.subtotal;
    _serverTax = snapshot.tax;
    _serverTotal = snapshot.grandTotal;
    _items.clear();
    for (final item in snapshot.items) {
      _items[item.product.id] = item;
    }
    notifyListeners();
  }

  void applySocketPayload(Map<String, dynamic> payload) {
    final cart = payload['cart'];
    if (cart is Map) {
      applySnapshot(CartSnapshot.fromJson(Map<String, dynamic>.from(cart)));
    } else if (payload.containsKey('items')) {
      applySnapshot(CartSnapshot.fromJson(payload));
    }
  }

  Future<bool> pairCart(String cartCode, {bool faceVerified = false}) async {
    if (_cartApi == null) {
      _cartCode = cartCode;
      _sessionId = 'local';
      notifyListeners();
      return true;
    }
    _loading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final snapshot = await _cartApi!.pair(cartCode: cartCode, faceVerified: faceVerified);
      if (snapshot != null) {
        applySnapshot(snapshot);
        _connectSocket();
        _loading = false;
        notifyListeners();
        return true;
      }
      _errorMessage = 'Could not pair cart.';
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    }
    _loading = false;
    notifyListeners();
    return false;
  }

  Future<void> loadActiveCart() async {
    if (_cartApi == null) return;
    try {
      final snapshot = await _cartApi!.getActive();
      if (snapshot != null) {
        applySnapshot(snapshot);
        _connectSocket();
      }
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  Future<void> removeProductCompletely(String productId) async {
    final item = _items[productId];
    if (item == null) return;

    if (_cartApi != null && item.cartItemId != null) {
      try {
        final snapshot = await _cartApi!.removeItem(cartItemId: item.cartItemId!, forceDelete: true);
        if (snapshot != null) {
          applySnapshot(snapshot);
          return;
        }
      } catch (e) {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        notifyListeners();
        return;
      }
    }

    _items.remove(productId);
    _serverSubtotal = null;
    _serverTax = null;
    _serverTotal = null;
    notifyListeners();
  }

  Future<void> simulateAiAdd(int productId) async {
    if (_cartApi == null || _cartCode == null) return;
    await _cartApi!.simulateAiDetection(cartCode: _cartCode!, productId: productId);
  }

  Future<List<Map<String, dynamic>>> fetchCatalog() async {
    if (_cartApi == null) return [];
    return _cartApi!.fetchProducts();
  }

  void _connectSocket() {
    _socket?.connect(
      userId: null,
      cartCode: _cartCode,
      onCartUpdated: applySocketPayload,
      onCheckoutCompleted: applySocketPayload,
      onFaceVerified: applySocketPayload,
    );
    if (_cartCode != null) {
      _socket?.joinCart(_cartCode!);
    }
  }

  void _addProductFromCv(Product product) {
    if (_items.containsKey(product.id)) {
      final current = _items[product.id]!;
      _items[product.id] = current.copyWith(quantity: current.quantity + 1);
    } else {
      _items[product.id] = CartItem(product: product, quantity: 1);
    }
    _serverSubtotal = null;
    _serverTax = null;
    _serverTotal = null;
    notifyListeners();
  }

  void _removeProductFromCv(String productId) {
    if (_items.containsKey(productId)) {
      final current = _items[productId]!;
      if (current.quantity > 1) {
        _items[productId] = current.copyWith(quantity: current.quantity - 1);
      } else {
        _items.remove(productId);
      }
      _serverSubtotal = null;
      _serverTax = null;
      _serverTotal = null;
      notifyListeners();
    }
  }

  void _clearCart() {
    _items.clear();
    _serverSubtotal = null;
    _serverTax = null;
    _serverTotal = null;
    notifyListeners();
  }

  void clearCart() {
    _clearCart();
    _sessionId = null;
    _cartCode = null;
    _faceVerified = false;
    _socket?.disconnect();
  }

  @override
  void dispose() {
    _cvSubscription?.cancel();
    _socket?.disconnect();
    super.dispose();
  }
}

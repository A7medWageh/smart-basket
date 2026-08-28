import '../core/constants/app_constants.dart';
import '../models/cart_item.dart';
import 'api_client.dart';

class CartSnapshot {
  final String sessionId;
  final String cartCode;
  final bool faceVerified;
  final List<CartItem> items;
  final double subtotal;
  final double tax;
  final double grandTotal;
  final int itemsCount;

  const CartSnapshot({
    required this.sessionId,
    required this.cartCode,
    required this.faceVerified,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.grandTotal,
    required this.itemsCount,
  });

  factory CartSnapshot.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = <CartItem>[];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is Map) {
          items.add(CartItem.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    return CartSnapshot(
      sessionId: json['sessionId']?.toString() ?? '',
      cartCode: json['cartCode']?.toString() ?? AppConstants.defaultCartCode,
      faceVerified: json['faceVerified'] == true,
      items: items,
      subtotal: _toDouble(json['subtotal']),
      tax: _toDouble(json['tax']),
      grandTotal: _toDouble(json['grandTotal'] ?? json['totalAmount']),
      itemsCount: json['itemsCount'] is int
          ? json['itemsCount'] as int
          : items.fold(0, (sum, item) => sum + item.quantity),
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class CartApiService {
  final ApiClient _apiClient;

  CartApiService({required ApiClient apiClient}) : _apiClient = apiClient;

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  Map<String, dynamic>? _unwrap(ApiResponse response) {
    final root = _asMap(response.data);
    if (root == null) return null;
    return _asMap(root['data']) ?? root;
  }

  Future<CartSnapshot?> pair({required String cartCode, bool faceVerified = false}) async {
    final response = await _apiClient.post(
      AppConstants.cartPairEndpoint,
      body: {
        'cartCode': cartCode,
        'faceVerified': faceVerified,
      },
    );
    if (!response.isSuccess) {
      throw Exception(response.errorMessage ?? 'Failed to pair cart');
    }
    final payload = _unwrap(response);
    if (payload == null) return null;
    return CartSnapshot.fromJson(payload);
  }

  Future<CartSnapshot?> getActive() async {
    final response = await _apiClient.get(AppConstants.cartActiveEndpoint);
    if (!response.isSuccess) {
      throw Exception(response.errorMessage ?? 'Failed to load cart');
    }
    final payload = _unwrap(response);
    if (payload == null) return null;
    return CartSnapshot.fromJson(payload);
  }

  Future<CartSnapshot?> removeItem({required String cartItemId, bool forceDelete = true}) async {
    final response = await _apiClient.post(
      AppConstants.cartRemoveItemEndpoint,
      body: {
        'cartItemId': int.tryParse(cartItemId) ?? cartItemId,
        'forceDelete': forceDelete,
      },
    );
    if (!response.isSuccess) {
      throw Exception(response.errorMessage ?? 'Failed to remove item');
    }
    final payload = _unwrap(response);
    if (payload == null) return null;
    return CartSnapshot.fromJson(payload);
  }

  Future<CartSnapshot?> addItem({int? productId, String? barcode}) async {
    final response = await _apiClient.post(
      AppConstants.cartAddItemEndpoint,
      body: {
        if (productId != null) 'productId': productId,
        if (barcode != null) 'barcode': barcode,
      },
    );
    if (!response.isSuccess) {
      throw Exception(response.errorMessage ?? 'Failed to add item');
    }
    final payload = _unwrap(response);
    if (payload == null) return null;
    return CartSnapshot.fromJson(payload);
  }

  Future<void> unpair() async {
    final response = await _apiClient.post(AppConstants.cartUnpairEndpoint, body: {});
    if (!response.isSuccess) {
      throw Exception(response.errorMessage ?? 'Failed to unpair cart');
    }
  }

  Future<CartSnapshot?> verifyFace() async {
    final response = await _apiClient.post(AppConstants.cartVerifyFaceEndpoint, body: {});
    if (!response.isSuccess) {
      throw Exception(response.errorMessage ?? 'Face verification failed');
    }
    final payload = _unwrap(response);
    if (payload == null) return null;
    return CartSnapshot.fromJson(payload);
  }

  Future<List<Map<String, dynamic>>> fetchProducts() async {
    final response = await _apiClient.get(AppConstants.productsEndpoint);
    if (!response.isSuccess) return [];
    final root = _asMap(response.data);
    final data = root?['data'];
    if (data is List) {
      return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  Future<void> simulateAiDetection({
    required String cartCode,
    required int productId,
    String action = 'added',
  }) async {
    final response = await _apiClient.post(
      AppConstants.aiDetectionEndpoint,
      body: {
        'cart_code': cartCode,
        'product_id': productId,
        'confidence': 0.99,
        'action': action,
      },
    );
    if (!response.isSuccess) {
      throw Exception(response.errorMessage ?? 'AI detection failed');
    }
  }
}

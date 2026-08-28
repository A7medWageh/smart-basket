import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';

class AppConstants {
  AppConstants._();

  static const String appName = 'ScanGo';
  static const double taxRate = 0.03;
  static const String defaultCartCode = 'CART_01';

  // Product Catalog IDs
  static const String doritosId = 'prod_doritos';
  static const String tunaId = 'prod_tuna';
  static const String honeyId = 'prod_honey';

  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  static const bool useMockServices = bool.fromEnvironment(
    'USE_MOCK_SERVICES',
    defaultValue: false,
  );

  static String _apiBaseUrl = 'https://cytoplast-courier-dandelion.ngrok-free.dev/api';

  static String get apiBaseUrl {
    if (_apiBaseUrl.isNotEmpty) return _apiBaseUrl;
    if (_envBaseUrl.isNotEmpty) {
      return _stripTrailingSlash(_envBaseUrl);
    }
    return _stripTrailingSlash(_platformDefaultBaseUrl());
  }

  static set apiBaseUrl(String url) {
    _apiBaseUrl = _stripTrailingSlash(url);
  }

  static String get socketUrl {
    final api = apiBaseUrl;
    if (api.endsWith('/api')) {
      return api.substring(0, api.length - 4);
    }
    return api;
  }

  static String _stripTrailingSlash(String url) {
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  static String _platformDefaultBaseUrl() {
    if (kIsWeb) return 'http://localhost:5001/api';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:5001/api';
    } catch (_) {}
    return 'http://127.0.0.1:5001/api';
  }

  static String get registerEndpoint => '$apiBaseUrl/auth/register';
  static String get loginEndpoint => '$apiBaseUrl/auth/login';
  static String get meEndpoint => '$apiBaseUrl/auth/me';
  static String get faceEnrollEndpoint => '$apiBaseUrl/auth/face/enroll';
  static String get faceVerifyEndpoint => '$apiBaseUrl/auth/face/verify';

  static String get productsEndpoint => '$apiBaseUrl/products';
  static String get cartPairEndpoint => '$apiBaseUrl/cart/pair';
  static String get cartActiveEndpoint => '$apiBaseUrl/cart/active';
  static String get cartAddItemEndpoint => '$apiBaseUrl/cart/add-item';
  static String get cartRemoveItemEndpoint => '$apiBaseUrl/cart/remove-item';
  static String get cartUnpairEndpoint => '$apiBaseUrl/cart/unpair';
  static String get cartVerifyFaceEndpoint => '$apiBaseUrl/cart/verify-face';

  static String get checkoutEndpoint => '$apiBaseUrl/orders/checkout';
  static String get ordersHistoryEndpoint => '$apiBaseUrl/orders/history';
  static String get aiDetectionEndpoint => '$apiBaseUrl/ai/detection';
}

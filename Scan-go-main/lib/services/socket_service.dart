import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../core/constants/app_constants.dart';

class ScanGoSocketService {
  io.Socket? _socket;

  void connect({
    required String? userId,
    String? cartCode,
    required void Function(Map<String, dynamic> payload) onCartUpdated,
    void Function(Map<String, dynamic> payload)? onCheckoutCompleted,
    void Function(Map<String, dynamic> payload)? onFaceVerified,
  }) {
    disconnect();

    _socket = io.io(
      AppConstants.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .build(),
    );

    _socket!.onConnect((_) {
      if (userId != null && userId.isNotEmpty) {
        _socket!.emit('join:user', userId);
      }
      if (cartCode != null && cartCode.isNotEmpty) {
        joinCart(cartCode);
      }
    });

    _socket!.on('cart:updated', (data) {
      final payload = _asMap(data);
      if (payload != null) onCartUpdated(payload);
    });

    _socket!.on('checkout:completed', (data) {
      final payload = _asMap(data);
      if (payload != null) onCheckoutCompleted?.call(payload);
    });

    _socket!.on('cart:face_verified', (data) {
      final payload = _asMap(data);
      if (payload != null) onFaceVerified?.call(payload);
    });

    _socket!.onConnectError((err) {
      debugPrint('Socket connect error: $err');
    });

    _socket!.connect();
  }

  void joinCart(String cartCode) {
    _socket?.emit('join:cart', cartCode);
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }

  Map<String, dynamic>? _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }
}

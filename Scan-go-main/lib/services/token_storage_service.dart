import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorageService {
  final FlutterSecureStorage _storage;
  final Map<String, String> _memoryFallback = {};

  TokenStorageService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _keyToken = 'auth_token';
  static const String _keyUserId = 'user_id';
  static const String _keySessionId = 'session_id';

  Future<void> saveToken(String token) async {
    _memoryFallback[_keyToken] = token;
    if (!kIsWeb) {
      try {
        await _storage.write(key: _keyToken, value: token);
      } catch (_) {}
    }
  }

  Future<String?> getToken() async {
    if (!kIsWeb) {
      try {
        final token = await _storage.read(key: _keyToken);
        if (token != null) return token;
      } catch (_) {}
    }
    return _memoryFallback[_keyToken];
  }

  Future<void> saveUserId(String userId) async {
    _memoryFallback[_keyUserId] = userId;
    if (!kIsWeb) {
      try {
        await _storage.write(key: _keyUserId, value: userId);
      } catch (_) {}
    }
  }

  Future<String?> getUserId() async {
    if (!kIsWeb) {
      try {
        final id = await _storage.read(key: _keyUserId);
        if (id != null) return id;
      } catch (_) {}
    }
    return _memoryFallback[_keyUserId];
  }

  Future<void> saveSessionId(String sessionId) async {
    _memoryFallback[_keySessionId] = sessionId;
    if (!kIsWeb) {
      try {
        await _storage.write(key: _keySessionId, value: sessionId);
      } catch (_) {}
    }
  }

  Future<String?> getSessionId() async {
    if (!kIsWeb) {
      try {
        final sId = await _storage.read(key: _keySessionId);
        if (sId != null) return sId;
      } catch (_) {}
    }
    return _memoryFallback[_keySessionId];
  }

  Future<void> clearAll() async {
    _memoryFallback.clear();
    if (!kIsWeb) {
      try {
        await _storage.deleteAll();
      } catch (_) {}
    }
  }
}

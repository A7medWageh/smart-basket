import 'package:flutter/foundation.dart';
import '../core/constants/app_constants.dart';
import '../models/shopping_session.dart';
import '../models/user.dart';
import '../services/auth/auth_api_service.dart';
import '../services/face_recognition_service.dart';
import '../services/token_storage_service.dart';

enum AuthStatus {
  initial,
  registering,
  registered,
  loggingIn,
  enrollingFace,
  faceEnrolled,
  verifyingFace,
  authenticated,
  failed,
}

class AuthProvider extends ChangeNotifier {
  final FaceRecognitionService faceService;
  final AuthApiService _authApiService;
  final TokenStorageService _tokenStorage;

  AuthProvider({
    required this.faceService,
    AuthApiService? authApiService,
    TokenStorageService? tokenStorage,
  })  : _authApiService = authApiService ?? AuthApiService(),
        _tokenStorage = tokenStorage ?? TokenStorageService();

  AuthStatus _status = AuthStatus.initial;
  AuthStatus get status => _status;

  User? _currentUser;
  User? get currentUser => _currentUser;

  String? _token;
  String? get token => _token;

  ShoppingSession? _currentSession;
  ShoppingSession? get currentSession => _currentSession;

  Map<String, dynamic>? _activeCart;
  Map<String, dynamic>? get activeCart => _activeCart;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isVerified => _status == AuthStatus.authenticated || _status == AuthStatus.faceEnrolled;
  bool get isScanning => _status == AuthStatus.verifyingFace || _status == AuthStatus.enrollingFace;
  bool get isLoading =>
      _status == AuthStatus.registering ||
      _status == AuthStatus.loggingIn ||
      _status == AuthStatus.enrollingFace ||
      _status == AuthStatus.verifyingFace;

  Future<bool> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    _status = AuthStatus.registering;
    _errorMessage = null;
    notifyListeners();

    final result = await _authApiService.register(
      fullName: fullName,
      email: email,
      phone: phone,
      password: password,
    );

    if (result.isSuccess && result.user != null) {
      await _persistAuth(result);
      _status = AuthStatus.registered;
      notifyListeners();
      return true;
    }

    _status = AuthStatus.failed;
    _errorMessage = result.errorMessage ?? 'Registration failed.';
    notifyListeners();
    return false;
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _status = AuthStatus.loggingIn;
    _errorMessage = null;
    notifyListeners();

    final result = await _authApiService.login(
      email: email,
      password: password,
    );

    if (result.isSuccess && result.user != null) {
      await _persistAuth(result);
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    }

    _status = AuthStatus.failed;
    _errorMessage = result.errorMessage ?? 'Login failed.';
    notifyListeners();
    return false;
  }

  Future<bool> restoreSession() async {
    final token = await _tokenStorage.getToken();
    if (token == null || token.isEmpty) return false;
    _token = token;
    final result = await _authApiService.getMe();
    if (result.isSuccess && result.user != null) {
      _currentUser = result.user;
      _activeCart = result.activeCart;
      if (_activeCart != null) {
        _currentSession = ShoppingSession.fromJson({
          ..._activeCart!,
          'userId': _currentUser!.id,
        });
      }
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> enrollFace({
    required String imagePath,
    Uint8List? imageBytes,
  }) async {
    final userId = _currentUser?.id ?? await _tokenStorage.getUserId();
    if (userId == null || userId.isEmpty) {
      _status = AuthStatus.failed;
      _errorMessage = 'User not found. Please register or login first.';
      notifyListeners();
      return false;
    }

    _status = AuthStatus.enrollingFace;
    _errorMessage = null;
    notifyListeners();

    final result = await faceService.enrollFace(
      userId: userId,
      imagePath: imagePath,
      imageBytes: imageBytes,
    );

    if (result.isSuccess) {
      _status = AuthStatus.faceEnrolled;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    }

    _status = AuthStatus.failed;
    _errorMessage = result.errorMessage ?? 'Face enrollment failed.';
    notifyListeners();
    return false;
  }

  Future<bool> verifyFace({
    required String imagePath,
    Uint8List? imageBytes,
    String? cartCode,
  }) async {
    _status = AuthStatus.verifyingFace;
    _errorMessage = null;
    notifyListeners();

    final restored = _currentUser != null || await restoreSession();
    if (!restored && _currentUser == null) {
      _status = AuthStatus.failed;
      _errorMessage = 'Please sign in first, then use Face ID.';
      notifyListeners();
      return false;
    }

    final result = await faceService.verifyFace(
      imagePath: imagePath,
      imageBytes: imageBytes,
      cartCode: cartCode,
    );

    if (result.isSuccess) {
      if (result.token != null && result.token!.isNotEmpty && result.token != 'mock_jwt_token_123') {
        _token = result.token;
        await _tokenStorage.saveToken(_token!);
      }
      if (result.userId != null && result.userId!.isNotEmpty && !result.userId!.startsWith('mock_')) {
        await _tokenStorage.saveUserId(result.userId!);
      }
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    }

    _status = AuthStatus.failed;
    _errorMessage = result.errorMessage ?? 'Face not recognized.';
    notifyListeners();
    return false;
  }

  Future<bool> startShoppingSession({String? cartCode}) async {
    final userId = _currentUser?.id ?? await _tokenStorage.getUserId() ?? 'user_anonymous';
    final session = await _authApiService.createShoppingSession(
      userId: userId,
      cartCode: cartCode ?? AppConstants.defaultCartCode,
    );
    _currentSession = session;
    if (session != null) {
      await _tokenStorage.saveSessionId(session.sessionId);
    }
    notifyListeners();
    return session != null;
  }

  Future<void> _persistAuth(AuthResult result) async {
    _currentUser = result.user;
    _token = result.token;
    _activeCart = result.activeCart;
    if (_token != null && _token!.isNotEmpty) {
      await _tokenStorage.saveToken(_token!);
    }
    if (_currentUser != null) {
      await _tokenStorage.saveUserId(_currentUser!.id);
    }
    if (_activeCart != null) {
      _currentSession = ShoppingSession.fromJson({
        ..._activeCart!,
        'userId': _currentUser?.id,
      });
      if (_currentSession!.sessionId.isNotEmpty) {
        await _tokenStorage.saveSessionId(_currentSession!.sessionId);
      }
    }
  }

  void reset() {
    _status = AuthStatus.initial;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> logout() async {
    _currentUser = null;
    _token = null;
    _currentSession = null;
    _activeCart = null;
    _status = AuthStatus.initial;
    _errorMessage = null;
    await _tokenStorage.clearAll();
    notifyListeners();
  }
}

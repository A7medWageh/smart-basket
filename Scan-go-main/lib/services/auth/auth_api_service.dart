import '../../core/constants/app_constants.dart';
import '../../models/shopping_session.dart';
import '../../models/user.dart';
import '../api_client.dart';

class AuthResult {
  final bool isSuccess;
  final User? user;
  final String? token;
  final Map<String, dynamic>? activeCart;
  final String? errorMessage;

  const AuthResult({
    required this.isSuccess,
    this.user,
    this.token,
    this.activeCart,
    this.errorMessage,
  });

  factory AuthResult.success(User user, String token, {Map<String, dynamic>? activeCart}) =>
      AuthResult(
        isSuccess: true,
        user: user,
        token: token,
        activeCart: activeCart,
      );

  factory AuthResult.failure(String message) => AuthResult(
        isSuccess: false,
        errorMessage: message,
      );
}

class AuthApiService {
  final ApiClient _apiClient;

  AuthApiService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  Map<String, dynamic>? _unwrap(ApiResponse response) {
    final root = _asMap(response.data);
    if (root == null) return null;
    final inner = _asMap(root['data']);
    return inner ?? root;
  }

  AuthResult _parseAuth(ApiResponse response, {String fallbackEmail = '', String fallbackName = '', String fallbackPhone = ''}) {
    if (!response.isSuccess) {
      return AuthResult.failure(response.errorMessage ?? 'Request failed.');
    }
    final payload = _unwrap(response);
    if (payload == null) {
      return AuthResult.failure('Unexpected server response.');
    }

    final userJson = _asMap(payload['user']) ?? payload;
    final token = payload['token']?.toString() ?? '';
    final user = User(
      id: userJson['id']?.toString() ?? userJson['userId']?.toString() ?? '',
      name: userJson['name']?.toString() ??
          userJson['fullName']?.toString() ??
          fallbackName,
      email: userJson['email']?.toString() ?? fallbackEmail,
      phone: userJson['phone']?.toString() ?? fallbackPhone,
    );

    if (user.id.toString().isEmpty || token.isEmpty) {
      return AuthResult.failure('Login succeeded but token was missing.');
    }

    return AuthResult.success(
      user,
      token,
      activeCart: _asMap(payload['activeCart']),
    );
  }

  Future<AuthResult> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final response = await _apiClient.post(
      AppConstants.registerEndpoint,
      body: {
        'name': fullName,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'password': password,
      },
    );

    return _parseAuth(
      response,
      fallbackEmail: email,
      fallbackName: fullName,
      fallbackPhone: phone,
    );
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post(
      AppConstants.loginEndpoint,
      body: {
        'email': email,
        'password': password,
      },
    );

    return _parseAuth(response, fallbackEmail: email);
  }

  Future<AuthResult> getMe() async {
    final response = await _apiClient.get(AppConstants.meEndpoint);
    if (!response.isSuccess) {
      return AuthResult.failure(response.errorMessage ?? 'Session expired.');
    }
    final payload = _unwrap(response);
    if (payload == null) {
      return AuthResult.failure('Unexpected server response.');
    }
    final userJson = _asMap(payload['user']);
    if (userJson == null) {
      return AuthResult.failure('User profile missing.');
    }
    final token = await _apiClient.tokenStorage.getToken();
    return AuthResult.success(
      User.fromJson(userJson),
      token ?? '',
      activeCart: _asMap(payload['activeCart']),
    );
  }

  Future<ShoppingSession?> createShoppingSession({
    required String userId,
    String? cartCode,
  }) async {
    final response = await _apiClient.post(
      AppConstants.cartPairEndpoint,
      body: {
        'cartCode': cartCode ?? AppConstants.defaultCartCode,
      },
    );

    if (response.isSuccess) {
      final payload = _unwrap(response);
      if (payload != null) {
        return ShoppingSession.fromJson({
          ...payload,
          'userId': userId,
        });
      }
    }
    return null;
  }
}

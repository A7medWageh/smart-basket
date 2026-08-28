import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'token_storage_service.dart';

class ApiResponse {
  final bool isSuccess;
  final int statusCode;
  final dynamic data;
  final String? errorMessage;

  const ApiResponse({
    required this.isSuccess,
    required this.statusCode,
    this.data,
    this.errorMessage,
  });

  factory ApiResponse.success(dynamic data, {int statusCode = 200}) => ApiResponse(
        isSuccess: true,
        statusCode: statusCode,
        data: data,
      );

  factory ApiResponse.failure(String message, {int statusCode = 500, dynamic data}) =>
      ApiResponse(
        isSuccess: false,
        statusCode: statusCode,
        errorMessage: message,
        data: data,
      );
}

class ApiClient {
  final http.Client _client;
  final TokenStorageService _tokenStorage;

  ApiClient({
    http.Client? client,
    TokenStorageService? tokenStorage,
  })  : _client = client ?? http.Client(),
        _tokenStorage = tokenStorage ?? TokenStorageService();

  TokenStorageService get tokenStorage => _tokenStorage;

  Future<Map<String, String>> _getHeaders({bool isJson = true}) async {
    final headers = <String, String>{};
    if (isJson) {
      headers['Content-Type'] = 'application/json';
      headers['Accept'] = 'application/json';
    }
    final token = await _tokenStorage.getToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<ApiResponse> post(String url, {Map<String, dynamic>? body}) async {
    try {
      final uri = Uri.parse(url);
      final headers = await _getHeaders(isJson: true);
      final response = await _client
          .post(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 15));

      return _processResponse(response);
    } on TimeoutException {
      return ApiResponse.failure(
        'Connection timed out. Please check your network.',
        statusCode: 408,
      );
    } catch (e) {
      return ApiResponse.failure('Network error: $e');
    }
  }

  Future<ApiResponse> get(String url) async {
    try {
      final uri = Uri.parse(url);
      final headers = await _getHeaders(isJson: true);
      final response = await _client.get(uri, headers: headers).timeout(const Duration(seconds: 15));
      return _processResponse(response);
    } on TimeoutException {
      return ApiResponse.failure(
        'Connection timed out. Please check your network.',
        statusCode: 408,
      );
    } catch (e) {
      return ApiResponse.failure('Network error: $e');
    }
  }

  ApiResponse _processResponse(http.Response response) {
    dynamic decodedData;
    try {
      if (response.body.isNotEmpty) {
        decodedData = jsonDecode(response.body);
      }
    } catch (_) {
      decodedData = response.body;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return ApiResponse.success(decodedData, statusCode: response.statusCode);
    } else {
      String message = 'Server error (${response.statusCode})';
      if (decodedData is Map && decodedData.containsKey('message')) {
        message = decodedData['message'].toString();
      } else if (decodedData is Map && decodedData.containsKey('error')) {
        message = decodedData['error'].toString();
      }
      return ApiResponse.failure(
        message,
        statusCode: response.statusCode,
        data: decodedData,
      );
    }
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:scango/models/shopping_session.dart';
import 'package:scango/models/user.dart';
import 'package:scango/services/auth/auth_api_service.dart';
import 'package:scango/services/mock_face_recognition_service.dart';
import 'package:scango/services/token_storage_service.dart';
import 'package:scango/state/auth_provider.dart';

class FastMockAuthApiService extends AuthApiService {
  @override
  Future<AuthResult> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    return AuthResult.success(
      User(id: 'usr_reg_1', name: fullName, email: email, phone: phone),
      'mock_token_reg',
    );
  }

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    return AuthResult.success(
      User(id: 'usr_login_1', name: 'Test User', email: email, phone: ''),
      'mock_token_login',
    );
  }

  @override
  Future<ShoppingSession?> createShoppingSession({
    required String userId,
    String? cartCode,
  }) async {
    return ShoppingSession(
      sessionId: 'sess_fast_123',
      cartId: cartCode ?? 'CART_01',
      userId: userId,
      faceVerified: false,
      createdAt: DateTime.now(),
    );
  }
}

void main() {
  group('AuthProvider & Backend Face Recognition Tests', () {
    late TokenStorageService tokenStorage;
    late MockFaceRecognitionService faceService;
    late FastMockAuthApiService mockAuthApi;
    late AuthProvider authProvider;

    setUp(() {
      tokenStorage = TokenStorageService();
      faceService = MockFaceRecognitionService();
      mockAuthApi = FastMockAuthApiService();
      authProvider = AuthProvider(
        faceService: faceService,
        authApiService: mockAuthApi,
        tokenStorage: tokenStorage,
      );
    });

    test('Initial state is AuthStatus.initial', () {
      expect(authProvider.status, AuthStatus.initial);
      expect(authProvider.isAuthenticated, isFalse);
    });

    test('Register flow success', () async {
      final res = await authProvider.register(
        fullName: 'Jane Doe',
        email: 'jane@example.com',
        phone: '1234567890',
        password: 'password123',
      );
      expect(res, isTrue);
      expect(authProvider.currentUser?.fullName, equals('Jane Doe'));
      expect(authProvider.status, equals(AuthStatus.registered));
    });

    test('Login flow success', () async {
      final res = await authProvider.login(
        email: 'jane@example.com',
        password: 'password123',
      );
      expect(res, isTrue);
      expect(authProvider.isAuthenticated, isTrue);
      expect(authProvider.currentSession, isNotNull);
    });

    test('Face Enrollment Success Flow', () async {
      await tokenStorage.saveUserId('user_test_99');

      final enrollResult = await authProvider.enrollFace(
        imagePath: 'test_path.jpg',
      );

      expect(enrollResult, isTrue);
      expect(authProvider.isAuthenticated, isTrue);
      expect(authProvider.currentSession, isNotNull);
      expect(authProvider.errorMessage, isNull);
    });

    test('Face Enrollment Failure Flow', () async {
      final failService = MockFaceRecognitionService(
        shouldFail: true,
        failureMessage: 'No face detected in image.',
      );
      final failAuthProvider = AuthProvider(
        faceService: failService,
        authApiService: mockAuthApi,
        tokenStorage: tokenStorage,
      );
      await tokenStorage.saveUserId('user_test_99');

      final enrollResult = await failAuthProvider.enrollFace(
        imagePath: 'test_path.jpg',
      );

      expect(enrollResult, isFalse);
      expect(failAuthProvider.isAuthenticated, isFalse);
      expect(failAuthProvider.errorMessage, contains('No face detected'));
    });

    test('Face Verification Success Flow', () async {
      final verifyResult = await authProvider.verifyFace(
        imagePath: 'test_verify_path.jpg',
      );

      expect(verifyResult, isTrue);
      expect(authProvider.isAuthenticated, isTrue);
      expect(authProvider.currentUser?.id, equals('mock_user_101'));
      expect(authProvider.currentSession, isNotNull);
      expect(authProvider.errorMessage, isNull);
    });

    test('Face Verification Failure Flow', () async {
      final failService = MockFaceRecognitionService(
        shouldFail: true,
        failureMessage: 'Face not recognized. Please try again.',
      );
      final failAuthProvider = AuthProvider(
        faceService: failService,
        authApiService: mockAuthApi,
        tokenStorage: tokenStorage,
      );

      final verifyResult = await failAuthProvider.verifyFace(
        imagePath: 'test_verify_path.jpg',
      );

      expect(verifyResult, isFalse);
      expect(failAuthProvider.isAuthenticated, isFalse);
      expect(failAuthProvider.errorMessage, contains('Face not recognized'));
    });
  });
}

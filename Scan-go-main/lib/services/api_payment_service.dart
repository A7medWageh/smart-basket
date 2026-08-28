import '../core/constants/app_constants.dart';
import '../models/payment_method.dart';
import 'api_client.dart';
import 'payment_service.dart';

class ApiPaymentService implements PaymentService {
  final ApiClient _apiClient;

  ApiPaymentService({required ApiClient apiClient}) : _apiClient = apiClient;

  String _methodCode(PaymentMethod method) {
    switch (method.type) {
      case PaymentMethodType.vodafoneCash:
        return 'VODAFONE_CASH';
      case PaymentMethodType.instaPay:
        return 'INSTAPAY';
      case PaymentMethodType.visaCard:
        return 'VISA';
    }
  }

  @override
  Future<PaymentResult> processPayment({
    required PaymentMethod method,
    required double totalAmount,
    bool shouldFail = false,
  }) async {
    if (shouldFail) {
      return const PaymentResult(
        isSuccess: false,
        transactionId: '',
        errorMessage: 'Transaction declined. Please try another card or method.',
      );
    }

    final response = await _apiClient.post(
      AppConstants.checkoutEndpoint,
      body: {
        'paymentMethod': _methodCode(method),
      },
    );

    if (!response.isSuccess) {
      return PaymentResult(
        isSuccess: false,
        transactionId: '',
        errorMessage: response.errorMessage ?? 'Checkout failed',
      );
    }

    Map<String, dynamic>? payload;
    if (response.data is Map) {
      final root = Map<String, dynamic>.from(response.data as Map);
      if (root['data'] is Map) {
        payload = Map<String, dynamic>.from(root['data'] as Map);
      } else {
        payload = root;
      }
    }

    return PaymentResult(
      isSuccess: true,
      transactionId: payload?['orderNumber']?.toString() ??
          payload?['orderId']?.toString() ??
          '',
      exitQrCode: payload?['exitQrCode']?.toString(),
      orderNumber: payload?['orderNumber']?.toString(),
      receipt: payload,
    );
  }
}

import '../models/payment_method.dart';
import 'payment_service.dart';

class MockPaymentService implements PaymentService {
  @override
  Future<PaymentResult> processPayment({
    required PaymentMethod method,
    required double totalAmount,
    bool shouldFail = false,
  }) async {
    // Simulate 2 seconds of payment gateway processing
    await Future.delayed(const Duration(seconds: 2));

    if (shouldFail) {
      return const PaymentResult(
        isSuccess: false,
        transactionId: '',
        errorMessage: 'Transaction declined. Please try another card or method.',
      );
    }

    final txId = 'TXN-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    return PaymentResult(
      isSuccess: true,
      transactionId: txId,
    );
  }
}

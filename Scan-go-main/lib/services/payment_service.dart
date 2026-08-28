import '../models/payment_method.dart';

class PaymentResult {
  final bool isSuccess;
  final String transactionId;
  final String? errorMessage;
  final String? exitQrCode;
  final String? orderNumber;
  final Map<String, dynamic>? receipt;

  const PaymentResult({
    required this.isSuccess,
    required this.transactionId,
    this.errorMessage,
    this.exitQrCode,
    this.orderNumber,
    this.receipt,
  });
}

abstract class PaymentService {
  Future<PaymentResult> processPayment({
    required PaymentMethod method,
    required double totalAmount,
    bool shouldFail = false,
  });
}

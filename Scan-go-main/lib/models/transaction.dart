import 'cart_item.dart';
import 'payment_method.dart';

enum TransactionStatus { pending, completed, failed }

class TransactionRecord {
  final String transactionId;
  final String userId;
  final String sessionId;
  final String cartId;
  final List<CartItem> items;
  final double subtotal;
  final double tax;
  final double total;
  final PaymentMethod paymentMethod;
  final TransactionStatus status;
  final DateTime timestamp;

  const TransactionRecord({
    required this.transactionId,
    required this.userId,
    required this.sessionId,
    required this.cartId,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.paymentMethod,
    required this.status,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'transactionId': transactionId,
      'userId': userId,
      'sessionId': sessionId,
      'cartId': cartId,
      'subtotal': subtotal,
      'tax': tax,
      'total': total,
      'paymentMethod': paymentMethod.name,
      'status': status.name,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

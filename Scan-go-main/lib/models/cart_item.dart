import 'product.dart';

class CartItem {
  final String? cartItemId;
  final Product product;
  final int quantity;
  final String detectedBy;

  const CartItem({
    this.cartItemId,
    required this.product,
    required this.quantity,
    this.detectedBy = 'AI',
  });

  double get totalPrice => product.price * quantity;

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      cartItemId: json['cartItemId']?.toString() ?? json['id']?.toString(),
      product: Product.fromJson({
        ...json,
        'id': json['productId'] ?? json['id'],
        'price': json['unitPrice'] ?? json['price'],
      }),
      quantity: json['quantity'] is int
          ? json['quantity'] as int
          : int.tryParse(json['quantity']?.toString() ?? '1') ?? 1,
      detectedBy: json['detectedBy']?.toString() ?? 'AI',
    );
  }

  CartItem copyWith({
    String? cartItemId,
    Product? product,
    int? quantity,
    String? detectedBy,
  }) {
    return CartItem(
      cartItemId: cartItemId ?? this.cartItemId,
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      detectedBy: detectedBy ?? this.detectedBy,
    );
  }
}

class ShoppingSession {
  final String sessionId;
  final String cartId;
  final String userId;
  final bool isActive;
  final bool faceVerified;
  final DateTime createdAt;

  const ShoppingSession({
    required this.sessionId,
    required this.cartId,
    required this.userId,
    this.isActive = true,
    this.faceVerified = false,
    required this.createdAt,
  });

  factory ShoppingSession.fromJson(Map<String, dynamic> json) {
    final status = json['sessionStatus']?.toString().toUpperCase();
    return ShoppingSession(
      sessionId: json['sessionId']?.toString() ?? json['id']?.toString() ?? '',
      cartId: json['cartCode']?.toString() ??
          json['cartId']?.toString() ??
          'CART_01',
      userId: json['userId']?.toString() ?? '',
      isActive: json['isActive'] ?? status == null || status == 'ACTIVE',
      faceVerified: json['faceVerified'] == true,
      createdAt: json['startedAt'] != null
          ? DateTime.tryParse(json['startedAt'].toString()) ?? DateTime.now()
          : json['createdAt'] != null
              ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'cartId': cartId,
      'userId': userId,
      'isActive': isActive,
      'faceVerified': faceVerified,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

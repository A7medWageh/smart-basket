class Product {
  final String id;
  final String name;
  final String nameAr;
  final String weight;
  final double price;
  final String imagePath;
  final String barcode;

  const Product({
    required this.id,
    required this.name,
    this.nameAr = '',
    required this.weight,
    required this.price,
    required this.imagePath,
    this.barcode = '',
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final weightGrams = json['weightGrams'] ?? json['weight_grams'];
    String weight = json['weight']?.toString() ?? '';
    if (weight.isEmpty && weightGrams != null) {
      weight = '${weightGrams}g';
    }

    return Product(
      id: json['id']?.toString() ?? json['productId']?.toString() ?? '',
      name: json['nameEn']?.toString() ??
          json['name']?.toString() ??
          json['nameAr']?.toString() ??
          'Product',
      nameAr: json['nameAr']?.toString() ?? '',
      weight: weight,
      price: _toDouble(json['price'] ?? json['unitPrice']),
      imagePath: json['imageUrl']?.toString() ?? json['imagePath']?.toString() ?? '',
      barcode: json['barcode']?.toString() ?? '',
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

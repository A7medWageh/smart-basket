class User {
  final dynamic id;
  final String name;
  final String email;
  final String? phone;

  const User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
  });

  String get fullName => name;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? json['userId'] ?? '',
      name: json['name']?.toString() ?? json['fullName']?.toString() ?? 'ScanGo Customer',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User && runtimeType == other.runtimeType && id.toString() == other.id.toString();

  @override
  int get hashCode => id.toString().hashCode;
}

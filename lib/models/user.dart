class User {
  final int? id;
  final String phone;
  final String name;
  final String defaultAddress;
  final int bonusBalance;
  final bool firstOrderDiscountAvailable;
  final bool firstOrderDiscountUsed;

  const User({
    this.id,
    required this.phone,
    this.name = '',
    this.defaultAddress = '',
    this.bonusBalance = 0,
    this.firstOrderDiscountAvailable = false,
    this.firstOrderDiscountUsed = false,
  });

  int get points => bonusBalance;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] is int ? json['id'] as int : null,
      phone: json['phone']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      defaultAddress: json['default_address']?.toString() ?? '',
      bonusBalance: _toInt(json['bonus_balance']),
      firstOrderDiscountAvailable:
          json['first_order_discount_available'] == true,
      firstOrderDiscountUsed: json['first_order_discount_used'] == true,
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;

    return 0;
  }
}

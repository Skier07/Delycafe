import 'customer_address.dart';

class User {
  final int? id;
  final String phone;
  final String name;
  final String defaultAddress;
  final int bonusBalance;
  final bool firstOrderDiscountAvailable;
  final bool firstOrderDiscountUsed;
  final List<CustomerAddress> addresses;

  const User({
    this.id,
    required this.phone,
    this.name = '',
    this.defaultAddress = '',
    this.bonusBalance = 0,
    this.firstOrderDiscountAvailable = false,
    this.firstOrderDiscountUsed = false,
    this.addresses = const [],
  });

  int get points => bonusBalance;

  CustomerAddress? get defaultCustomerAddress {
    for (final address in addresses) {
      if (address.isDefault) {
        return address;
      }
    }

    if (addresses.isNotEmpty) {
      return addresses.first;
    }

    return null;
  }

  String get checkoutAddress {
    final address = defaultCustomerAddress;

    if (address != null) {
      return address.fullAddress.isNotEmpty
          ? address.fullAddress
          : address.address;
    }

    return defaultAddress;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'name': name,
      'default_address': defaultAddress,
      'bonus_balance': bonusBalance,
      'first_order_discount_available': firstOrderDiscountAvailable,
      'first_order_discount_used': firstOrderDiscountUsed,
      'addresses': addresses.map((address) => address.toJson()).toList(),
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    final rawAddresses = json['addresses'];

    final parsedAddresses = rawAddresses is List
        ? rawAddresses
            .whereType<Map<String, dynamic>>()
            .map(CustomerAddress.fromJson)
            .toList()
        : <CustomerAddress>[];

    return User(
      id: json['id'] is int ? json['id'] as int : null,
      phone: json['phone']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      defaultAddress: json['default_address']?.toString() ?? '',
      bonusBalance: _toInt(json['bonus_balance']),
      firstOrderDiscountAvailable:
          json['first_order_discount_available'] == true,
      firstOrderDiscountUsed: json['first_order_discount_used'] == true,
      addresses: parsedAddresses,
    );
  }

  User copyWith({
    int? id,
    String? phone,
    String? name,
    String? defaultAddress,
    int? bonusBalance,
    bool? firstOrderDiscountAvailable,
    bool? firstOrderDiscountUsed,
    List<CustomerAddress>? addresses,
  }) {
    return User(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      defaultAddress: defaultAddress ?? this.defaultAddress,
      bonusBalance: bonusBalance ?? this.bonusBalance,
      firstOrderDiscountAvailable:
          firstOrderDiscountAvailable ?? this.firstOrderDiscountAvailable,
      firstOrderDiscountUsed:
          firstOrderDiscountUsed ?? this.firstOrderDiscountUsed,
      addresses: addresses ?? this.addresses,
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;

    if (value is double) return value.toInt();

    if (value is String) {
      return int.tryParse(value) ?? 0;
    }

    return 0;
  }
}

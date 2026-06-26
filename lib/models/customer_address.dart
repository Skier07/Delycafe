class CustomerAddress {
  final int id;
  final String title;
  final String address;
  final String entrance;
  final String floor;
  final String apartment;
  final String comment;
  final bool isDefault;
  final String fullAddress;

  const CustomerAddress({
    required this.id,
    required this.title,
    required this.address,
    this.entrance = '',
    this.floor = '',
    this.apartment = '',
    this.comment = '',
    this.isDefault = false,
    this.fullAddress = '',
  });

  factory CustomerAddress.fromJson(Map<String, dynamic> json) {
    return CustomerAddress(
      id: _toInt(json['id']),
      title: json['title']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      entrance: json['entrance']?.toString() ?? '',
      floor: json['floor']?.toString() ?? '',
      apartment: json['apartment']?.toString() ?? '',
      comment: json['comment']?.toString() ?? '',
      isDefault: json['is_default'] == true,
      fullAddress: json['full_address']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'address': address,
      'entrance': entrance,
      'floor': floor,
      'apartment': apartment,
      'comment': comment,
      'is_default': isDefault,
      'full_address': fullAddress,
    };
  }

  Map<String, dynamic> toCreateJson({
    required String phone,
  }) {
    return {
      'phone': phone,
      'title': title,
      'address': address,
      'entrance': entrance,
      'floor': floor,
      'apartment': apartment,
      'comment': comment,
      'is_default': isDefault,
    };
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;

    if (value is String) {
      return int.tryParse(value) ?? 0;
    }

    return 0;
  }
}

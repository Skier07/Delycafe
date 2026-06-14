class OrderItem {
  final int id;
  final String productTitle;
  final String variantTitle;
  final int quantity;
  final int price;
  final int totalPrice;

  const OrderItem({
    required this.id,
    required this.productTitle,
    required this.variantTitle,
    required this.quantity,
    required this.price,
    required this.totalPrice,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: _toInt(json['id']),
      productTitle: json['product_title']?.toString() ?? '',
      variantTitle: json['variant_title']?.toString() ?? '',
      quantity: _toInt(json['quantity']),
      price: _toInt(json['price']),
      totalPrice: _toInt(json['total_price']),
    );
  }

  String get titleWithQuantity {
    final variantPart = variantTitle.isNotEmpty ? ' · $variantTitle' : '';

    return '$productTitle$variantPart × $quantity';
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

class Order {
  final int id;
  final String phone;
  final String customerName;
  final String deliveryTypeLabel;
  final String address;
  final String paymentTypeLabel;
  final String paymentStatusLabel;
  final int productsTotal;
  final int deliveryPrice;
  final int discountAmount;
  final int bonusSpent;
  final int bonusEarned;
  final int totalPrice;
  final String status;
  final String statusLabel;
  final String comment;
  final DateTime date;
  final List<OrderItem> items;

  const Order({
    required this.id,
    required this.phone,
    required this.customerName,
    required this.deliveryTypeLabel,
    required this.address,
    required this.paymentTypeLabel,
    required this.paymentStatusLabel,
    required this.productsTotal,
    required this.deliveryPrice,
    required this.discountAmount,
    required this.bonusSpent,
    required this.bonusEarned,
    required this.totalPrice,
    required this.status,
    required this.statusLabel,
    required this.comment,
    required this.date,
    required this.items,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];

    final parsedItems = rawItems is List
        ? rawItems
            .whereType<Map<String, dynamic>>()
            .map(OrderItem.fromJson)
            .toList()
        : <OrderItem>[];

    return Order(
      id: _toInt(json['id']),
      phone: json['phone']?.toString() ?? '',
      customerName: json['customer_name']?.toString() ?? '',
      deliveryTypeLabel: json['delivery_type_label']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      paymentTypeLabel: json['payment_type_label']?.toString() ?? '',
      paymentStatusLabel: json['payment_status_label']?.toString() ?? '',
      productsTotal: _toInt(json['products_total']),
      deliveryPrice: _toInt(json['delivery_price']),
      discountAmount: _toInt(json['discount_amount']),
      bonusSpent: _toInt(json['bonus_spent']),
      bonusEarned: _toInt(json['bonus_earned']),
      totalPrice: _toInt(json['total_price']),
      status: json['status']?.toString() ?? '',
      statusLabel: json['status_label']?.toString() ?? '',
      comment: json['comment']?.toString() ?? '',
      date: _parseDate(json['created_at']) ?? DateTime.now(),
      items: parsedItems,
    );
  }

  String get formattedDate {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day.$month.$year $hour:$minute';
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;

    return DateTime.tryParse(value.toString())?.toLocal();
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

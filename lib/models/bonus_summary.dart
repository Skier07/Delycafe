import 'package:delycafe/constants/bonus_rules.dart';
import 'package:delycafe/models/user.dart';

class BonusSummary {
  final int customerId;
  final String phone;
  final int bonusBalance;
  final int earnPercent;
  final int maxSpendPercent;
  final bool firstOrderDiscountAvailable;
  final bool firstOrderDiscountUsed;
  final List<BonusTransactionItem> transactions;

  const BonusSummary({
    required this.customerId,
    required this.phone,
    required this.bonusBalance,
    required this.earnPercent,
    required this.maxSpendPercent,
    required this.firstOrderDiscountAvailable,
    required this.firstOrderDiscountUsed,
    required this.transactions,
  });

  factory BonusSummary.fromJson(Map<String, dynamic> json) {
    final transactionsJson = json['transactions'];
    final earnPercent = _toInt(json['earn_percent']);
    final maxSpendPercent = _toInt(json['max_spend_percent']);

    return BonusSummary(
      customerId: _toInt(json['customer_id']),
      phone: json['phone']?.toString() ?? '',
      bonusBalance: _toInt(json['bonus_balance']),
      earnPercent: earnPercent > 0 ? earnPercent : BonusRules.earnPercent,
      maxSpendPercent:
          maxSpendPercent > 0 ? maxSpendPercent : BonusRules.maxSpendPercent,
      firstOrderDiscountAvailable:
          json['first_order_discount_available'] == true,
      firstOrderDiscountUsed: json['first_order_discount_used'] == true,
      transactions: transactionsJson is List
          ? transactionsJson
              .whereType<Map<String, dynamic>>()
              .map(BonusTransactionItem.fromJson)
              .toList()
          : const [],
    );
  }

  factory BonusSummary.fromUser(User user) {
    return BonusSummary(
      customerId: user.id ?? 0,
      phone: user.phone,
      bonusBalance: user.bonusBalance,
      earnPercent: BonusRules.earnPercent,
      maxSpendPercent: BonusRules.maxSpendPercent,
      firstOrderDiscountAvailable: user.firstOrderDiscountAvailable,
      firstOrderDiscountUsed: user.firstOrderDiscountUsed,
      transactions: const [],
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;

    return 0;
  }
}

class BonusTransactionItem {
  final int id;
  final String transactionType;
  final String transactionTypeLabel;
  final int amount;
  final String comment;
  final int? orderId;
  final DateTime? createdAt;

  const BonusTransactionItem({
    required this.id,
    required this.transactionType,
    required this.transactionTypeLabel,
    required this.amount,
    required this.comment,
    required this.orderId,
    required this.createdAt,
  });

  bool get isEarn => amount > 0;
  bool get isSpend => amount < 0;

  factory BonusTransactionItem.fromJson(Map<String, dynamic> json) {
    return BonusTransactionItem(
      id: BonusSummary._toInt(json['id']),
      transactionType: json['transaction_type']?.toString() ?? '',
      transactionTypeLabel: json['transaction_type_label']?.toString() ?? '',
      amount: BonusSummary._toInt(json['amount']),
      comment: json['comment']?.toString() ?? '',
      orderId: json['order_id'] == null
          ? null
          : BonusSummary._toInt(json['order_id']),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }
}

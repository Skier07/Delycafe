import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CheckoutDraft {
  const CheckoutDraft({
    this.name = '',
    this.phone = '',
    this.address = '',
    this.entrance = '',
    this.floor = '',
    this.apartment = '',
    this.comment = '',
    this.deliveryTime = '',
    this.deliveryType = 'ozersk',
    this.urgency = 'asap',
    this.paymentMethod = 'card',
    this.useManualAddress = false,
  });

  final String name;
  final String phone;
  final String address;
  final String entrance;
  final String floor;
  final String apartment;
  final String comment;
  final String deliveryTime;
  final String deliveryType;
  final String urgency;
  final String paymentMethod;
  final bool useManualAddress;

  bool get isEmpty {
    final onlyDefaults = deliveryType == 'ozersk' &&
        urgency == 'asap' &&
        paymentMethod == 'card' &&
        !useManualAddress;

    return onlyDefaults &&
        name.trim().isEmpty &&
        phone.trim().isEmpty &&
        address.trim().isEmpty &&
        entrance.trim().isEmpty &&
        floor.trim().isEmpty &&
        apartment.trim().isEmpty &&
        comment.trim().isEmpty &&
        deliveryTime.trim().isEmpty;
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'phone': phone,
      'address': address,
      'entrance': entrance,
      'floor': floor,
      'apartment': apartment,
      'comment': comment,
      'deliveryTime': deliveryTime,
      'deliveryType': deliveryType,
      'urgency': urgency,
      'paymentMethod': paymentMethod,
      'useManualAddress': useManualAddress,
    };
  }

  factory CheckoutDraft.fromJson(Map<String, dynamic> json) {
    return CheckoutDraft(
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      entrance: json['entrance']?.toString() ?? '',
      floor: json['floor']?.toString() ?? '',
      apartment: json['apartment']?.toString() ?? '',
      comment: json['comment']?.toString() ?? '',
      deliveryTime: json['deliveryTime']?.toString() ?? '',
      deliveryType: json['deliveryType']?.toString() ?? 'ozersk',
      urgency: json['urgency']?.toString() ?? 'asap',
      paymentMethod: json['paymentMethod']?.toString() ?? 'card',
      useManualAddress: json['useManualAddress'] == true,
    );
  }
}

class CheckoutDraftService {
  CheckoutDraftService._();

  static final CheckoutDraftService instance = CheckoutDraftService._();

  static const String _storageKey = 'checkout_draft_v1';

  Future<CheckoutDraft?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);

    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final draft = CheckoutDraft.fromJson(decoded);
      return draft.isEmpty ? null : draft;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(CheckoutDraft draft) async {
    final prefs = await SharedPreferences.getInstance();

    if (draft.isEmpty) {
      await prefs.remove(_storageKey);
      return;
    }

    await prefs.setString(_storageKey, jsonEncode(draft.toJson()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}

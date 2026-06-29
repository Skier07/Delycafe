import 'dart:convert';

import 'package:delycafe/config/api_config.dart';
import 'package:delycafe/models/customer_address.dart';
import 'package:delycafe/models/user.dart';
import 'package:http/http.dart' as http;

class OtpSendResult {
  const OtpSendResult({
    required this.sessionId,
    required this.phone,
    required this.awaitingCode,
    this.mode,
    this.status,
  });

  final int sessionId;
  final String phone;
  final bool awaitingCode;
  final String? mode;
  final String? status;

  factory OtpSendResult.fromJson(Map<String, dynamic> json) {
    return OtpSendResult(
      sessionId: json['session_id'] as int,
      phone: json['phone']?.toString() ?? '',
      awaitingCode: json['awaiting_code'] == true,
      mode: json['mode']?.toString(),
      status: json['status']?.toString(),
    );
  }
}

class OtpVerifyResult {
  const OtpVerifyResult({
    required this.verified,
    required this.phone,
  });

  final bool verified;
  final String phone;

  factory OtpVerifyResult.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'];

    return OtpVerifyResult(
      verified: json['verified'] == true,
      phone: customer is Map<String, dynamic>
          ? customer['phone']?.toString() ?? ''
          : '',
    );
  }
}

class CustomerApiService {
  Future<OtpSendResult> sendOtp({
    required String phone,
  }) async {
    final response = await http.post(
      ApiConfig.uri('/api/customers/auth/otp/send/'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'phone': phone,
      }),
    );

    final data = _decodeResponse(response);

    return OtpSendResult.fromJson(data);
  }

  Future<OtpVerifyResult> verifyOtp({
    required int sessionId,
    required String phone,
    required String code,
  }) async {
    final response = await http.post(
      ApiConfig.uri('/api/customers/auth/otp/verify/'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'session_id': sessionId,
        'phone': phone,
        'code': code,
      }),
    );

    final data = _decodeResponse(response);

    return OtpVerifyResult.fromJson(data);
  }

  Future<User> fetchProfile({
    required String phone,
    bool syncSaby = false,
  }) async {
    final response = await http.get(
      ApiConfig.uri(
        '/api/customers/profile/',
        queryParameters: {
          'phone': phone,
          if (syncSaby) 'sync_saby': '1',
        },
      ),
    );

    final data = _decodeResponse(response);

    return User.fromJson(data);
  }

  Future<User> updateProfile({
    required String phone,
    String? name,
    String? defaultAddress,
  }) async {
    final body = <String, dynamic>{
      'phone': phone,
    };

    if (name != null) {
      body['name'] = name;
    }

    if (defaultAddress != null) {
      body['default_address'] = defaultAddress;
    }

    final response = await http.patch(
      ApiConfig.uri('/api/customers/profile/'),
      headers: _jsonHeaders,
      body: jsonEncode(body),
    );

    final data = _decodeResponse(response);

    return User.fromJson(data);
  }

  Future<List<CustomerAddress>> fetchAddresses({
    required String phone,
  }) async {
    final response = await http.get(
      ApiConfig.uri(
        '/api/customers/addresses/',
        queryParameters: {
          'phone': phone,
        },
      ),
    );

    final data = _decodeListResponse(response);

    return data
        .whereType<Map<String, dynamic>>()
        .map(CustomerAddress.fromJson)
        .toList();
  }

  Future<CustomerAddress> createAddress({
    required String phone,
    required String title,
    required String address,
    String entrance = '',
    String floor = '',
    String apartment = '',
    String comment = '',
    bool isDefault = false,
  }) async {
    final response = await http.post(
      ApiConfig.uri('/api/customers/addresses/'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'phone': phone,
        'title': title,
        'address': address,
        'entrance': entrance,
        'floor': floor,
        'apartment': apartment,
        'comment': comment,
        'is_default': isDefault,
      }),
    );

    final data = _decodeResponse(response);

    return CustomerAddress.fromJson(data);
  }

  Future<CustomerAddress> updateAddress({
    required int addressId,
    String? title,
    String? address,
    String? entrance,
    String? floor,
    String? apartment,
    String? comment,
    bool? isDefault,
  }) async {
    final body = <String, dynamic>{};

    if (title != null) {
      body['title'] = title;
    }

    if (address != null) {
      body['address'] = address;
    }

    if (entrance != null) {
      body['entrance'] = entrance;
    }

    if (floor != null) {
      body['floor'] = floor;
    }

    if (apartment != null) {
      body['apartment'] = apartment;
    }

    if (comment != null) {
      body['comment'] = comment;
    }

    if (isDefault != null) {
      body['is_default'] = isDefault;
    }

    final response = await http.patch(
      ApiConfig.uri('/api/customers/addresses/$addressId/'),
      headers: _jsonHeaders,
      body: jsonEncode(body),
    );

    final data = _decodeResponse(response);

    return CustomerAddress.fromJson(data);
  }

  Future<CustomerAddress> setDefaultAddress({
    required int addressId,
  }) async {
    final response = await http.post(
      ApiConfig.uri('/api/customers/addresses/$addressId/set-default/'),
      headers: _jsonHeaders,
    );

    final data = _decodeResponse(response);

    return CustomerAddress.fromJson(data);
  }

  Future<void> deleteAddress({
    required int addressId,
  }) async {
    final response = await http.delete(
      ApiConfig.uri('/api/customers/addresses/$addressId/'),
    );

    if (response.statusCode == 204) {
      return;
    }

    _decodeResponse(response);
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final decodedBody = utf8.decode(response.bodyBytes);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decodedBody.isEmpty) {
        return <String, dynamic>{};
      }

      final data = jsonDecode(decodedBody);

      if (data is Map<String, dynamic>) {
        return data;
      }

      throw Exception('Сервер вернул неожиданный формат данных.');
    }

    throw Exception(_extractErrorMessage(decodedBody));
  }

  List<dynamic> _decodeListResponse(http.Response response) {
    final decodedBody = utf8.decode(response.bodyBytes);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decodedBody.isEmpty) {
        return <dynamic>[];
      }

      final data = jsonDecode(decodedBody);

      if (data is List) {
        return data;
      }

      throw Exception('Сервер вернул неожиданный формат списка.');
    }

    throw Exception(_extractErrorMessage(decodedBody));
  }

  String _extractErrorMessage(String decodedBody) {
    if (decodedBody.isEmpty) {
      return 'Ошибка сервера.';
    }

    try {
      final data = jsonDecode(decodedBody);

      if (data is Map<String, dynamic>) {
        final detail = data['detail'];

        if (detail != null) {
          return detail.toString();
        }

        return data.toString();
      }

      return data.toString();
    } catch (_) {
      return decodedBody;
    }
  }

  Map<String, String> get _jsonHeaders {
    return {
      'Content-Type': 'application/json; charset=utf-8',
    };
  }
}

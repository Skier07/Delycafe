import 'dart:async';
import 'dart:convert';

import 'package:delycafe/config/api_config.dart';
import 'package:delycafe/exceptions/auth_required_exception.dart';
import 'package:delycafe/models/customer_address.dart';
import 'package:delycafe/models/user.dart';
import 'package:delycafe/services/api_auth_storage.dart';
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
    required this.accessToken,
  });

  final bool verified;
  final String phone;
  final String accessToken;

  factory OtpVerifyResult.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'];

    return OtpVerifyResult(
      verified: json['verified'] == true,
      phone: customer is Map<String, dynamic>
          ? customer['phone']?.toString() ?? ''
          : '',
      accessToken: json['access_token']?.toString() ?? '',
    );
  }
}

class OtpStatusResult {
  const OtpStatusResult({
    required this.sessionId,
    required this.status,
    required this.verified,
    required this.awaitingCode,
  });

  final int sessionId;
  final String status;
  final bool verified;
  final bool awaitingCode;

  factory OtpStatusResult.fromJson(Map<String, dynamic> json) {
    return OtpStatusResult(
      sessionId: json['session_id'] as int,
      status: json['status']?.toString() ?? '',
      verified: json['verified'] == true,
      awaitingCode: json['awaiting_code'] == true,
    );
  }
}

class OtpApiException implements Exception {
  const OtpApiException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
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

    final decodedBody = utf8.decode(response.bodyBytes);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(decodedBody);

      if (data is Map<String, dynamic>) {
        return OtpVerifyResult.fromJson(data);
      }

      throw Exception('Сервер вернул неожиданный формат данных.');
    }

    throw _parseOtpApiException(decodedBody);
  }

  Future<OtpStatusResult> fetchOtpStatus({
    required int sessionId,
    required String phone,
  }) async {
    final response = await http.get(
      ApiConfig.uri(
        '/api/customers/auth/otp/status/',
        queryParameters: {
          'session_id': sessionId.toString(),
          'phone': phone,
        },
      ),
    );

    final data = _decodeResponse(response);

    return OtpStatusResult.fromJson(data);
  }

  Future<User> fetchProfile({
    required String phone,
    bool syncSaby = false,
  }) async {
    final response = await http.get(
      ApiConfig.uri(
        '/api/customers/profile/',
        queryParameters: {
          if (syncSaby) 'sync_saby': '1',
        },
      ),
      headers: _authHeaders(),
    );

    final data = _decodeResponse(response);

    return User.fromJson(data);
  }

  Future<User> updateProfile({
    required String phone,
    String? name,
    String? defaultAddress,
  }) async {
    final body = <String, dynamic>{};

    if (name != null) {
      body['name'] = name;
    }

    if (defaultAddress != null) {
      body['default_address'] = defaultAddress;
    }

    final response = await http.patch(
      ApiConfig.uri('/api/customers/profile/'),
      headers: _authJsonHeaders,
      body: jsonEncode(body),
    );

    final data = _decodeResponse(response);

    return User.fromJson(data);
  }

  Future<List<CustomerAddress>> fetchAddresses({
    required String phone,
  }) async {
    final response = await http.get(
      ApiConfig.uri('/api/customers/addresses/'),
      headers: _authHeaders(),
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
      headers: _authJsonHeaders,
      body: jsonEncode({
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
      headers: _authJsonHeaders,
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
      headers: _authJsonHeaders,
    );

    final data = _decodeResponse(response);

    return CustomerAddress.fromJson(data);
  }

  Future<void> deleteAddress({
    required int addressId,
  }) async {
    final response = await http.delete(
      ApiConfig.uri('/api/customers/addresses/$addressId/'),
      headers: _authHeaders(),
    );

    if (response.statusCode == 204) {
      return;
    }

    _decodeResponse(response);
  }

  Future<void> deleteAccount({
    required String phone,
    required int sessionId,
    required String code,
  }) async {
    final response = await http.post(
      ApiConfig.uri('/api/customers/account/delete/'),
      headers: _authJsonHeaders,
      body: jsonEncode({
        'phone': phone,
        'session_id': sessionId,
        'code': code,
      }),
    );

    _decodeResponse(response);
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final decodedBody = utf8.decode(response.bodyBytes);

    if (response.statusCode == 401 || response.statusCode == 403) {
      unawaited(ApiAuthStorage.instance.clearAccessToken());
      throw const AuthRequiredException(
        'Сессия истекла. Войдите по SMS для продолжения.',
      );
    }

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

    if (response.statusCode == 401 || response.statusCode == 403) {
      unawaited(ApiAuthStorage.instance.clearAccessToken());
      throw const AuthRequiredException(
        'Сессия истекла. Войдите по SMS для продолжения.',
      );
    }

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

  OtpApiException _parseOtpApiException(String decodedBody) {
    if (decodedBody.isEmpty) {
      return const OtpApiException('Ошибка сервера.');
    }

    try {
      final data = jsonDecode(decodedBody);

      if (data is Map<String, dynamic>) {
        final detail = data['detail'];

        return OtpApiException(
          detail?.toString() ?? 'Ошибка сервера.',
          code: data['code']?.toString(),
        );
      }

      return OtpApiException(decodedBody);
    } catch (_) {
      return OtpApiException(decodedBody);
    }
  }

  Map<String, String> get _authJsonHeaders =>
      ApiAuthStorage.instance.headers(jsonContentType: true);

  Map<String, String> _authHeaders() => ApiAuthStorage.instance.headers();

  Map<String, String> get _jsonHeaders {
    return {
      'Content-Type': 'application/json; charset=utf-8',
    };
  }
}

import 'dart:convert';

import 'package:delycafe/config/api_config.dart';
import 'package:delycafe/services/api_auth_storage.dart';
import 'package:http/http.dart' as http;

class LegalDocumentInfo {
  final String slug;
  final String title;
  final bool requiredForOrder;
  final String url;

  const LegalDocumentInfo({
    required this.slug,
    required this.title,
    required this.requiredForOrder,
    required this.url,
  });

  factory LegalDocumentInfo.fromJson(Map<String, dynamic> json) {
    return LegalDocumentInfo(
      slug: json['slug']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      requiredForOrder: json['required_for_order'] == true,
      url: json['url']?.toString() ?? '',
    );
  }
}

class LegalConsentStatus {
  final String legalDocsVersion;
  final String acceptedVersion;
  final bool canPlaceOrder;
  final bool termsAccepted;
  final bool privacyAccepted;
  final bool pdConsentAccepted;
  final bool marketingConsentAccepted;

  const LegalConsentStatus({
    required this.legalDocsVersion,
    required this.acceptedVersion,
    required this.canPlaceOrder,
    required this.termsAccepted,
    required this.privacyAccepted,
    required this.pdConsentAccepted,
    required this.marketingConsentAccepted,
  });

  factory LegalConsentStatus.empty() {
    return const LegalConsentStatus(
      legalDocsVersion: '',
      acceptedVersion: '',
      canPlaceOrder: false,
      termsAccepted: false,
      privacyAccepted: false,
      pdConsentAccepted: false,
      marketingConsentAccepted: false,
    );
  }

  factory LegalConsentStatus.fromJson(Map<String, dynamic> json) {
    return LegalConsentStatus(
      legalDocsVersion: json['legal_docs_version']?.toString() ?? '',
      acceptedVersion: json['accepted_version']?.toString() ?? '',
      canPlaceOrder: json['can_place_order'] == true,
      termsAccepted: json['terms_accepted'] == true,
      privacyAccepted: json['privacy_accepted'] == true,
      pdConsentAccepted: json['pd_consent_accepted'] == true,
      marketingConsentAccepted: json['marketing_consent_accepted'] == true,
    );
  }
}

class LegalApiService {
  Future<List<LegalDocumentInfo>> fetchDocuments() async {
    final uri = ApiConfig.uri('/api/legal/documents/');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception(
        'Не удалось загрузить документы: ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Неверный формат списка документов');
    }

    final items = decoded['documents'];

    if (items is! List) {
      return const [];
    }

    return items
        .whereType<Map<String, dynamic>>()
        .map(LegalDocumentInfo.fromJson)
        .toList();
  }

  Future<LegalConsentStatus> fetchConsentStatus() async {
    final uri = ApiConfig.uri('/api/legal/consent/status/');
    final response = await http.get(
      uri,
      headers: ApiAuthStorage.instance.headers(),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Не удалось проверить согласия: ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Неверный формат статуса согласий');
    }

    return LegalConsentStatus.fromJson(decoded);
  }

  Future<LegalConsentStatus> saveConsents({
    required bool termsAccepted,
    required bool privacyAccepted,
    required bool pdConsentAccepted,
    bool marketingConsentAccepted = false,
  }) async {
    final uri = ApiConfig.uri('/api/legal/consent/');
    final response = await http.post(
      uri,
      headers: ApiAuthStorage.instance.headers(jsonContentType: true),
      body: jsonEncode({
        'terms_accepted': termsAccepted,
        'privacy_accepted': privacyAccepted,
        'pd_consent_accepted': pdConsentAccepted,
        'marketing_consent_accepted': marketingConsentAccepted,
      }),
    );

    if (response.statusCode != 200) {
      final body = utf8.decode(response.bodyBytes);
      throw Exception(
        'Не удалось сохранить согласия: ${response.statusCode}\n$body',
      );
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Неверный формат ответа сохранения согласий');
    }

    return LegalConsentStatus.fromJson(decoded);
  }
}

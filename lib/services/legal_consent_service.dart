import 'package:delycafe/services/api_auth_storage.dart';
import 'package:delycafe/services/legal_api_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LegalConsentService extends ChangeNotifier {
  LegalConsentService({LegalApiService? apiService})
      : _apiService = apiService ?? LegalApiService();

  static const String _localVersionKey = 'legal_docs_version';
  static const String _termsKey = 'legal_terms_accepted';
  static const String _privacyKey = 'legal_privacy_accepted';
  static const String _pdConsentKey = 'legal_pd_consent_accepted';
  static const String _marketingKey = 'legal_marketing_accepted';

  final LegalApiService _apiService;

  bool _isLoading = false;
  bool _termsAccepted = false;
  bool _privacyAccepted = false;
  bool _pdConsentAccepted = false;
  bool _marketingAccepted = false;
  String _legalDocsVersion = '';

  bool get isLoading => _isLoading;
  bool get termsAccepted => _termsAccepted;
  bool get privacyAccepted => _privacyAccepted;
  bool get pdConsentAccepted => _pdConsentAccepted;
  bool get marketingAccepted => _marketingAccepted;

  bool get canPlaceOrder =>
      _termsAccepted && _privacyAccepted && _pdConsentAccepted;

  Future<void> initialize({String? phone}) async {
    await _loadLocal();

    if (phone != null && phone.trim().isNotEmpty) {
      await refreshFromServer();
    }

    notifyListeners();
  }

  Future<void> refreshFromServer() async {
    final token = ApiAuthStorage.instance.accessToken;

    if (token == null || token.isEmpty) {
      return;
    }

    try {
      final status = await _apiService.fetchConsentStatus();
      _applyStatus(status);
      await _saveLocal();
    } catch (_) {
      // Локальные согласия остаются доступными офлайн.
    }

    notifyListeners();
  }

  Future<void> saveConsents({
    String? phone,
    required bool termsAccepted,
    required bool privacyAccepted,
    required bool pdConsentAccepted,
    required bool marketingAccepted,
  }) async {
    _termsAccepted = termsAccepted;
    _privacyAccepted = privacyAccepted;
    _pdConsentAccepted = pdConsentAccepted;
    _marketingAccepted = marketingAccepted;

    if (ApiAuthStorage.instance.accessToken?.isNotEmpty == true &&
        canPlaceOrder) {
      _isLoading = true;
      notifyListeners();

      try {
        final status = await _apiService.saveConsents(
          termsAccepted: termsAccepted,
          privacyAccepted: privacyAccepted,
          pdConsentAccepted: pdConsentAccepted,
          marketingConsentAccepted: marketingAccepted,
        );
        _applyStatus(status);
      } finally {
        _isLoading = false;
      }
    }

    await _saveLocal();
    notifyListeners();
  }

  Future<void> ensureSyncedForOrder() async {
    if (!canPlaceOrder) {
      return;
    }

    await saveConsents(
      termsAccepted: _termsAccepted,
      privacyAccepted: _privacyAccepted,
      pdConsentAccepted: _pdConsentAccepted,
      marketingAccepted: _marketingAccepted,
    );
  }

  Future<void> clearAll() async {
    _legalDocsVersion = '';
    _termsAccepted = false;
    _privacyAccepted = false;
    _pdConsentAccepted = false;
    _marketingAccepted = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_localVersionKey);
    await prefs.remove(_termsKey);
    await prefs.remove(_privacyKey);
    await prefs.remove(_pdConsentKey);
    await prefs.remove(_marketingKey);

    notifyListeners();
  }

  Future<void> _loadLocal() async {
    final prefs = await SharedPreferences.getInstance();

    _legalDocsVersion = prefs.getString(_localVersionKey) ?? '';
    _termsAccepted = prefs.getBool(_termsKey) ?? false;
    _privacyAccepted = prefs.getBool(_privacyKey) ?? false;
    _pdConsentAccepted = prefs.getBool(_pdConsentKey) ?? false;
    _marketingAccepted = prefs.getBool(_marketingKey) ?? false;
  }

  Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_localVersionKey, _legalDocsVersion);
    await prefs.setBool(_termsKey, _termsAccepted);
    await prefs.setBool(_privacyKey, _privacyAccepted);
    await prefs.setBool(_pdConsentKey, _pdConsentAccepted);
    await prefs.setBool(_marketingKey, _marketingAccepted);
  }

  void _applyStatus(LegalConsentStatus status) {
    _legalDocsVersion = status.legalDocsVersion;
    _termsAccepted = status.termsAccepted;
    _privacyAccepted = status.privacyAccepted;
    _pdConsentAccepted = status.pdConsentAccepted;
    _marketingAccepted = status.marketingConsentAccepted;

    if (status.canPlaceOrder) {
      _termsAccepted = true;
      _privacyAccepted = true;
      _pdConsentAccepted = true;
    }
  }
}

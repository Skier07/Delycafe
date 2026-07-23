import 'package:delycafe/config/api_config.dart';
import 'package:delycafe/screens/legal_document_screen.dart';
import 'package:delycafe/services/legal_api_service.dart';
import 'package:delycafe/services/legal_consent_service.dart';
import 'package:delycafe/ui/tokens/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LegalConsentCheckoutSection extends StatefulWidget {
  const LegalConsentCheckoutSection({super.key});

  @override
  State<LegalConsentCheckoutSection> createState() =>
      _LegalConsentCheckoutSectionState();
}

class _LegalConsentCheckoutSectionState
    extends State<LegalConsentCheckoutSection> {
  final LegalApiService _apiService = LegalApiService();

  List<LegalDocumentInfo> _documents = const [];
  bool _termsAccepted = false;
  bool _privacyAccepted = false;
  bool _pdConsentAccepted = false;
  bool _marketingAccepted = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncFromService();
    });
  }

  Future<void> _loadDocuments() async {
    try {
      final documents = await _apiService.fetchDocuments();
      if (!mounted) return;

      setState(() {
        _documents = documents;
      });
    } catch (_) {
      // Документы можно открыть по slug и без списка.
    }
  }

  void _syncFromService() {
    final consent = context.read<LegalConsentService>();

    setState(() {
      _termsAccepted = consent.termsAccepted;
      _privacyAccepted = consent.privacyAccepted;
      _pdConsentAccepted = consent.pdConsentAccepted;
      _marketingAccepted = consent.marketingAccepted;
    });
  }

  LegalDocumentInfo? _documentBySlug(String slug) {
    for (final document in _documents) {
      if (document.slug == slug) {
        return document;
      }
    }

    return null;
  }

  void _openDocument(String slug, String title) {
    final document = _documentBySlug(slug);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LegalDocumentScreen(
          title: document?.title ?? title,
          url: document?.url.isNotEmpty == true
              ? document!.url
              : ApiConfig.uri('/api/legal/documents/$slug/').toString(),
        ),
      ),
    );
  }

  Future<void> _updateConsents() async {
    setState(() {
      _isSaving = true;
    });

    try {
      await context.read<LegalConsentService>().saveConsents(
        termsAccepted: _termsAccepted,
        privacyAccepted: _privacyAccepted,
        pdConsentAccepted: _pdConsentAccepted,
        marketingAccepted: _marketingAccepted,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _setTerms(bool value) async {
    setState(() => _termsAccepted = value);
    await _updateConsents();
  }

  Future<void> _setPrivacy(bool value) async {
    setState(() => _privacyAccepted = value);
    await _updateConsents();
  }

  Future<void> _setPdConsent(bool value) async {
    setState(() => _pdConsentAccepted = value);
    await _updateConsents();
  }

  Future<void> _setMarketing(bool value) async {
    setState(() => _marketingAccepted = value);
    await _updateConsents();
  }

  @override
  Widget build(BuildContext context) {
    final consentService = context.watch<LegalConsentService>();

    if (consentService.canPlaceOrder) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.header.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.header.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Для оформления заказа примите условия',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.header.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Отметьте обязательные пункты. После первого заказа они сохранятся '
            'и больше не потребуют повторного подтверждения.',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: Colors.black.withValues(alpha: 0.68),
            ),
          ),
          const SizedBox(height: 12),
          _ConsentRow(
            value: _termsAccepted,
            label: 'Пользовательское соглашение',
            onChanged: _isSaving ? null : _setTerms,
            onOpen: () => _openDocument(
              'user-agreement',
              'Пользовательское соглашение',
            ),
          ),
          _ConsentRow(
            value: _privacyAccepted,
            label: 'Политика конфиденциальности',
            onChanged: _isSaving ? null : _setPrivacy,
            onOpen: () => _openDocument(
              'privacy-policy',
              'Политика конфиденциальности',
            ),
          ),
          _ConsentRow(
            value: _pdConsentAccepted,
            label: 'Согласие на обработку персональных данных',
            onChanged: _isSaving ? null : _setPdConsent,
            onOpen: () => _openDocument(
              'personal-data-consent',
              'Согласие на обработку персональных данных',
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            value: _marketingAccepted,
            onChanged: _isSaving
                ? null
                : (value) => _setMarketing(value ?? false),
            title: const Text(
              'Согласие на рекламные и информационные сообщения (необязательно)',
              style: TextStyle(fontSize: 14),
            ),
          ),
          if (_isSaving) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(minHeight: 2),
          ],
        ],
      ),
    );
  }
}

class _ConsentRow extends StatelessWidget {
  const _ConsentRow({
    required this.value,
    required this.label,
    required this.onChanged,
    required this.onOpen,
  });

  final bool value;
  final String label;
  final ValueChanged<bool>? onChanged;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: value,
          onChanged: onChanged == null
              ? null
              : (checked) => onChanged!(checked ?? false),
        ),
        Expanded(
          child: GestureDetector(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                label,
                style: const TextStyle(
                  decoration: TextDecoration.underline,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

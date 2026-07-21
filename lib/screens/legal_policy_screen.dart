import 'package:delycafe/config/api_config.dart';
import 'package:delycafe/screens/legal_document_screen.dart';
import 'package:delycafe/services/legal_api_service.dart';
import 'package:delycafe/services/legal_consent_service.dart';
import 'package:delycafe/ui/components/buttons/auth_button.dart';
import 'package:delycafe/ui/components/glass/shader_glass_container.dart';
import 'package:delycafe/ui/tokens/app_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LegalPolicyScreen extends StatefulWidget {
  const LegalPolicyScreen({super.key});

  @override
  State<LegalPolicyScreen> createState() => _LegalPolicyScreenState();
}

class _LegalPolicyScreenState extends State<LegalPolicyScreen> {
  final LegalApiService _apiService = LegalApiService();

  List<LegalDocumentInfo> _documents = const [];
  bool _isLoadingDocuments = true;
  String? _errorMessage;

  bool _termsAccepted = false;
  bool _privacyAccepted = false;
  bool _pdConsentAccepted = false;
  bool _marketingAccepted = false;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCurrentConsents();
    });
  }

  Future<void> _loadDocuments() async {
    try {
      final documents = await _apiService.fetchDocuments();
      if (!mounted) return;

      setState(() {
        _documents = documents;
        _isLoadingDocuments = false;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoadingDocuments = false;
        _errorMessage = error.toString();
      });
    }
  }

  void _loadCurrentConsents() {
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

  void _openDocument(LegalDocumentInfo document) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LegalDocumentScreen(
          title: document.title,
          url: document.url.isNotEmpty
              ? document.url
              : ApiConfig.uri('/api/legal/documents/${document.slug}/').toString(),
        ),
      ),
    );
  }

  Future<void> _saveConsents() async {
    if (!(_termsAccepted && _privacyAccepted && _pdConsentAccepted)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Отметьте все обязательные пункты, чтобы оформлять заказы.',
          ),
        ),
      );
      return;
    }

    final consentService = context.read<LegalConsentService>();

    try {
      await consentService.saveConsents(
        termsAccepted: _termsAccepted,
        privacyAccepted: _privacyAccepted,
        pdConsentAccepted: _pdConsentAccepted,
        marketingAccepted: _marketingAccepted,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Согласия сохранены. Можно оформлять заказы.'),
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final consentService = context.watch<LegalConsentService>();

    return Scaffold(
      backgroundColor: const Color(0xFFFEF7FF),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.header,
        elevation: 0,
        toolbarHeight: 60,
        leadingWidth: 60,
        leading: Padding(
          padding: const EdgeInsets.all(8),
          child: ShaderGlassContainer(
            borderRadius: 30,
            onPressed: () => Navigator.pop(context),
            padding: const EdgeInsets.all(8),
            child: const Icon(
              CupertinoIcons.chevron_left_2,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
        title: const Text('Политика'),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 22,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_isLoadingDocuments)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_errorMessage != null)
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
            )
          else ...[
            const Text(
              'Документы',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ..._documents.map(
              (document) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(document.title),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openDocument(document),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Обязательные согласия для заказа',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _ConsentTile(
              value: _termsAccepted,
              label: 'Пользовательское соглашение',
              onChanged: (value) => setState(() => _termsAccepted = value),
              onOpen: () {
                final document = _documentBySlug('user-agreement');
                if (document != null) {
                  _openDocument(document);
                }
              },
            ),
            _ConsentTile(
              value: _privacyAccepted,
              label: 'Политика конфиденциальности',
              onChanged: (value) => setState(() => _privacyAccepted = value),
              onOpen: () {
                final document = _documentBySlug('privacy-policy');
                if (document != null) {
                  _openDocument(document);
                }
              },
            ),
            _ConsentTile(
              value: _pdConsentAccepted,
              label: 'Согласие на обработку персональных данных',
              onChanged: (value) => setState(() => _pdConsentAccepted = value),
              onOpen: () {
                final document = _documentBySlug('personal-data-consent');
                if (document != null) {
                  _openDocument(document);
                }
              },
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _marketingAccepted,
              onChanged: (value) {
                setState(() {
                  _marketingAccepted = value ?? false;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'Согласие на рекламные и информационные сообщения (необязательно)',
              ),
            ),
            const SizedBox(height: 16),
            if (consentService.canPlaceOrder)
              const Text(
                'Обязательные согласия приняты. Заказы доступны.',
                style: TextStyle(color: Colors.green),
              ),
            const SizedBox(height: 16),
            AuthButton(
              text: consentService.isLoading ? 'Сохраняем...' : 'Сохранить',
              onPressed: consentService.isLoading ? null : _saveConsents,
            ),
          ],
        ],
      ),
    );
  }
}

class _ConsentTile extends StatelessWidget {
  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpen;

  const _ConsentTile({
    required this.value,
    required this.label,
    required this.onChanged,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: value,
          onChanged: (checked) => onChanged(checked ?? false),
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
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

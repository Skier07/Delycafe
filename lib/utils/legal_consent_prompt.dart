import 'package:delycafe/screens/legal_policy_screen.dart';
import 'package:delycafe/services/legal_consent_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

Future<void> showLegalConsentRequiredDialog(BuildContext context) async {
  final consent = context.read<LegalConsentService>();

  if (consent.canPlaceOrder) {
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Примите условия'),
        content: const Text(
          'Для оформления заказа примите обязательные согласия '
          'на экране «Политика»: пользовательское соглашение, '
          'политику конфиденциальности и обработку персональных данных.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const LegalPolicyScreen(),
                ),
              );
            },
            child: const Text('Перейти к политике'),
          ),
        ],
      );
    },
  );
}

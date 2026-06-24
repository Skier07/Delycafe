import 'package:delycafe/config/jivo_config.dart';
import 'package:delycafe/models/user.dart';
import 'package:delycafe/screens/jivo_chat_screen.dart';
import 'package:flutter/material.dart';

class JivoService {
  const JivoService._();

  static Future<void> openSupportChat(
    BuildContext context, {
    User? user,
  }) async {
    if (!JivoConfig.isConfigured) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Чат поддержки'),
          content: const Text(
            'Виджет Jivo ещё не настроен.\n\n'
            'Укажите Widget ID при сборке:\n'
            '--dart-define=JIVO_WIDGET_ID=ваш_id',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Понятно'),
            ),
          ],
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => JivoChatScreen(user: user),
      ),
    );
  }
}

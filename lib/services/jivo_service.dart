import 'package:delycafe/models/user.dart';
import 'package:delycafe/screens/jivo_chat_screen.dart';
import 'package:flutter/material.dart';

class JivoService {
  const JivoService._();

  static Future<bool?> openSupportChat(
    BuildContext context, {
    User? user,
  }) async {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => JivoChatScreen(user: user),
      ),
    );
  }
}

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class UpdateService {
  static Future<void> checkForUpdates(BuildContext context) async {
    try {
      final response = await Dio().get(
        'https://raw.githubusercontent.com/Skier07/Delycafe/refs/heads/main/version.json',
      );

      final data = jsonDecode(response.data);

      final latestVersion = data['version'];
      final apkUrl = data['apk_url'];

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (latestVersion != currentVersion) {
        _showUpdateDialog(context, apkUrl);
      }
    } catch (e) {
      debugPrint('Ошибка обновления: $e');
    }
  }

  static void _showUpdateDialog(
    BuildContext context,
    String apkUrl,
  ) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Доступно обновление'),
          content: const Text(
            'Появилась новая версия приложения.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Позже'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _downloadAndInstall(apkUrl);
              },
              child: const Text('Обновить'),
            ),
          ],
        );
      },
    );
  }

  static Future<void> _downloadAndInstall(String url) async {
    final dir = await getTemporaryDirectory();

    final path = '${dir.path}/update.apk';

    await Dio().download(url, path);

    await OpenFilex.open(path);
  }
}

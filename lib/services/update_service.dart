import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class UpdateService {
  static const _apkMimeType = 'application/vnd.android.package-archive';

  static Future<void> checkForUpdates(BuildContext context) async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      final response = await Dio().get(
        'https://raw.githubusercontent.com/Skier07/Delycafe/refs/heads/main/version.json',
      );

      final data = jsonDecode(response.data);

      final latestVersion = data['version'] as String;
      final apkUrl = data['apk_url'] as String;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (latestVersion != currentVersion && context.mounted) {
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
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Доступно обновление'),
          content: const Text(
            'Появилась новая версия приложения.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Позже'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await _downloadAndInstall(context, apkUrl);
              },
              child: const Text('Обновить'),
            ),
          ],
        );
      },
    );
  }

  static Future<void> _downloadAndInstall(
    BuildContext context,
    String url,
  ) async {
    if (!context.mounted) {
      return;
    }

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 24),
                Expanded(child: Text('Загрузка обновления…')),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/update.apk';

      await Dio().download(url, path);

      if (!context.mounted) {
        return;
      }
      Navigator.pop(context);

      final result = await OpenFilex.open(
        path,
        type: _apkMimeType,
      );

      if (!context.mounted) {
        return;
      }

      if (result.type != ResultType.done) {
        _showError(
          context,
          result.message.isNotEmpty
              ? result.message
              : 'Не удалось открыть установщик',
        );
      }
    } on DioException catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        _showError(context, 'Ошибка загрузки: ${e.message ?? e.type}');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        _showError(context, 'Ошибка обновления: $e');
      }
    }
  }

  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

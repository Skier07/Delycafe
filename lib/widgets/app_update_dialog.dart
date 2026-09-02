import 'package:delycafe/services/app_update_service.dart';
import 'package:delycafe/ui/tokens/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> showAppUpdateDialog(
  BuildContext context,
  AppUpdateInfo info,
) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Доступна новая версия'),
        content: Text(
          'В магазине уже версия ${info.storeVersion}, '
          'у вас установлена ${info.currentVersion}.\n\n'
          'Приложение не обновляется само — откройте магазин и установите '
          'обновление вручную. На iPhone также можно включить автообновление: '
          'Настройки → App Store → Обновления приложений.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await AppUpdateService.instance.dismissVersion(info.storeVersion);
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Позже'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.header,
            ),
            onPressed: () async {
              final uri = Uri.parse(info.storeUrl);
              final launched = await launchUrl(
                uri,
                mode: LaunchMode.externalApplication,
              );

              if (launched) {
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('Обновить'),
          ),
        ],
      );
    },
  );
}

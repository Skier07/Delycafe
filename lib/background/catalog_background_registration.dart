import 'package:delycafe/background/workmanager_callback.dart';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

/// Регистрация фоновой синхронизации каталога. Не блокирует UI при ошибках.
Future<void> registerCatalogBackgroundSync() async {
  try {
    await Workmanager().initialize(callbackDispatcher);

    await Workmanager().registerPeriodicTask(
      catalogBackgroundTaskName,
      catalogBackgroundTaskName,
      frequency: const Duration(hours: 4),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  } catch (error, stackTrace) {
    debugPrint('Фоновая синхронизация каталога не зарегистрирована: $error');
    debugPrint(stackTrace.toString());
  }
}

import 'package:delycafe/background/workmanager_callback.dart';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

bool _registrationComplete = false;
bool _registrationInProgress = false;

/// Регистрация фоновой синхронизации после старта UI (безопасно для iOS BGTask).
Future<void> registerCatalogBackgroundSyncWhenReady() async {
  if (_registrationComplete || _registrationInProgress) {
    return;
  }

  _registrationInProgress = true;

  try {
    // Не трогаем BGTaskScheduler в том же окне, что нативный launch.
    await Future<void>.delayed(const Duration(seconds: 3));

    await Workmanager().initialize(callbackDispatcher);

    await Workmanager().registerPeriodicTask(
      catalogBackgroundTaskName,
      catalogBackgroundTaskName,
      frequency: const Duration(hours: 4),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );

    _registrationComplete = true;
  } catch (error, stackTrace) {
    debugPrint('Фоновая синхронизация каталога не зарегистрирована: $error');
    debugPrint(stackTrace.toString());
  } finally {
    _registrationInProgress = false;
  }
}

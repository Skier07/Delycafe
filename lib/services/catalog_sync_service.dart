import 'dart:async';

import 'package:delycafe/data/hive/hive_init.dart';
import 'package:delycafe/services/catalog_repository.dart';

/// Периодическая и фоновая синхронизация каталога с API.
class CatalogSyncService {
  CatalogSyncService._();

  static final CatalogSyncService instance = CatalogSyncService._();

  static const Duration minInterval = Duration(minutes: 15);
  static const Duration foregroundInterval = Duration(minutes: 30);

  final CatalogRepository _repository = CatalogRepository();

  DateTime? _lastSuccessAt;
  bool _inProgress = false;
  Timer? _foregroundTimer;

  Future<void> refresh({bool force = false}) async {
    if (_inProgress) {
      return;
    }

    if (!force &&
        _lastSuccessAt != null &&
        DateTime.now().difference(_lastSuccessAt!) < minInterval) {
      return;
    }

    _inProgress = true;

    try {
      await _repository.fetchFromApiAndCache();
      _lastSuccessAt = DateTime.now();
    } catch (_) {
      // Оставляем кэш, не прерываем работу приложения.
    } finally {
      _inProgress = false;
    }
  }

  void onAppForeground() {
    unawaited(refresh());

    _foregroundTimer ??= Timer.periodic(
      foregroundInterval,
      (_) => unawaited(refresh()),
    );
  }

  void onAppBackground() {
    _foregroundTimer?.cancel();
    _foregroundTimer = null;
  }

  /// Для workmanager: отдельный isolate без UI.
  static Future<void> backgroundRefresh() async {
    await initHive();
    await instance.refresh(force: true);
  }
}

import 'dart:async';

import 'package:delycafe/data/hive/hive_init.dart';
import 'package:delycafe/services/catalog_repository.dart';
import 'package:flutter/foundation.dart';

/// Периодическая и фоновая синхронизация каталога с API.
class CatalogSyncService {
  CatalogSyncService._({CatalogRepository? repository})
      : _repository = repository ?? CatalogRepository();

  static final CatalogSyncService instance = CatalogSyncService._();

  @visibleForTesting
  factory CatalogSyncService.forTesting(CatalogRepository repository) {
    return CatalogSyncService._(repository: repository);
  }

  static const Duration minInterval = Duration(minutes: 15);
  static const Duration foregroundInterval = Duration(minutes: 30);

  final CatalogRepository _repository;

  DateTime? _lastSuccessAt;
  Future<void>? _ongoingRefresh;
  Timer? _foregroundTimer;

  Future<void> refresh({bool force = false}) async {
    if (_ongoingRefresh != null) {
      return _ongoingRefresh!;
    }

    if (!force &&
        _lastSuccessAt != null &&
        DateTime.now().difference(_lastSuccessAt!) < minInterval) {
      return;
    }

    final operation = _runRefresh();
    _ongoingRefresh = operation;

    try {
      await operation;
    } finally {
      if (identical(_ongoingRefresh, operation)) {
        _ongoingRefresh = null;
      }
    }
  }

  Future<void> _runRefresh() async {
    try {
      await _repository.fetchFromApiAndCache();
      _lastSuccessAt = DateTime.now();
    } catch (_) {
      // Оставляем кэш, не прерываем работу приложения.
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

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:haptic_feedback/haptic_feedback.dart' as apple;

/// Центральная точка тактильной отдачи.
///
/// На iPhone используется пакет [haptic_feedback]: нативные генераторы
/// Apple (`success`, `warning`, `rigid`, `selection`).
/// На Android — [HapticFeedback] Flutter (`lightImpact`, `mediumImpact`,
/// `heavyImpact`, `selectionClick`).
///
/// Чтобы выключить всю отдачу, поставьте [enabled] в `false`.
/// Чтобы сменить эффект у конкретного действия, правьте только этот файл.
class AppHaptics {
  AppHaptics._();

  /// Мастер-выключатель всей тактильной отдачи.
  static bool enabled = true;

  static bool? _iosCanVibrate;

  static bool get _useApple => defaultTargetPlatform == TargetPlatform.iOS;

  /// Кнопки баннера и остальные [ShaderGlassContainer].
  ///
  /// iPhone: `rigid`. Android: `lightImpact`.
  static void glassButton() {
    _play(
      ios: apple.HapticsType.rigid,
      android: HapticFeedback.lightImpact,
    );
  }

  /// Открытие карточки товара.
  ///
  /// iPhone: `rigid`. Android: `lightImpact`.
  static void openProduct() {
    _play(
      ios: apple.HapticsType.rigid,
      android: HapticFeedback.lightImpact,
    );
  }

  /// Добавление в корзину.
  ///
  /// iPhone: `success`. Android: `mediumImpact`.
  static void addToCart() {
    _play(
      ios: apple.HapticsType.success,
      android: HapticFeedback.mediumImpact,
    );
  }

  /// Ошибка оплаты и неверный SMS-код.
  ///
  /// iPhone: `warning` (короткий «не получилось» от Apple).
  /// Android: `heavyImpact` — короткий удар, не путать с
  /// [HapticFeedback.vibrate]: `vibrate` это длинная вибрация как у звонка.
  static void error() {
    _play(
      ios: apple.HapticsType.warning,
      android: HapticFeedback.heavyImpact,
    );
  }

  /// Переключатели («Озёрск / Самовывоз») и щелчок категории.
  ///
  /// iPhone: `selection`. Android: `selectionClick`.
  static void selection() {
    _play(
      ios: apple.HapticsType.selection,
      android: HapticFeedback.selectionClick,
    );
  }

  static void _play({
    required apple.HapticsType ios,
    required Future<void> Function() android,
  }) {
    if (!enabled) {
      return;
    }

    unawaited(_playAsync(ios: ios, android: android));
  }

  static Future<void> _playAsync({
    required apple.HapticsType ios,
    required Future<void> Function() android,
  }) async {
    try {
      if (_useApple) {
        _iosCanVibrate ??= await apple.Haptics.canVibrate();
        if (_iosCanVibrate != true) {
          return;
        }

        await apple.Haptics.vibrate(ios);
        return;
      }

      await android();
    } catch (_) {
      // На эмуляторе, в тестах и на устройствах без вибромотора
      // отдачу просто пропускаем.
    }
  }
}

/// Щелчки энкодера при горизонтальном скролле категорий меню.
class CategoryEncoderHaptics {
  CategoryEncoderHaptics();

  static const double detentPixels = 28;
  static const Duration minInterval = Duration(milliseconds: 45);

  double _lastTickPixels = 0;
  DateTime? _lastTickAt;
  bool _armed = false;

  bool handle(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.horizontal) {
      return false;
    }

    if (notification is ScrollStartNotification) {
      if (notification.dragDetails != null) {
        _armed = true;
        _lastTickPixels = notification.metrics.pixels;
      }

      return false;
    }

    if (notification is ScrollUpdateNotification && _armed) {
      final pixels = notification.metrics.pixels;

      if ((pixels - _lastTickPixels).abs() >= detentPixels) {
        final now = DateTime.now();

        if (_lastTickAt == null ||
            now.difference(_lastTickAt!) >= minInterval) {
          _lastTickPixels = pixels;
          _lastTickAt = now;
          AppHaptics.selection();
        }
      }

      return false;
    }

    if (notification is ScrollEndNotification) {
      _armed = false;
    }

    return false;
  }
}

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
  /// iPhone: `selection`. Android: `selectionClick`.
  static void openProduct() {
    _play(
      ios: apple.HapticsType.selection,
      android: HapticFeedback.selectionClick,
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

  /// Переключатели («Озёрск / Самовывоз») и листание.
  ///
  /// iPhone: `selection`. Android: `selectionClick`.
  static void selection() {
    _play(
      ios: apple.HapticsType.selection,
      android: HapticFeedback.selectionClick,
    );
  }

  /// Один тик при начале жеста прокрутки, без дрожи на каждый пиксель.
  static bool onScrollStart(ScrollNotification notification) {
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      selection();
    }

    return false;
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

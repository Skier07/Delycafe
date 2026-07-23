import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Настройки полей ввода с поддержкой русской клавиатуры на Android.
abstract final class RussianTextInput {
  static const TextInputType text = TextInputType.text;
  static const TextInputType multiline = TextInputType.multiline;

  /// На Android цифровой `keyboardType` часто «залипает» и блокирует кириллицу
  /// в соседних текстовых полях. Поэтому для подъезда/этажа/квартиры оставляем
  /// текстовую клавиатуру, а цифры ограничиваем formatter'ом.
  static TextInputType get digitsKeyboardType {
    if (Platform.isAndroid) {
      return TextInputType.text;
    }

    return const TextInputType.numberWithOptions(
      signed: false,
      decimal: false,
    );
  }

  static List<TextInputFormatter> get digitsOnlyFormatters {
    return [FilteringTextInputFormatter.digitsOnly];
  }
}

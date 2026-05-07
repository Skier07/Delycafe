import 'package:flutter/material.dart';

class AppButtonStyles {
  static ButtonStyle iconOverlay = ButtonStyle(
    overlayColor: WidgetStatePropertyAll(
      Colors.black87.withValues(alpha: 0.2),
    ),
  );
}

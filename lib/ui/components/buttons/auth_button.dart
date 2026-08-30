import 'package:delycafe/ui/tokens/app_colors.dart';
import 'package:delycafe/ui/tokens/app_radius.dart';
import 'package:delycafe/ui/tokens/app_sizes.dart';
import 'package:delycafe/utils/haptic_feedback.dart';
import 'package:flutter/material.dart';

class AuthButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;

  const AuthButton({super.key, required this.text, required this.onPressed});

  @override
  State<AuthButton> createState() => _AuthButtonState();
}

class _AuthButtonState extends State<AuthButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!mounted || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;

    return Listener(
      onPointerDown: enabled ? (_) => _setPressed(true) : null,
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 90),
        scale: _pressed ? 0.97 : 1,
        child: SizedBox(
          height: AppSizes.buttonHeight,
          width: double.infinity,
          child: ElevatedButton(
            onPressed: enabled
                ? () {
                    AppHaptics.glassButton();
                    widget.onPressed!();
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: enabled
                  ? AppColors.primary
                  : Colors.black.withValues(alpha: 0.12),
              foregroundColor: enabled
                  ? AppColors.onPrimary
                  : Colors.black.withValues(alpha: 0.55),
              disabledBackgroundColor: Colors.black.withValues(alpha: 0.12),
              disabledForegroundColor: Colors.black.withValues(alpha: 0.55),
              elevation: enabled ? 2 : 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.button),
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                widget.text,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

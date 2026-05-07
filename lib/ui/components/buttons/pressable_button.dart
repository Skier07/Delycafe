import 'package:flutter/material.dart';

class PressableButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;
  final BorderRadius borderRadius;

  const PressableButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  @override
  State<PressableButton> createState() => _PressableButtonState();
}

class _PressableButtonState extends State<PressableButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 90),
        scale: _pressed ? 0.96 : 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: widget.borderRadius,
            onTap: widget.onPressed,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

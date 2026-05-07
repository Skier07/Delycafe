import 'package:delycafe/ui/components/glass/shader_glass_container.dart';
import 'package:flutter/material.dart';

class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final Color color;
  final EdgeInsets padding;
  final double borderRadius;
  final Color tint;

  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 24,
    this.color = Colors.white,
    this.padding = const EdgeInsets.all(8),
    this.borderRadius = 30,
    this.tint = const Color(0xFF5AC8FA),
  });

  @override
  Widget build(BuildContext context) {
    return ShaderGlassContainer(
      onPressed: onPressed,
      padding: padding,
      borderRadius: borderRadius,
      tint: tint,
      child: Icon(
        icon,
        size: size,
        color: color,
      ),
    );
  }
}

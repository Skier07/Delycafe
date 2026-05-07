import 'package:delycafe/ui/components/glass/shader_glass_container.dart';
import 'package:flutter/material.dart';

class GlassBadge extends StatelessWidget {
  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;
  final double fontSize;
  final FontWeight fontWeight;
  final Color textColor;
  final Color iconColor;
  final double iconSize;
  final EdgeInsets padding;
  final double borderRadius;
  final double spacing;
  final Color tint;

  const GlassBadge({
    super.key,
    required this.text,
    this.icon,
    this.onPressed,
    this.fontSize = 22,
    this.fontWeight = FontWeight.w700,
    this.textColor = Colors.white,
    this.iconColor = const Color(0xFF7DD3FC),
    this.iconSize = 22,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.borderRadius = 30,
    this.spacing = 8,
    this.tint = const Color(0xFF5AC8FA),
  });

  @override
  Widget build(BuildContext context) {
    return ShaderGlassContainer(
      onPressed: onPressed,
      padding: padding,
      borderRadius: borderRadius,
      tint: tint,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: textColor,
            ),
          ),
          if (icon != null) ...[
            SizedBox(width: spacing),
            Icon(
              icon,
              size: iconSize,
              color: iconColor,
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

class GlassText extends StatelessWidget {
  final String text;

  const GlassText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        /// База (тёмная подложка как в divider)
        Text(
          text,
          style: TextStyle(
            fontSize: 50,
            fontWeight: FontWeight.bold,
            letterSpacing: -1.0,
            color: Colors.black.withValues(alpha: 0.3),
          ),
        ),

        /// Светлый градиент (как стекло)
        ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.7),
                Colors.white.withValues(alpha: 0.15),
              ],
            ).createShader(bounds);
          },
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 50,
              fontWeight: FontWeight.bold,
              letterSpacing: -1.0,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

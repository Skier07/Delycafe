import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class ShaderGlassContainer extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final EdgeInsets padding;
  final double borderRadius;
  final Color tint;
  final double blur;

  const ShaderGlassContainer({
    super.key,
    required this.child,
    this.onPressed,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    this.borderRadius = 30,
    this.tint = const Color(0xFF5AC8FA),
    this.blur = 3,
  });

  @override
  State<ShaderGlassContainer> createState() => _ShaderGlassContainerState();
}

class _ShaderGlassContainerState extends State<ShaderGlassContainer> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final glass = ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
        child: Stack(
          children: [
            // Базовый стеклянный слой
            Container(
              padding: widget.padding,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.13),
                    Colors.white.withValues(alpha: 0.05),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.22),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: widget.child,
            ),

            // Холодная синяя линза слева-сверху
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    gradient: RadialGradient(
                      center: const Alignment(-0.75, -0.8),
                      radius: 1.25,
                      colors: [
                        widget.tint.withValues(alpha: 0.14),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Мягкий верхний блик
            Positioned(
              top: 1,
              left: 2,
              right: 2,
              child: IgnorePointer(
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.20),
                        Colors.white.withValues(alpha: 0.07),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Диагональный отражённый свет
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    gradient: LinearGradient(
                      begin: const Alignment(-0.9, -0.8),
                      end: const Alignment(0.7, 0.9),
                      colors: [
                        Colors.white.withValues(alpha: 0.10),
                        Colors.transparent,
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.28, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // Лёгкая выпуклость в центре
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    gradient: RadialGradient(
                      center: const Alignment(0.0, -0.2),
                      radius: 1.1,
                      colors: [
                        Colors.white.withValues(alpha: 0.05),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Затемнение при нажатии
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 90),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    color: Colors.black.withValues(
                      alpha: _pressed ? 0.10 : 0.0,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    final scaledGlass = AnimatedScale(
      duration: const Duration(milliseconds: 90),
      scale: _pressed ? 0.97 : 1,
      child: glass,
    );

    if (widget.onPressed == null) {
      return scaledGlass;
    }

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: widget.onPressed,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        // borderRadius: BorderRadius.circular(widget.borderRadius),
        // splashColor: Colors.transparent,
        // highlightColor: Colors.transparent,
        child: scaledGlass,
      ),
    );
  }
}

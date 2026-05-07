/* import 'dart:ui';

import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final EdgeInsets padding;
  final double borderRadius;

  const GlassContainer({
    super.key,
    required this.child,
    this.onPressed,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    this.borderRadius = 26,
  });

  @override
  Widget build(BuildContext context) {
    final glass = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: AlignmentGeometry.bottomRight,
              colors: [
                Colors.blueGrey.withValues(alpha: 0.22),
                Colors.blueGrey.withValues(alpha: 0.10),
              ],
            ),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.28),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
    if (onPressed == null) return glass;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: TextButton(
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          minimumSize: const WidgetStatePropertyAll(Size.zero),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          overlayColor: WidgetStatePropertyAll(
            Colors.black.withValues(alpha: 0.14),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
        ),
        onPressed: onPressed,
        child: glass,
      ),
    );
  }
}
 */

import 'dart:ui';

import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final EdgeInsets padding;
  final double borderRadius;

  const GlassContainer({
    super.key,
    required this.child,
    this.onPressed,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    this.borderRadius = 26,
  });

  @override
  Widget build(BuildContext context) {
    final glass = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: Stack(
          children: [
            // Основной стеклянный слой
            Container(
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.22),
                    Colors.white.withValues(alpha: 0.08),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.30),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: child,
            ),

            // 1. верхний блик
            Positioned(
              top: 1,
              left: 2,
              right: 2,
              child: IgnorePointer(
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(borderRadius),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.28),
                        Colors.white.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Голубая линза по краю
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(borderRadius),
                    gradient: RadialGradient(
                      center: const Alignment(-0.7, -0.8),
                      radius: 1.35,
                      colors: [
                        Colors.lightBlueAccent.withValues(alpha: 0.18),
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.05),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Верхний блик
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(borderRadius),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.22),
                        Colors.transparent,
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.22, 1.0],
                    ),
                  ),
                ),
              ),
            ),

            // Лёгкая внутренняя выпуклость
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(borderRadius),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.10),
                        blurRadius: 8,
                        spreadRadius: -2,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Контент
            Positioned.fill(
              child: Center(child: child),
            ),
          ],
        ),
      ),
    );

    if (onPressed == null) return glass;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(borderRadius),
          splashColor: Colors.white.withValues(alpha: 0.08),
          highlightColor: Colors.black.withValues(alpha: 0.08),
          child: glass,
        ),
      ),
    );
  }
}

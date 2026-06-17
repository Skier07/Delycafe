import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

class AddToCartDropletOrigin {
  final Offset globalCenter;
  final Size buttonSize;
  final Color color;
  final double borderRadius;

  const AddToCartDropletOrigin({
    required this.globalCenter,
    required this.buttonSize,
    required this.color,
    this.borderRadius = 14,
  });
}

class CartAnimationTarget {
  static Offset resolve(
    BuildContext context,
    GlobalKey? cartIconKey,
  ) {
    final cartBox =
        cartIconKey?.currentContext?.findRenderObject() as RenderBox?;

    if (cartBox != null && cartBox.hasSize) {
      final topLeft = cartBox.localToGlobal(Offset.zero);
      final center = topLeft + cartBox.size.center(Offset.zero);
      final screenHeight = MediaQuery.sizeOf(context).height;

      if (center.dy >= -20 && center.dy <= screenHeight + 20) {
        return center;
      }
    }

    final screenSize = MediaQuery.sizeOf(context);

    return Offset(
      screenSize.width - 36,
      screenSize.height * 0.22,
    );
  }
}

/// Кнопка «В корзину» сжимается в круглую каплю и летит к корзине.
class AddToCartDropletAnimation {
  static const Duration duration = Duration(milliseconds: 650);
  static const double _squeezePhase = 0.22;

  static Future<void> play({
    required BuildContext context,
    required AddToCartDropletOrigin origin,
    required Offset end,
  }) {
    final overlay = Overlay.of(context, rootOverlay: true);
    final completer = Completer<void>();

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) {
        return _DropletFlyOverlay(
          origin: origin,
          end: end,
          onComplete: () {
            entry.remove();
            if (!completer.isCompleted) {
              completer.complete();
            }
          },
        );
      },
    );

    overlay.insert(entry);
    return completer.future;
  }
}

class _DropletFlyOverlay extends StatefulWidget {
  final AddToCartDropletOrigin origin;
  final Offset end;
  final VoidCallback onComplete;

  const _DropletFlyOverlay({
    required this.origin,
    required this.end,
    required this.onComplete,
  });

  @override
  State<_DropletFlyOverlay> createState() => _DropletFlyOverlayState();
}

class _DropletFlyOverlayState extends State<_DropletFlyOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AddToCartDropletAnimation.duration,
    )..forward().whenComplete(widget.onComplete);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Offset _bezierPoint(Offset start, Offset end, double t) {
    final control = Offset(
      (start.dx + end.dx) / 2,
      math.min(start.dy, end.dy) - 64 - (start.dx - end.dx).abs() * 0.05,
    );
    final inverse = 1 - t;

    return Offset(
      inverse * inverse * start.dx + 2 * inverse * t * control.dx + t * t * end.dx,
      inverse * inverse * start.dy + 2 * inverse * t * control.dy + t * t * end.dy,
    );
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = _controller.value;
          final origin = widget.origin;
          final dropletSize = math.max(
            math.min(origin.buttonSize.width, origin.buttonSize.height),
            14,
          );

          late Offset center;
          late double width;
          late double height;
          late double radius;
          late double opacity;

          if (progress <= AddToCartDropletAnimation._squeezePhase) {
            final squeeze = Curves.easeInOut.transform(
              progress / AddToCartDropletAnimation._squeezePhase,
            );

            center = origin.globalCenter;
            width = lerpDouble(origin.buttonSize.width, dropletSize, squeeze)!;
            height = lerpDouble(origin.buttonSize.height, dropletSize, squeeze)!;
            radius = lerpDouble(
              origin.borderRadius,
              dropletSize / 2,
              squeeze,
            )!;
            opacity = 1;
          } else {
            final flyRaw = ((progress - AddToCartDropletAnimation._squeezePhase) /
                    (1 - AddToCartDropletAnimation._squeezePhase))
                .clamp(0.0, 1.0);
            final fly = Curves.easeInOutCubic.transform(flyRaw);
            final fadeOut =
                fly > 0.82 ? ((1 - fly) / 0.18).clamp(0.0, 1.0) : 1.0;

            center = _bezierPoint(origin.globalCenter, widget.end, fly);
            final size = lerpDouble(dropletSize, dropletSize * 0.65, fly)!;
            width = size;
            height = size;
            radius = size / 2;
            opacity = fadeOut;
          }

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: center.dx - width / 2,
                top: center.dy - height / 2,
                child: Opacity(
                  opacity: opacity,
                  child: Container(
                    width: width,
                    height: height,
                    decoration: BoxDecoration(
                      color: origin.color,
                      borderRadius: BorderRadius.circular(radius),
                      boxShadow: [
                        BoxShadow(
                          color: origin.color.withValues(alpha: 0.35),
                          blurRadius: 8,
                          spreadRadius: 0.5,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

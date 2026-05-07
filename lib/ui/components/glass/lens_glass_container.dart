import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class LensGlassContainer extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final EdgeInsets padding;
  final double borderRadius;
  final Color tint;
  final double lensStrength;

  const LensGlassContainer({
    super.key,
    required this.child,
    this.onPressed,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    this.borderRadius = 26,
    this.tint = const Color(0xFF5AC8FA),
    this.lensStrength = 0.12,
  });

  @override
  State<LensGlassContainer> createState() => _LensGlassContainerState();
}

class _LensGlassContainerState extends State<LensGlassContainer> {
  ui.FragmentShader? _shader;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _loadShader();
  }

  Future<void> _loadShader() async {
    final program = await ui.FragmentProgram.fromAsset(
      'shaders/lens_glass.frag',
    );

    if (!mounted) return;

    setState(() {
      _shader = program.fragmentShader();
    });
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _updateShaderUniforms() {
    if (_shader == null) return;
    _shader!
      ..setFloat(2, widget.lensStrength)
      ..setFloat(3, widget.tint.r)
      ..setFloat(4, widget.tint.g)
      ..setFloat(5, widget.tint.b)
      ..setFloat(6, widget.tint.a)
      ..setFloat(7, _pressed ? 1.0 : 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.borderRadius);

    final fallback = _FallbackLensGlass(
      padding: widget.padding,
      borderRadius: widget.borderRadius,
      tint: widget.tint,
      pressed: _pressed,
      child: widget.child,
    );

    if (!ui.ImageFilter.isShaderFilterSupported || _shader == null) {
      return _wrapInteractive(fallback);
    }

    _updateShaderUniforms();

    final lens = IntrinsicWidth(
      child: IntrinsicHeight(
        child: ClipRRect(
          borderRadius: radius,
          child: SizedBox(
            child: Stack(
              children: [
                // =========================
                // 1. ТЁМНАЯ БАЗА (ВАЖНО!)
                // =========================
                Container(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    color: Colors.black.withValues(alpha: 0.18),
                  ),
                ),

                // =========================
                // 2. ЛИНЗА (shader)
                // =========================
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.shader(_shader!),
                    child: const SizedBox(),
                  ),
                ),

                // =========================
                // 3. FRESNEL / EDGE LIGHT
                // =========================
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: radius,
                        gradient: RadialGradient(
                          center: const Alignment(0.0, 0.0),
                          radius: 1.2,
                          colors: [
                            Colors.transparent,
                            widget.tint.withValues(alpha: 0.10),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // =========================
                // 4. ВЕРХНИЙ БЛИК (очень мягкий)
                // =========================
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: radius,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.18),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // =========================
                // 5. КОНТЕНТ (САМОЕ ВАЖНОЕ — В КОНЦЕ)
                // =========================
                Center(
                  child: Padding(
                    padding: widget.padding,
                    child: widget.child,
                  ),
                ),

                // =========================
                // 6. ГРАНИЦА
                // =========================
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: radius,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),

                // =========================
                // 7. НАЖАТИЕ
                // =========================
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 90),
                      decoration: BoxDecoration(
                        borderRadius: radius,
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
        ),
      ),
    );

    return _wrapInteractive(lens);
  }

  Widget _wrapInteractive(Widget child) {
    final scaled = AnimatedScale(
      duration: const Duration(milliseconds: 90),
      scale: _pressed ? 0.97 : 1,
      child: child,
    );

    if (widget.onPressed == null) {
      return scaled;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onPressed,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: scaled,
      ),
    );
  }
}

class _FallbackLensGlass extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final Color tint;
  final bool pressed;

  const _FallbackLensGlass({
    required this.child,
    required this.padding,
    required this.borderRadius,
    required this.tint,
    required this.pressed,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Stack(
          children: [
            Container(
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.16),
                    Colors.white.withValues(alpha: 0.06),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.22),
                ),
              ),
              child: Center(child: child),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(borderRadius),
                    gradient: RadialGradient(
                      center: const Alignment(-0.7, -0.8),
                      radius: 1.3,
                      colors: [
                        tint.withValues(alpha: 0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 90),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(borderRadius),
                    color: Colors.black.withValues(
                      alpha: pressed ? 0.10 : 0.0,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

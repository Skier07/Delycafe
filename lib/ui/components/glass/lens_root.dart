import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'lens_controller.dart';

class LensRoot extends StatefulWidget {
  final Widget child;
  const LensRoot({super.key, required this.child});

  @override
  State<LensRoot> createState() => _LensRootState();
}

class _LensRootState extends State<LensRoot> {
  final GlobalKey _key = GlobalKey();

  Future<void> _capture() async {
    final boundary =
        _key.currentContext?.findRenderObject() as RenderRepaintBoundary?;

    if (boundary == null) return;

    final image = await boundary.toImage(pixelRatio: 2.0);

    LensController.snapshot = image;
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _capture();
    });

    return RepaintBoundary(
      key: _key,
      child: widget.child,
    );
  }
}

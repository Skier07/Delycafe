import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class DarkGlassSheet extends StatelessWidget {
  final List<Widget> children;
  final double widthFactor;
  final VoidCallback onClose;

  const DarkGlassSheet({
    super.key,
    required this.children,
    required this.onClose,
    this.widthFactor = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final sheetWidth = screenWidth * widthFactor;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: Container(
              color: Colors.black.withValues(alpha: 0.26),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              bottomLeft: Radius.circular(28),
            ),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                width: sheetWidth,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: [
                      Colors.black.withValues(alpha: 0.38),
                      Colors.black.withValues(alpha: 0.22),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.20),
                      blurRadius: 16,
                      offset: const Offset(-4, 0),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Меню',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            IconButton(
                              onPressed: onClose,
                              icon: Icon(
                                Icons.close,
                                color: Colors.white.withValues(alpha: 0.90),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                          children: children,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class DarkGlassSheetItem extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final bool isDanger;

  const DarkGlassSheetItem({
    super.key,
    required this.title,
    required this.onTap,
    this.isDanger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDanger
        ? Colors.redAccent.withValues(alpha: 0.95)
        : Colors.white.withValues(alpha: 0.95);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class DarkGlassSheetDivider extends StatelessWidget {
  const DarkGlassSheetDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: Colors.white.withValues(alpha: 0.08),
    );
  }
}

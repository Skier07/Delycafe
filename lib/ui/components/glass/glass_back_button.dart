import 'package:delycafe/ui/components/glass/shader_glass_container.dart';
import 'package:delycafe/ui/tokens/app_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Shared back control. Custom callbacks keep payment/confirmation flows intact.
class GlassBackButton extends StatelessWidget {
  const GlassBackButton(
      {super.key,
      this.onPressed,
      this.lightBackground = false,
      this.busy = false});

  final VoidCallback? onPressed;
  final bool lightBackground;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final color = lightBackground ? AppColors.header : Colors.white;
    return Semantics(
      button: true,
      enabled: !busy,
      label: busy ? 'Проверяем оплату' : 'Назад',
      child: SizedBox.square(
        dimension: 46,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: lightBackground
                    ? const Color(0x240C204D)
                    : const Color(0x55FFFFFF),
                width: .8),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x160C204D),
                  blurRadius: 8,
                  offset: Offset(0, 1),
                  blurStyle: BlurStyle.outer)
            ],
          ),
          child: ShaderGlassContainer(
            // Scrolling Android back controls avoid the unstable shader path.
            forceSimpleBlur: defaultTargetPlatform == TargetPlatform.android,
            padding: EdgeInsets.zero,
            borderRadius: 22,
            blur: 8,
            liquidBlur: 8,
            onPressed: busy
                ? null
                : (onPressed ?? () => Navigator.of(context).maybePop()),
            child: Center(
                child: busy
                    ? SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.2, color: color))
                    : Icon(CupertinoIcons.chevron_left_2,
                        color: color, size: 24)),
          ),
        ),
      ),
    );
  }
}

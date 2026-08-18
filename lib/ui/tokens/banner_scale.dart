import 'package:delycafe/ui/tokens/app_sizes.dart';
import 'package:flutter/material.dart';

/// Масштаб элементов баннера от логической ширины экрана.
///
/// При ширине iPhone 13 (390 pt) коэффициент около 0.87, поэтому кнопки
/// остаются удобными для нажатия, но не занимают значительную часть баннера.
class BannerScale {
  BannerScale._(this._scale);

  static const double _referenceWidth = 450;

  final double _scale;

  double get factor => _scale;

  static BannerScale of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final scale = (width / _referenceWidth).clamp(0.85, 1.0);
    return BannerScale._(scale);
  }

  double _s(double value) => value * _scale;

  double get iconSize => _s(AppSizes.buttonSize);

  double get glassPadding => _s(8);

  double get glassRadius => _s(30);

  double get bannerPadding => _s(12);

  double get loginLeft => _s(24);

  double get loginTop => _s(58);

  double get loginFontSize => _s(50);

  double get loginChevronSize => _s(40);

  double get loginLetterSpacing => _s(-1);

  double get loginChevronGap => _s(4);

  double get bonusFontSize => _s(20);

  double get bonusPaddingH => _s(12);

  double get bonusPaddingV => _s(8);

  double get bonusIconGap => _s(8);

  double get badgeTop => _s(25);

  double get badgeRight => _s(40);

  double get badgeFontSize => _s(11);

  double get badgePaddingH => _s(6);

  double get badgePaddingV => _s(2);

  double get badgeRadius => _s(10);
}

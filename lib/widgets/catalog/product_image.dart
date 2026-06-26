import 'package:cached_network_image/cached_network_image.dart';
import 'package:delycafe/config/api_config.dart';
import 'package:delycafe/ui/tokens/app_colors.dart';
import 'package:flutter/material.dart';

class ProductImage extends StatelessWidget {
  final String image;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const ProductImage({
    super.key,
    required this.image,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedImage = ApiConfig.normalizeMediaUrl(image);
    final child = _buildImage(normalizedImage);

    if (borderRadius == null) {
      return child;
    }

    return ClipRRect(
      borderRadius: borderRadius!,
      child: child,
    );
  }

  Widget _buildImage(String normalizedImage) {
    final resolvedWidth = width ?? double.infinity;
    final resolvedHeight = height ?? double.infinity;

    if (normalizedImage.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: normalizedImage,
        fit: fit,
        width: resolvedWidth,
        height: resolvedHeight,
        fadeInDuration: const Duration(milliseconds: 180),
        placeholder: (context, url) => const _ImagePlaceholder(
          showProgress: true,
        ),
        errorWidget: (context, url, error) => const _ImagePlaceholder(),
      );
    }

    if (normalizedImage.startsWith('assets/')) {
      return Image.asset(
        normalizedImage,
        fit: fit,
        width: resolvedWidth,
        height: resolvedHeight,
        errorBuilder: (context, error, stackTrace) {
          return const _ImagePlaceholder();
        },
      );
    }

    return const _ImagePlaceholder();
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final bool showProgress;

  const _ImagePlaceholder({
    this.showProgress = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.header.withValues(alpha: 0.08),
      alignment: Alignment.center,
      child: showProgress
          ? SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: AppColors.header.withValues(alpha: 0.55),
              ),
            )
          : Icon(
              Icons.restaurant_menu,
              size: 44,
              color: AppColors.header.withValues(alpha: 0.45),
            ),
    );
  }
}

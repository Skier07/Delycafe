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
    final normalizedImage = _normalizedImageUrl(image);
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
    if (normalizedImage.startsWith('http')) {
      return Image.network(
        normalizedImage,
        fit: fit,
        width: width ?? double.infinity,
        height: height ?? double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return const _ImagePlaceholder();
        },
      );
    }
    if (normalizedImage.isEmpty) {
      return Image.asset(
        normalizedImage,
        fit: fit,
        width: width ?? double.infinity,
        height: height ?? double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return const _ImagePlaceholder();
        },
      );
    }
    return const _ImagePlaceholder();
  }

  String _normalizedImageUrl(String value) {
    final imagePath = value.trim();

    if (imagePath.startsWith('http://127.0.0.1:8000')) {
      return imagePath.replaceFirst(
        'http://127.0.0.1:8000',
        'http://10.0.2.2:8000',
      );
    }

    if (imagePath.startsWith('http://localhost:8000')) {
      return imagePath.replaceFirst(
        'http://localhost:8000',
        'http://10.0.2.2:8000',
      );
    }
    return imagePath;
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.header.withValues(alpha: 0.08),
      alignment: Alignment.center,
      child: Icon(
        Icons.restaurant_menu,
        size: 44,
        color: AppColors.header.withValues(alpha: 0.45),
      ),
    );
  }
}

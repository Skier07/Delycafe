import 'package:cached_network_image/cached_network_image.dart';
import 'package:delycafe/config/api_config.dart';
import 'package:delycafe/models/content_post.dart';
import 'package:delycafe/ui/tokens/app_colors.dart';
import 'package:flutter/material.dart';

class ContentBlocksRenderer extends StatelessWidget {
  final List<ContentLine> lines;
  final EdgeInsetsGeometry padding;

  const ContentBlocksRenderer({
    super.key,
    required this.lines,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < lines.length; index++) ...[
            if (index > 0) const SizedBox(height: 10),
            _ContentLineView(line: lines[index], index: index),
          ],
        ],
      ),
    );
  }
}

class _ContentLineView extends StatelessWidget {
  final ContentLine line;
  final int index;

  const _ContentLineView({
    required this.line,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    if (line.type == 'spacer') {
      return const SizedBox(height: 12);
    }

    if (line.type == 'image') {
      return _ImageBlock(line: line);
    }

    return _TextBlock(line: line, index: index);
  }
}

class _TextBlock extends StatelessWidget {
  final ContentLine line;
  final int index;

  const _TextBlock({
    required this.line,
    required this.index,
  });

  TextAlign get _align {
    switch (line.align) {
      case 'center':
        return TextAlign.center;
      case 'right':
        return TextAlign.right;
      default:
        return TextAlign.left;
    }
  }

  double get _fontSize {
    switch (line.fontSize) {
      case 'small':
        return 13;
      case 'large':
        return 18;
      case 'xlarge':
        return 22;
      default:
        return 15;
    }
  }

  String? get _fontFamily {
    switch (line.fontFamily) {
      case 'serif':
        return 'serif';
      case 'mono':
        return 'monospace';
      default:
        return null;
    }
  }

  Color get _color {
    final raw = line.color.trim();
    if (raw.startsWith('#') && (raw.length == 7 || raw.length == 4)) {
      try {
        final hex = raw.length == 4
            ? '#${raw[1]}${raw[1]}${raw[2]}${raw[2]}${raw[3]}${raw[3]}'
            : raw;
        return Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);
      } catch (_) {
        // fall through
      }
    }

    return Colors.black.withValues(alpha: 0.78);
  }

  String get _prefix {
    switch (line.marker) {
      case 'bullet':
        return '• ';
      case 'dash':
        return '— ';
      case 'number':
        return '${index + 1}. ';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '$_prefix${line.text}',
      textAlign: _align,
      style: TextStyle(
        color: _color,
        fontSize: _fontSize,
        height: 1.45,
        fontFamily: _fontFamily,
        fontWeight: line.bold ? FontWeight.w700 : FontWeight.w500,
        fontStyle: line.italic ? FontStyle.italic : FontStyle.normal,
        decoration:
            line.underline ? TextDecoration.underline : TextDecoration.none,
      ),
    );
  }
}

class _ImageBlock extends StatelessWidget {
  final ContentLine line;

  const _ImageBlock({required this.line});

  @override
  Widget build(BuildContext context) {
    final url = ApiConfig.normalizeMediaUrl(line.imageUrl);
    if (url.isEmpty) {
      return const SizedBox.shrink();
    }

    final image = ClipRRect(
      borderRadius: line.fullBleed
          ? BorderRadius.zero
          : BorderRadius.circular(16),
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: double.infinity,
        placeholder: (_, __) => Container(
          height: 160,
          color: AppColors.header.withValues(alpha: 0.08),
        ),
        errorWidget: (_, __, ___) => Container(
          height: 120,
          alignment: Alignment.center,
          color: Colors.black12,
          child: const Icon(Icons.broken_image_outlined),
        ),
      ),
    );

    if (line.fullBleed) {
      return image;
    }

    Alignment alignment;
    switch (line.align) {
      case 'left':
        alignment = Alignment.centerLeft;
        break;
      case 'right':
        alignment = Alignment.centerRight;
        break;
      default:
        alignment = Alignment.center;
    }

    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: image,
      ),
    );
  }
}

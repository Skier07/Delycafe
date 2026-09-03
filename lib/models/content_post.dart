class ContentLine {
  final String type;
  final String text;
  final String marker;
  final String fontSize;
  final String fontFamily;
  final String align;
  final String color;
  final bool bold;
  final bool italic;
  final bool underline;
  final String imageUrl;
  final bool fullBleed;

  const ContentLine({
    this.type = 'text',
    this.text = '',
    this.marker = 'none',
    this.fontSize = 'normal',
    this.fontFamily = 'default',
    this.align = 'left',
    this.color = '',
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.imageUrl = '',
    this.fullBleed = false,
  });

  factory ContentLine.fromJson(Map<String, dynamic> json) {
    return ContentLine(
      type: json['type']?.toString() ?? 'text',
      text: json['text']?.toString() ?? '',
      marker: json['marker']?.toString() ?? 'none',
      fontSize: json['font_size']?.toString() ?? 'normal',
      fontFamily: json['font_family']?.toString() ?? 'default',
      align: json['align']?.toString() ?? 'left',
      color: json['color']?.toString() ?? '',
      bold: json['bold'] == true,
      italic: json['italic'] == true,
      underline: json['underline'] == true,
      imageUrl: json['image_url']?.toString() ?? '',
      fullBleed: json['full_bleed'] == true,
    );
  }
}

class ContentPost {
  final int id;
  final String postType;
  final String title;
  final String coverImage;
  final List<ContentLine> bodyLines;
  final String plainText;
  final int sortOrder;

  const ContentPost({
    required this.id,
    required this.postType,
    required this.title,
    required this.coverImage,
    required this.bodyLines,
    required this.plainText,
    required this.sortOrder,
  });

  factory ContentPost.fromJson(Map<String, dynamic> json) {
    final linesJson = json['body_lines'];

    return ContentPost(
      id: _toInt(json['id']),
      postType: json['post_type']?.toString() ?? 'news',
      title: json['title']?.toString() ?? '',
      coverImage: json['cover_image']?.toString() ?? '',
      bodyLines: linesJson is List
          ? linesJson
              .whereType<Map>()
              .map(
                (item) => ContentLine.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
          : const [],
      plainText: json['plain_text']?.toString() ?? '',
      sortOrder: _toInt(json['sort_order'], fallback: 500),
    );
  }

  static int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}

class AppPageContent {
  final String key;
  final String title;
  final List<ContentLine> bodyLines;
  final String plainText;
  final Map<String, String> placeholders;

  const AppPageContent({
    required this.key,
    required this.title,
    required this.bodyLines,
    required this.plainText,
    this.placeholders = const {},
  });

  factory AppPageContent.fromJson(Map<String, dynamic> json) {
    final linesJson = json['body_lines'];
    final placeholdersJson = json['placeholders'];

    return AppPageContent(
      key: json['key']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      bodyLines: linesJson is List
          ? linesJson
              .whereType<Map>()
              .map(
                (item) => ContentLine.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
          : const [],
      plainText: json['plain_text']?.toString() ?? '',
      placeholders: placeholdersJson is Map
          ? placeholdersJson.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : const {},
    );
  }
}

class PromotionPercents {
  final int earnPercent;
  final int maxSpendPercent;
  final int pickupDiscountPercent;

  const PromotionPercents({
    required this.earnPercent,
    required this.maxSpendPercent,
    required this.pickupDiscountPercent,
  });

  factory PromotionPercents.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return PromotionPercents.fallback();
    }

    return PromotionPercents(
      earnPercent: _positive(json['earn_percent'], 3),
      maxSpendPercent: _positive(json['max_spend_percent'], 25),
      pickupDiscountPercent: _positive(json['pickup_discount_percent'], 5),
    );
  }

  factory PromotionPercents.fallback() {
    return const PromotionPercents(
      earnPercent: 3,
      maxSpendPercent: 25,
      pickupDiscountPercent: 5,
    );
  }

  static int _positive(dynamic value, int fallback) {
    int parsed = fallback;
    if (value is int) {
      parsed = value;
    } else if (value is double) {
      parsed = value.round();
    } else if (value is String) {
      parsed = int.tryParse(value) ?? fallback;
    }
    return parsed > 0 ? parsed : fallback;
  }
}

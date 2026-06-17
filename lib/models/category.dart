class Category {
  final int id;
  final String title;
  final String slug;
  final int sortOrder;

  Category({
    required this.id,
    required this.title,
    required this.slug,
    required this.sortOrder,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'slug': slug,
      'sort_order': sortOrder,
    };
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: _toInt(json['id']),
      title: json['title']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      sortOrder: _toInt(json['sort_order'], defaultValue: 500),
    );
  }
}

int _toInt(
  dynamic value, {
  int defaultValue = 0,
}) {
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) return int.tryParse(value) ?? defaultValue;

  return defaultValue;
}

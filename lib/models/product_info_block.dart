class ProductInfoLine {
  final String text;
  final String marker;
  final String fontSize;
  final bool bold;
  final bool italic;
  final bool underline;
  final int number;

  const ProductInfoLine({
    required this.text,
    this.marker = 'bullet',
    this.fontSize = 'normal',
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.number = 0,
  });

  factory ProductInfoLine.fromJson(Map<String, dynamic> json) {
    return ProductInfoLine(
      text: json['text']?.toString() ?? '',
      marker: json['marker']?.toString() ?? 'bullet',
      fontSize: json['font_size']?.toString() ?? 'normal',
      bold: json['bold'] == true,
      italic: json['italic'] == true,
      underline: json['underline'] == true,
      number: _toInt(json['number']),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value) ?? 0;

    return 0;
  }
}

class ProductInfoBlock {
  final String section;
  final String title;
  final String text;
  final String style;
  final List<ProductInfoLine> lines;

  const ProductInfoBlock({
    required this.section,
    required this.title,
    required this.text,
    this.style = 'normal',
    this.lines = const [],
  });

  bool get isWarning => style == 'warning';

  List<ProductInfoLine> resolvedLines() {
    if (lines.isNotEmpty) {
      return lines;
    }

    final trimmed = text.trim();

    if (trimmed.isEmpty) {
      return const [];
    }

    return [
      ProductInfoLine(text: trimmed),
    ];
  }

  Map<String, dynamic> toJson() {
    return {
      'section': section,
      'title': title,
      'text': text,
      'style': style,
      'lines': lines
          .map(
            (line) => {
              'text': line.text,
              'marker': line.marker,
              'font_size': line.fontSize,
              'bold': line.bold,
              'italic': line.italic,
              'underline': line.underline,
              'number': line.number,
            },
          )
          .toList(),
    };
  }

  factory ProductInfoBlock.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'];

    return ProductInfoBlock(
      section: json['section']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      style: json['style']?.toString() ?? 'normal',
      lines: rawLines is List
          ? rawLines
              .map(
                (line) => ProductInfoLine.fromJson(
                  line as Map<String, dynamic>,
                ),
              )
              .toList(growable: false)
          : const [],
    );
  }
}

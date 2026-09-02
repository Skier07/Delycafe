import 'package:delycafe/models/product_info_block.dart';
import 'package:flutter_test/flutter_test.dart';
void main() {
  test('parses info line maps from Hive-style dynamic maps', () {
    final block = ProductInfoBlock.fromJson({
      'section': 'shelf_life',
      'title': 'Срок годности',
      'text': '',
      'style': 'normal',
      'lines': [
        {
          'text': '48 часов',
          'marker': 'bullet',
          'font_size': 'normal',
          'bold': false,
          'italic': false,
          'underline': false,
          'number': 1,
        },
      ],
    });

    expect(block.resolvedLines().single.text, '48 часов');
  });

  test('parses lines stored as Map<dynamic, dynamic>', () {
    final dynamicLine = <dynamic, dynamic>{
      'text': 'Сутки',
      'marker': 'bullet',
      'font_size': 'normal',
      'bold': true,
      'italic': false,
      'underline': false,
      'number': 2,
    };

    final block = ProductInfoBlock.fromJson({
      'section': 'shelf_life',
      'title': 'Срок',
      'text': '',
      'lines': [dynamicLine],
    });

    expect(block.resolvedLines().single.text, 'Сутки');
    expect(block.resolvedLines().single.bold, isTrue);
  });
}

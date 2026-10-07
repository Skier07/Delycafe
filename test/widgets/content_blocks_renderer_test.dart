import 'package:cached_network_image/cached_network_image.dart';
import 'package:delycafe/models/content_post.dart';
import 'package:delycafe/widgets/content/content_blocks_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CMS icon stays small and left of wrapping text', (tester) async {
    final line = ContentLine.fromJson({
      'text': 'Бонусы начисляются после оплаты заказа и доступны в приложении.',
      'icon_url': '/media/bonus.png',
    });
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 220,
            child: ContentBlocksRenderer(lines: [line]),
          ),
        ),
      ),
    ));
    final icon = find.byType(CachedNetworkImage);
    final text = find.text(line.text);
    expect(tester.getSize(icon), const Size(24, 24));
    expect(tester.getTopLeft(text).dx, tester.getTopRight(icon).dx + 10);
    expect(tester.getTopLeft(text).dy, tester.getTopLeft(icon).dy);
    expect(tester.getSize(text).height, greaterThan(24));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('existing text without an icon remains text-only',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
          body: ContentBlocksRenderer(lines: [
        ContentLine(text: 'Правила бонусной программы'),
      ])),
    ));
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.text('Правила бонусной программы'), findsOneWidget);
  });
}

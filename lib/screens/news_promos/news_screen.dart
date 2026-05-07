import 'package:delycafe/screens/news_promos/news_detail_screen.dart';
import 'package:flutter/material.dart';

class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final news = [
      {
        'title': 'Скидка в день рождения',
        'image': 'assets/images/birthday.jpg',
        'text': '🎉 Скидка 20% в день вашего рождения (за 2 дня до и после даты).\n\n'
            'Скидка не распространяется на пироги.\n\n'
            'Чтобы получить скидку, ИМЕНИННИК должен предъявить паспорт.\n'
            'Предъявить чужой паспорт не получится.\n\n'
            'Если день рождения отмечает ребенок — нужен паспорт родителей.\n\n'
            'Внимание! Скидка 1 раз в год (1 заказ).',
      },
      {
        'title': 'График работы 2026',
        'image': 'assets/images/29_dec.jpg',
        'text': '31 декабря: с 9:00 до 19:00\n\n'
            '1, 2 января - выходной\n\n'
            'С 3 января по обычному графику\n\n',
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: news.length,
      itemBuilder: (context, i) {
        final item = news[i];

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => NewsDetailScreen(
                  title: item['title']!,
                  text: item['text']!,
                  image: item['image']!,
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            height: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              image: DecorationImage(
                image: AssetImage(item['image']!),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent,
                  ],
                ),
              ),
              padding: const EdgeInsets.all(16),
              alignment: Alignment.bottomLeft,
              child: Text(
                item['title']!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

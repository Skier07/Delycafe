import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class NewsTabsScreen extends StatelessWidget {
  final String type;

  const NewsTabsScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final data = _getData();

    return Scaffold(
      body: Stack(
        children: [
          // фон картинка
          Image.asset(
            data.image,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          ),

          // затемнение
          Container(
            color: Colors.black.withValues(alpha: 0.4),
          ),

          // контент
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    color: Colors.black.withValues(alpha: 0.55),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          data.text,
                          style: const TextStyle(
                            color: Colors.white,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  _NewsData _getData() {
    if (type == 'birthday') {
      return _NewsData(
        title: 'Скидка в день рождения',
        image: 'assets/images/birthday.jpg',
        text: 'Скидка 20% в день рождения (±2 дня).\n\n'
            '–20% в день рождения\n(за 2 дня до и после)\n\n'
            '• не действует на пироги\n'
            '• нужен паспорт\n'
            '• 1 раз в год',
      );
    }

    return _NewsData(
      title: 'График работы 2026',
      image: 'assets/images/new_year_schedule.jpg',
      text: 'Актуальное расписание работы в праздничные дни.',
    );
  }
}

class _NewsData {
  final String title;
  final String image;
  final String text;

  _NewsData({
    required this.title,
    required this.image,
    required this.text,
  });
}

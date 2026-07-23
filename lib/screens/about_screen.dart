import 'dart:ui' as ui;

import 'package:delycafe/ui/components/glass/shader_glass_container.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Scaffold(
      backgroundColor: const ui.Color(0xFFFEF7FF),
      body: Stack(
        children: [
          // НИЖНЯЯ КАРТИНКА (фикс снизу, НЕ растягиваем)
          Align(
            alignment: Alignment.bottomCenter,
            child: Image.asset(
              'assets/images/about-page-bg.png',
              width: double.infinity,
              fit: BoxFit.fitWidth, // ключевая правка
            ),
          ),

          // ВЕРХНЯЯ КАРТИНКА
          SizedBox(
            height: screenHeight * 0.45,
            width: double.infinity,
            child: Image.asset(
              'assets/images/delycafe.jpg',
              fit: BoxFit.cover,
            ),
          ),

          // КНОПКА НАЗАД
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ShaderGlassContainer(
                borderRadius: 30,
                onPressed: () => Navigator.pop(context),
                padding: const EdgeInsets.all(8),
                child: const Icon(
                  CupertinoIcons.chevron_left_2,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),

          // ТЕКСТОВАЯ ПЛАШКА
          Positioned.fill(
            child: Column(
              children: [
                SizedBox(height: screenHeight * 0.25),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(
                          sigmaX: 14,
                          sigmaY: 14,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),

                            // ТЁМНОЕ СТЕКЛО (чтобы читалось)
                            color: Colors.black.withValues(alpha: 0.55),

                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                          child: const _AboutText(),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutText extends StatelessWidget {
  const _AboutText();

  @override
  Widget build(BuildContext context) {
    return const DefaultTextStyle(
      style: TextStyle(
        color: Colors.white,
        height: 1.6,
        fontSize: 15.5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'О компании',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Деликафе – кафе-доставка в Озёрске. Мы работаем ежедневно с 9 до 21, '
            'а в пятницу и субботу — до 22 часов, в воскресенье — до 21 часа.\n\n'
            'Приём заказов в приложении: с 10:00, вс–чт до 20:30, пт–сб до 21:30.',
          ),
          SizedBox(height: 10),
          Text(
            'Находимся на Кыштымской, 11 — через дорогу от «Камелота», рядом с робо-мойкой.',
          ),
          SizedBox(height: 10),
          Text(
            'У нас отличные повара, новое оборудование, быстрая доставка по городу и сильное желание стать лучшими.',
          ),
          SizedBox(height: 20),
          Text(
            'Деликафе — мы не достаём из холодильника, чтобы разогреть и подать на стол.',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 8),
          Text(
            'Мы готовим. Готовим для вас!',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
        ],
      ),
    );
  }
}

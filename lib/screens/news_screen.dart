import 'package:delycafe/screens/news_tabs_screen.dart';
import 'package:flutter/material.dart';

class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _NewsBanner(
          title: 'Скидка в день рождения',
          image: 'assets/images/birthday.jpg',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NewsTabsScreen(type: 'birthday'),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        _NewsBanner(
          title: 'График работы 2026',
          image: 'assets/images/new_year_schedule.jpg',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const NewsTabsScreen(type: 'newyear'),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _NewsBanner extends StatelessWidget {
  final String title;
  final String image;
  final VoidCallback onTap;

  const _NewsBanner({
    required this.title,
    required this.image,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Image.asset(
              image,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.35),
              ),
            ),
            Positioned(
              left: 16,
              bottom: 16,
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

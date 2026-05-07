import 'package:delycafe/screens/news_promos/news_screen.dart';
import 'package:delycafe/screens/news_promos/promo_screen.dart';
import 'package:delycafe/ui/components/glass/shader_glass_container.dart';
import 'package:delycafe/ui/tokens/app_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class NewsAndPromoScreen extends StatefulWidget {
  const NewsAndPromoScreen({super.key});

  @override
  State<NewsAndPromoScreen> createState() => _NewsAndPromoScreenState();
}

class _NewsAndPromoScreenState extends State<NewsAndPromoScreen> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEF7FF),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.header,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 64,
        titleSpacing: 16,
        title: Row(
          children: [
            ShaderGlassContainer(
              borderRadius: 30,
              onPressed: () => Navigator.pop(context),
              padding: const EdgeInsets.all(8),
              child: const Icon(
                CupertinoIcons.chevron_left_2,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Новости и акции',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 14),

            // ПЕРЕКЛЮЧАТЕЛЬ
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.black.withValues(alpha: 0.1),
              ),
              child: Row(
                children: [
                  _tabButton('Новости', 0),
                  _tabButton('Акции', 1),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // КОНТЕНТ
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: index == 0 ? const NewsScreen() : const PromoScreen(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(String title, int i) {
    final selected = index == i;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => index = i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: selected ? Colors.white : Colors.transparent,
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: selected ? Colors.black : Colors.black54,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

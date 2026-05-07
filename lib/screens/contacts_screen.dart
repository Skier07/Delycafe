import 'package:delycafe/ui/components/glass/shader_glass_container.dart';
import 'package:delycafe/ui/tokens/app_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.header,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leadingWidth: 60,
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 40,
              height: 40,
              child: ShaderGlassContainer(
                padding: const EdgeInsets.all(6),
                borderRadius: 20,
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Icon(
                  CupertinoIcons.chevron_left_2,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ),
        title: const Text('Контакты'),
        foregroundColor: Colors.white.withValues(alpha: 0.9),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const _ContactCard(
              icon: CupertinoIcons.location,
              title: 'Адрес',
              content: 'г. Озёрск, ул. Кыштымская, 11',
            ),
            const SizedBox(height: 14),
            const _ContactCard(
              icon: CupertinoIcons.phone,
              title: 'Телефон',
              content: '+7 (900) 022 30 22',
            ),
            const SizedBox(height: 14),
            const _ContactCard(
              icon: CupertinoIcons.clock,
              title: 'Время работы',
              content: '9:00 - 21:00',
            ),
            const SizedBox(height: 18),
            ShaderGlassContainer(
              borderRadius: 20,
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    CupertinoIcons.exclamationmark_triangle,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Внимание! Кухня закрывается за 30 минут до конца рабочего дня.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;

  const _ContactCard(
      {required this.icon, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return ShaderGlassContainer(
      borderRadius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.white.withValues(alpha: 0.8),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  content,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

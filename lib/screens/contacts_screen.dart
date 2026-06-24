import 'package:delycafe/services/auth_service.dart';
import 'package:delycafe/services/jivo_service.dart';
import 'package:delycafe/ui/components/glass/shader_glass_container.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
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
              'Контакты',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/contacts_bg_01.png',
              fit: BoxFit.cover,
            ),
          ),

          // затемнение поверх картинки
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.black.withValues(alpha: 0.45),
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                const _ContactCard(
                  title: 'Телефон',
                  child: Text(
                    '+7 (900) 022-30-22',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ShaderGlassContainer(
                  borderRadius: 20,
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 20,
                  ),
                  onPressed: () {
                    final user = context.read<AuthService>().currentUser;

                    JivoService.openSupportChat(
                      context,
                      user: user,
                    );
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.chat_bubble_text,
                        color: Colors.white,
                        size: 22,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Написать',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const _ContactCard(
                  title: 'Адрес',
                  child: Text(
                    'г. Озёрск, ул. Кыштымская, д. 11',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const _ContactCard(
                  title: 'Время работы',
                  child: Text(
                    '09:00 до 21:00',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _ContactCard(
                  title: 'Внимание!',
                  child: Text(
                    'Кухня закрывается за 30 минут до конца рабочего дня.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 16,
                      height: 1.3,
                    ),
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

class _ContactCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _ContactCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

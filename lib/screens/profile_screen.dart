import 'package:delycafe/data/mock_profile.dart';
import 'package:delycafe/ui/components/glass/shader_glass_container.dart';
import 'package:delycafe/ui/tokens/app_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = mockProfile;

    return Scaffold(
      backgroundColor: const Color(0xFFFEF7FF),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.header,
        elevation: 0,
        toolbarHeight: 76,
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
              'Мой профиль',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProfileHeaderCard(profile: profile),
          const SizedBox(height: 16),
          _InfoCard(
            icon: CupertinoIcons.phone,
            title: 'Телефон',
            child: Text(
              profile.phone,
              style: _valueStyle,
            ),
          ),
          const SizedBox(height: 12),
          _InfoCard(
            icon: CupertinoIcons.star_fill,
            title: 'Бонусы',
            child: Text(
              '${profile.points}',
              style: _bigValueStyle.copyWith(
                color: AppColors.header,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _InfoCard(
            icon: CupertinoIcons.location,
            title: 'Адрес доставки',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final address in profile.addresses) ...[
                  _BulletText(text: address),
                  if (address != profile.addresses.last)
                    const SizedBox(height: 10),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _InfoCard(
            icon: CupertinoIcons.cart,
            title: 'История заказов',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Всего заказов: ${profile.ordersCount}',
                  style: _valueStyle,
                ),
                const SizedBox(height: 8),
                Text(
                  'Последний заказ: ${profile.lastOrderDate}',
                  style: _subtleStyle,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _InfoCard(
            icon: CupertinoIcons.heart_fill,
            title: 'Любимый товар ',
            child: Text(
              profile.favoriteItem,
              style: _valueStyle,
            ),
          ),
          const SizedBox(height: 20),
          SafeArea(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(
                  child: Text(
                    'Готово',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
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
}

class _ProfileHeaderCard extends StatelessWidget {
  final dynamic profile;

  const _ProfileHeaderCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.header.withValues(alpha: 0.10),
            ),
            child: const Icon(
              CupertinoIcons.person_fill,
              size: 34,
              color: AppColors.header,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Постоянный клиент',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black.withValues(alpha: 0.58),
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

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.header.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              size: 22,
              color: AppColors.header,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 8),
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletText extends StatelessWidget {
  final String text;

  const _BulletText({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 7),
          child: Icon(
            Icons.circle,
            size: 6,
            color: AppColors.header,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: _valueStyle,
          ),
        ),
      ],
    );
  }
}

const TextStyle _valueStyle = TextStyle(
  fontSize: 16,
  height: 1.5,
  color: Colors.black87,
  fontWeight: FontWeight.w600,
);

const TextStyle _bigValueStyle = TextStyle(
  fontSize: 26,
  fontWeight: FontWeight.w800,
);

const TextStyle _subtleStyle = TextStyle(
  fontSize: 14,
  height: 1.4,
  color: Colors.black54,
);

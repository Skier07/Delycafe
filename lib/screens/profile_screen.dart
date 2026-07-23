import 'package:delycafe/constants/app_features.dart';
import 'package:delycafe/exceptions/auth_required_exception.dart';
import 'package:delycafe/features/auth/auth_screen.dart';
import 'package:delycafe/models/user.dart';
import 'package:delycafe/screens/account_deletion_screen.dart';
import 'package:delycafe/services/auth_service.dart';
import 'package:delycafe/ui/components/buttons/auth_button.dart';
import 'package:delycafe/ui/components/glass/shader_glass_container.dart';
import 'package:delycafe/ui/tokens/app_colors.dart';
import 'package:delycafe/utils/russian_text_input.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;

    final name = _getName(user);
    final phone = _formatPhone(user?.phone ?? '');
    final address = user?.defaultAddress.trim() ?? '';
    final bonuses = user?.bonusBalance ?? 0;

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
      body: RefreshIndicator(
        color: AppColors.header,
        onRefresh: () async {
          await context.read<AuthService>().refreshCurrentUser();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (auth.needsAccessTokenRefresh) ...[
              _SessionRefreshBanner(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AuthScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
            _ProfileHeaderCard(
              name: name,
              subtitle: user == null ? 'Гость' : 'Клиент DelyCafe',
              onEditName: user == null
                  ? null
                  : () {
                      _openEditNameSheet(context, user);
                    },
            ),
            const SizedBox(height: 16),
            _InfoCard(
              icon: CupertinoIcons.phone,
              title: 'Телефон',
              child: Text(
                phone,
                style: _valueStyle,
              ),
            ),
            if (AppFeatures.bonusesEnabled) ...[
              const SizedBox(height: 12),
              _InfoCard(
                icon: CupertinoIcons.star_fill,
                title: 'Бонусы',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$bonuses',
                      style: _bigValueStyle.copyWith(
                        color: AppColors.header,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '1 бонус = 1 ₽',
                      style: _subtleStyle,
                    ),
                  ],
                ),
              ),
            ],
            if (AppFeatures.firstOrderDiscountEnabled) ...[
              const SizedBox(height: 12),
              _InfoCard(
                icon: CupertinoIcons.tag_fill,
                title: 'Скидка первого заказа',
                child: Text(
                  user == null
                      ? 'Войдите в аккаунт, чтобы получить скидку'
                      : user.firstOrderDiscountAvailable
                          ? 'Доступна скидка 20% на первый заказ'
                          : 'Скидка первого заказа уже использована',
                  style: _valueStyle,
                ),
              ),
            ],
            const SizedBox(height: 12),
            _InfoCard(
              icon: CupertinoIcons.location,
              title: 'Адрес доставки',
              child: address.isNotEmpty
                  ? _BulletText(text: address)
                  : const Text(
                      'Адрес не указан',
                      style: _subtleStyle,
                    ),
            ),
            const SizedBox(height: 12),
            const _InfoCard(
              icon: CupertinoIcons.cart,
              title: 'История заказов',
              child: Text(
                'История заказов скоро появится здесь',
                style: _subtleStyle,
              ),
            ),
            if (user != null) ...[
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AccountDeletionScreen(
                          phone: user.phone,
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    'Удалить аккаунт',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
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
      ),
    );
  }

  Future<void> _openEditNameSheet(BuildContext context, User user) async {
    final auth = context.read<AuthService>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) {
        return _EditNameSheet(
          initialName: user.name.trim(),
          onSubmit: auth.updateProfileName,
        );
      },
    );
  }

  String _getName(User? user) {
    if (user == null) {
      return 'Гость';
    }

    if (user.name.trim().isNotEmpty) {
      return user.name.trim();
    }

    return 'Клиент';
  }

  String _formatPhone(String value) {
    final phone = value.trim();

    if (phone.isEmpty) {
      return 'Не указан';
    }

    final digits = phone.replaceAll(RegExp(r'\D'), '');

    if (digits.length == 11 && digits.startsWith('7')) {
      return '+7 (${digits.substring(1, 4)}) '
          '${digits.substring(4, 7)} '
          '${digits.substring(7, 9)} '
          '${digits.substring(9, 11)}';
    }

    return phone;
  }
}

class _EditNameSheet extends StatefulWidget {
  final String initialName;
  final Future<void> Function(String name) onSubmit;

  const _EditNameSheet({
    required this.initialName,
    required this.onSubmit,
  });

  @override
  State<_EditNameSheet> createState() => _EditNameSheetState();
}

class _EditNameSheetState extends State<_EditNameSheet> {
  late final TextEditingController _nameController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: widget.initialName,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final newName = _nameController.text.trim();

    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Введите имя'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.onSubmit(newName);

      if (!mounted) return;

      Navigator.pop(context);
    } on AuthRequiredException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );

      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось сохранить имя: $error'),
        ),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: bottomInset + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Редактировать имя',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            autofocus: true,
            keyboardType: RussianTextInput.text,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (!_isSaving) {
                _saveName();
              }
            },
            decoration: const InputDecoration(
              labelText: 'Имя',
              hintText: 'Например, Роман',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SafeArea(
            child: AuthButton(
              text: _isSaving ? 'Сохраняем...' : 'Сохранить',
              onPressed: _isSaving ? null : _saveName,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  final String name;
  final String subtitle;
  final VoidCallback? onEditName;

  const _ProfileHeaderCard({
    required this.name,
    required this.subtitle,
    required this.onEditName,
  });

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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (onEditName != null)
                      IconButton(
                        onPressed: onEditName,
                        icon: const Icon(
                          CupertinoIcons.pencil,
                          color: AppColors.header,
                          size: 22,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
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

  const _BulletText({
    required this.text,
  });

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

class _SessionRefreshBanner extends StatelessWidget {
  const _SessionRefreshBanner({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Нужно подтвердить вход по SMS',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'PIN и Face ID защищают вход в приложение. Серверная сессия '
            'действует 6 месяцев после входа по SMS. Если сессия истекла — '
            'нужен повторный вход по SMS один раз.',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onPressed,
            child: const Text('Войти по SMS'),
          ),
        ],
      ),
    );
  }
}

import 'package:delycafe/models/bonus_summary.dart';
import 'package:delycafe/services/auth_service.dart';
import 'package:delycafe/services/bonus_api_service.dart';
import 'package:delycafe/ui/components/glass/shader_glass_container.dart';
import 'package:delycafe/ui/tokens/app_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BonusesScreen extends StatefulWidget {
  const BonusesScreen({super.key});

  @override
  State<BonusesScreen> createState() => _BonusesScreenState();
}

class _BonusesScreenState extends State<BonusesScreen> {
  final BonusApiService _bonusApiService = BonusApiService();

  late Future<BonusSummary?> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadBonuses();
  }

  Future<BonusSummary?> _loadBonuses() async {
    final user = context.read<AuthService>().currentUser;

    if (user == null) {
      return null;
    }

    return _bonusApiService.fetchBonuses(
      phone: user.phone,
    );
  }

  Future<void> _refresh() async {
    await context.read<AuthService>().refreshCurrentUser();

    setState(() {
      _future = _loadBonuses();
    });

    await _future;
  }

  @override
  Widget build(BuildContext context) {
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
              'Бонусы',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      body: FutureBuilder<BonusSummary?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CupertinoActivityIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _ErrorState(
              message: snapshot.error.toString(),
              onRetry: () {
                setState(() {
                  _future = _loadBonuses();
                });
              },
            );
          }

          final summary = snapshot.data;

          if (summary == null) {
            return const _EmptyAuthState();
          }

          return RefreshIndicator(
            color: AppColors.header,
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                MediaQuery.of(context).padding.bottom + 24,
              ),
              children: [
                _BalanceCard(summary: summary),
                const SizedBox(height: 14),
                _RulesCard(summary: summary),
                const SizedBox(height: 14),
                const _SectionTitle('История бонусов'),
                const SizedBox(height: 10),
                if (summary.transactions.isEmpty)
                  const _EmptyTransactionsCard()
                else
                  ...summary.transactions.map((transaction) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _TransactionCard(transaction: transaction),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final BonusSummary summary;

  const _BalanceCard({
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.header,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.header.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ваш баланс',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${summary.bonusBalance} бонусов',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '1 бонус = 1 ₽',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (summary.firstOrderDiscountAvailable) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.14),
                ),
              ),
              child: const Text(
                'Доступна скидка 20% на первый заказ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RulesCard extends StatelessWidget {
  final BonusSummary summary;

  const _RulesCard({
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Как работают бонусы'),
          const SizedBox(height: 12),
          _RuleRow(
            icon: CupertinoIcons.plus_circle_fill,
            text: 'После заказа начисляется ${summary.earnPercent}% бонусами.',
          ),
          const SizedBox(height: 10),
          _RuleRow(
            icon: CupertinoIcons.creditcard_fill,
            text:
                'Бонусами можно оплатить до ${summary.maxSpendPercent}% суммы товаров.',
          ),
          const SizedBox(height: 10),
          const _RuleRow(
            icon: CupertinoIcons.car_detailed,
            text: 'На доставку бонусы не списываются.',
          ),
          const SizedBox(height: 10),
          const _RuleRow(
            icon: CupertinoIcons.tag_fill,
            text: 'Бонусы не списываются вместе со скидкой первого заказа.',
          ),
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _RuleRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: AppColors.header,
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.70),
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final BonusTransactionItem transaction;

  const _TransactionCard({
    required this.transaction,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = transaction.amount > 0;

    final amountText =
        isPositive ? '+${transaction.amount}' : '${transaction.amount}';

    return _WhiteCard(
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isPositive
                  ? Colors.green.withValues(alpha: 0.10)
                  : Colors.red.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isPositive
                  ? CupertinoIcons.arrow_down_circle_fill
                  : CupertinoIcons.arrow_up_circle_fill,
              color: isPositive ? Colors.green : Colors.red,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.comment.isNotEmpty
                      ? transaction.comment
                      : transaction.transactionTypeLabel,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(transaction.createdAt),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black.withValues(alpha: 0.52),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            amountText,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: isPositive ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return '';
    }

    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();

    return '$day.$month.$year';
  }
}

class _EmptyTransactionsCard extends StatelessWidget {
  const _EmptyTransactionsCard();

  @override
  Widget build(BuildContext context) {
    return const _WhiteCard(
      child: Text(
        'История бонусов пока пустая. После первого заказа здесь появятся начисления.',
        style: TextStyle(
          fontSize: 14.5,
          height: 1.4,
          color: Colors.black54,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyAuthState extends StatelessWidget {
  const _EmptyAuthState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Войдите в аккаунт, чтобы видеть бонусы.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            height: 1.4,
            color: Colors.black54,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.wifi_slash,
              size: 52,
              color: AppColors.header,
            ),
            const SizedBox(height: 14),
            const Text(
              'Не удалось загрузить бонусы',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WhiteCard extends StatelessWidget {
  final Widget child;

  const _WhiteCard({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.055),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w900,
        color: Colors.black87,
      ),
    );
  }
}

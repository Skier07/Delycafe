import 'package:delycafe/ui/components/glass/shader_glass_container.dart';
import 'package:delycafe/ui/tokens/app_colors.dart';
import 'package:delycafe/utils/delivery_schedule.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class DeliveryScreen extends StatelessWidget {
  const DeliveryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEF7FF),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.header,
        elevation: 0,
        toolbarHeight: 60,
        leadingWidth: 60,
        leading: Padding(
          padding: const EdgeInsets.all(8),
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
        title: const Text('Доставка и оплата'),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 22,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionCard(
            title: 'Время работы',
            content: 'Приём заказов в приложении: с 10:00.\n'
                'Закрытие приёма: ${DeliverySchedule.acceptanceHoursShort}.\n\n'
                'Минимальное время доставки: 1,5 часа (в Татыш — 2 часа).',
          ),
          const SizedBox(height: 16),
          const _SectionCard(
            title: 'Доставка и оплата',
            content: 'Оплата возможна через Мир, Visa, Mastercard и СБП.\n\n'
                'Все платежи защищены SSL.\n'
                'Данные карты не сохраняются.',
          ),
          const SizedBox(height: 16),
          const _SectionCard(
            title: 'Заказ по телефону',
            content: '+7 (900) 022-30-22\n\n'
                'При заказе от 3000₽ — предоплата.\n'
                'Можно оплатить в кафе.',
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Доставка по Озёрску',
            content: 'от 1700₽ — бесплатно\n'
                'от 1000 до 1700₽ — доставка 200₽\n'
                '< 1000₽ — доставка 250₽\n\n'
                '${DeliverySchedule.acceptanceHoursLong}',
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Доставка в Татыш',
            content: 'Стоимость: 450₽\n'
                'Минимум: 2 часа\n'
                '${DeliverySchedule.acceptanceHoursLong}',
          ),
          const SizedBox(height: 16),
          const _WarningCard(
            text: 'Если нет лифта — подъём до 5 этажа бесплатный.\n'
                'Далее — 50₽/этаж.',
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String content;

  const _SectionCard({
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(3, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              height: 1.5,
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  final String text;

  const _WarningCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.red.withValues(alpha: 0.08),
          border: Border.all(
            color: Colors.red.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

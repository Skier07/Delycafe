import 'package:delycafe/ui/components/glass/shader_glass_container.dart';
import 'package:delycafe/ui/tokens/app_colors.dart';
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
        title: const Text('Оплата и доставка'),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 22,
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              _SectionCard(
                title: 'Время работы',
                content:
                    'Мы работаем с понедельника по четверг с 9 до 21 часа.\n'
                    'В пятницу и субботу — с 9 до 22.\n'
                    'В воскресенье — с 9 до 21.\n\n'
                    'Кухня закрывается за 30 минут до конца рабочего дня.',
              ),
              SizedBox(height: 16),
              _SectionCard(
                title: 'Доставка и оплата',
                content:
                    'Оплата возможна через Мир, Visa, Mastercard и СБП.\n\n'
                    'Все платежи защищены SSL.\n'
                    'Данные карты не сохраняются.',
              ),
              SizedBox(height: 16),
              _SectionCard(
                title: 'Заказ по телефону',
                content: '+7 (900) 022-30-22\n\n'
                    'При заказе от 3000₽ — предоплата.\n'
                    'Можно оплатить в кафе.',
              ),
              SizedBox(height: 16),
              _SectionCard(
                title: 'Доставка по Озёрску',
                content: 'от 1700₽ — бесплатно\n'
                    'от 1000 до 1700₽ — доставка 200₽\n'
                    '< 1000₽ — доставка 250₽\n\n'
                    'Приём заказов: 9:00 — 20:00',
              ),
              SizedBox(height: 16),
              _SectionCard(
                title: 'Доставка в Татыш',
                content: 'Стоимость: 450₽\n'
                    'Минимум: 2 часа\n'
                    'Заказы: 9:00–19:00',
              ),
              SizedBox(height: 16),
              _WarningCard(
                text: 'Если нет лифта — подъём до 5 этажа бесплатный.\n'
                    'Далее — 50₽/этаж.',
              ),
            ],
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
    return ShaderGlassContainer(
      borderRadius: 20,
      padding: const EdgeInsets.all(16),
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
    return Container(
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
    );
  }
}

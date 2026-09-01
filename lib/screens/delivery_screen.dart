import 'dart:async';

import 'package:delycafe/models/delivery_config.dart';
import 'package:delycafe/services/delivery_config_service.dart';
import 'package:delycafe/ui/components/glass/shader_glass_container.dart';
import 'package:delycafe/ui/tokens/app_colors.dart';
import 'package:delycafe/utils/delivery_schedule.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class DeliveryScreen extends StatefulWidget {
  const DeliveryScreen({super.key});

  @override
  State<DeliveryScreen> createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  DeliveryConfig? _config;

  @override
  void initState() {
    super.initState();
    unawaited(_loadConfig());
  }

  Future<void> _loadConfig() async {
    final config = await DeliveryConfigService.instance.fetch();

    if (!mounted) {
      return;
    }

    setState(() {
      _config = config;
    });
  }

  String _minLeadTimeLabel(DeliveryConfig config) {
    final minutes = config.zones
        .where((zone) => zone.requiresAddress)
        .map((zone) => zone.leadMinutes)
        .fold<int?>(null, (current, value) {
      if (current == null || value < current) {
        return value;
      }

      return current;
    });

    if (minutes == null) {
      return '1,5 часа';
    }

    if (minutes % 60 == 0) {
      final hours = minutes ~/ 60;
      return '$hours ${_hoursLabel(hours)}';
    }

    if (minutes > 60) {
      final hours = minutes ~/ 60;
      final rest = minutes % 60;

      return '$hours ${_hoursLabel(hours)} $rest мин';
    }

    return '$minutes мин';
  }

  String _hoursLabel(int hours) {
    if (hours == 1) {
      return 'час';
    }

    if (hours >= 2 && hours <= 4) {
      return 'часа';
    }

    return 'часов';
  }

  @override
  Widget build(BuildContext context) {
    final config = _config ?? DeliveryConfig.fallback();
    final sections = config.infoSections;

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
                'Минимальное время доставки: ${_minLeadTimeLabel(config)}.',
          ),
          const SizedBox(height: 16),
          if (sections.isEmpty)
            ..._fallbackSections(config)
          else
            ...sections.map((section) {
              if (section.isWarning) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _WarningCard(text: section.content),
                );
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _SectionCard(
                  title: section.title,
                  content: section.content,
                ),
              );
            }),
        ],
      ),
    );
  }

  List<Widget> _fallbackSections(DeliveryConfig config) {
    return [
      const _SectionCard(
        title: 'Доставка и оплата',
        content: 'Оплата возможна через Мир, Visa, Mastercard и СБП.\n\n'
            'Все платежи защищены SSL.\n'
            'Данные карты не сохраняются.',
      ),
      const SizedBox(height: 16),
      ...config.zones.where((zone) => zone.requiresAddress).map((zone) {
        final content = zone.checkoutDescription.trim().isNotEmpty
            ? zone.checkoutDescription
            : zone.title;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _SectionCard(
            title: 'Доставка: ${zone.title}',
            content: '$content\n\n${DeliverySchedule.acceptanceHoursLong}',
          ),
        );
      }),
    ];
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
          if (title.trim().isNotEmpty) ...[
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
          ],
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

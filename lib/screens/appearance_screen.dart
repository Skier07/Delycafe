import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:delycafe/services/glass_settings.dart';
import 'package:delycafe/ui/components/glass/glass_back_button.dart';

class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});
  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  bool _saving = false;
  @override
  Widget build(BuildContext context) {
    final supported = ui.ImageFilter.isShaderFilterSupported &&
        const bool.fromEnvironment('LIQUID_GLASS', defaultValue: true) &&
        !MediaQuery.highContrastOf(context);
    return Scaffold(
      appBar: AppBar(
          title: const Text('Оформление'),
          leading: const Center(child: GlassBackButton(lightBackground: true))),
      body: ListenableBuilder(
          listenable: GlassSettings.instance,
          builder: (context, _) => ListView(children: [
                SwitchListTile(
                  title: const Text('Liquid Glass'),
                  subtitle: Text(supported
                      ? 'Преломление фона. Если прокрутка тормозит или кнопки мерцают, выключите: останется обычное размытие.'
                      : 'Сейчас доступно обычное размытие. Преломление не поддерживается устройством или отключено настройками доступности.'),
                  value: supported && GlassSettings.instance.enabled,
                  onChanged: !supported || _saving
                      ? null
                      : (value) async {
                          setState(() => _saving = true);
                          try {
                            await GlassSettings.instance.setEnabled(value);
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Не удалось сохранить настройку. Попробуйте ещё раз.')));
                            }
                          } finally {
                            if (mounted) setState(() => _saving = false);
                          }
                        },
                ),
              ])),
    );
  }
}

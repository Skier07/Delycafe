import 'package:flutter/material.dart';

class PromoScreen extends StatelessWidget {
  const PromoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '🎁 Акций пока нет\n'
        'Но мы уже готовим для вас что-то вкусное 😏',
        style: TextStyle(
          fontSize: 16,
          color: Colors.black54,
        ),
      ),
    );
  }
}

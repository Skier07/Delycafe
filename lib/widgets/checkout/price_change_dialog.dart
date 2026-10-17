import 'package:flutter/material.dart';

Future<bool> confirmCheckoutPriceChange(
  BuildContext context, {
  required int previousAmount,
  required int currentAmount,
}) async {
  if (previousAmount == currentAmount) return true;
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Сумма заказа обновилась'),
          content: Text(
            'Мы уточнили стоимость заказа.\n\n'
            'Было: $previousAmount ₽\n'
            'Теперь к оплате: $currentAmount ₽',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Вернуться к заказу'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Продолжить за $currentAmount ₽'),
            ),
          ],
        ),
      ) ??
      false;
}

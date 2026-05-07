import 'package:flutter/material.dart';

class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key});

  static const textStyleL = TextStyle(
      fontFamily: 'RobotoCondensed',
      fontWeight: FontWeight.w700,
      fontSize: 40,
      letterSpacing: -1.5,
      color: Color.fromRGBO(22, 24, 31, 0.8));

  static const textStyleS = TextStyle(
      fontWeight: FontWeight.w700,
      letterSpacing: 1,
      fontSize: 15,
      color: Color.fromRGBO(22, 24, 31, 0.4));

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 25),
          Text(
            'ВВЕДИ СВОЙ НОМЕР',
            style: textStyleL,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 25),
          Text(
            'Чтобы копить баллы,\n применять скидки\n и оформлять заказы',
            style: textStyleS,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 25),
        ],
      ),
    );
  }
}

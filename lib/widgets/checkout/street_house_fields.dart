import 'package:delycafe/utils/russian_text_input.dart';
import 'package:delycafe/utils/street_house_address.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class StreetHouseFields extends StatelessWidget {
  const StreetHouseFields({
    super.key,
    required this.streetController,
    required this.houseController,
    required this.decoration,
  });

  final TextEditingController streetController;
  final TextEditingController houseController;
  final InputDecoration Function(String label) decoration;

  @override
  Widget build(BuildContext context) {
    final street = TextFormField(
      controller: streetController,
      keyboardType: RussianTextInput.text,
      inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[0-9]'))],
      hintLocales: RussianTextInput.hintLocales,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.next,
      decoration: decoration('Улица').copyWith(errorMaxLines: 3),
      validator: (value) {
        final street = (value ?? '').trim();
        if (street.isEmpty) return 'Укажите улицу';
        // Controllers restored from saved addresses bypass input formatters.
        if (RegExp(r'[0-9]').hasMatch(street)) {
          return 'Уберите цифры из улицы';
        }
        return null;
      },
    );
    final house = TextFormField(
      controller: houseController,
      // Letters and slashes are valid: 12А, 12/1, 12 корп. 2.
      keyboardType: RussianTextInput.text,
      hintLocales: RussianTextInput.hintLocales,
      textCapitalization: TextCapitalization.characters,
      textInputAction: TextInputAction.next,
      decoration: decoration('Дом').copyWith(errorMaxLines: 2),
      validator: validateHouseNumber,
    );
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 300 ||
          MediaQuery.textScalerOf(context).scale(14) > 19) {
        return Column(children: [street, const SizedBox(height: 12), house]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 5, child: street),
          const SizedBox(width: 12),
          Expanded(flex: 3, child: house),
        ],
      );
    });
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PhoneInput extends StatefulWidget {
  final TextEditingController controller;
  final String? Function(String?)? validator;

  const PhoneInput({super.key, required this.controller, this.validator});

  @override
  State<PhoneInput> createState() => _PhoneInputState();
}

class _PhoneInputState extends State<PhoneInput> {
  late FocusNode _focusNode;
  // static const String _countryCode = '7 ';

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();

    _focusNode.addListener(() {
      if (_focusNode.hasFocus && widget.controller.text.isEmpty) {
        // widget.controller.text = _countryCode;
        widget.controller.selection = TextSelection.fromPosition(
          TextPosition(offset: widget.controller.text.length),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      validator: widget.validator,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        PhoneInputFormatter(),
      ],
      decoration: InputDecoration(
        hintText: '000 000 00 00',
        prefixText: '+7 ',
        // labelText: '+7 000 000 0000',
        // floatingLabelBehavior: FloatingLabelBehavior.auto,
        filled: true,
        prefixIcon: const Icon(CupertinoIcons.phone),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // сколько цифр было ДО курсора
    var digitsBeforeCursor = _countDigits(
      newValue.text.substring(0, newValue.selection.start),
    );

    // все цифры
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');

    // убираем 7 если вставили с кодом страны
    if (digits.length == 11 && digits.startsWith('7')) {
      digits = digits.substring(1);
    }

    // ограничение
    if (digits.length > 10) {
      digits = digits.substring(0, 10);
    }

    // форматируем
    final formatted = _format(digits);

    // пересчитываем позицию курсора
    var newCursorPosition = _calculateCursorPosition(
      formatted,
      digitsBeforeCursor,
    );

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newCursorPosition),
    );
  }

  // считаем только цифры
  int _countDigits(String text) {
    return text.replaceAll(RegExp(r'\D'), '').length;
  }

  // формат: 000 000 00 00
  String _format(String digits) {
    final buffer = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      if (i == 3 || i == 6 || i == 8) {
        buffer.write(' ');
      }
      buffer.write(digits[i]);
    }

    return buffer.toString();
  }

  // позиция курсора
  int _calculateCursorPosition(String formatted, int digitIndex) {
    int digitCount = 0;

    for (int i = 0; i < formatted.length; i++) {
      if (RegExp(r'\d').hasMatch(formatted[i])) {
        digitCount++;
      }

      if (digitCount == digitIndex) {
        return i + 1;
      }
    }

    return formatted.length;
  }
}

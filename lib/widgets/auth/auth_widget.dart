/* import 'package:flutter/material.dart';

class AuthWidget extends StatefulWidget {
  const AuthWidget({super.key});

  @override
  _AuthWidgetState createState() => _AuthWidgetState();
}

class _AuthWidgetState extends State<AuthWidget> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('DelyCafe', style: TextStyle(color: Colors.white)),
      ),
      body: ListView(children: [_HeaderWidget()]),
    );
  }
}

class _HeaderWidget extends StatelessWidget {
  const _HeaderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final textStyleL = const TextStyle(
        fontFamily: 'RobotoCondensed',
        fontWeight: FontWeight.w700,
        fontSize: 40,
        letterSpacing: -1.5,
        color: Color.fromRGBO(22, 24, 31, 0.8));

    final textStyleS = const TextStyle(
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
        fontSize: 15,
        color: Color.fromRGBO(22, 24, 31, 0.4));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          SizedBox(height: 25),
          Text('ВВЕДИ СВОЙ НОМЕР', style: textStyleL),
          SizedBox(height: 25),
          Text('Чтобы копить баллы,\n применять скидки и\n оформлять заказы',
              style: textStyleS),
          SizedBox(height: 25),
          _FormWidget(),
        ],
      ),
    );
  }
}

class _FormWidget extends StatefulWidget {
  const _FormWidget({super.key});

  @override
  State<_FormWidget> createState() => __FormWidgetState();
}

class __FormWidgetState extends State<_FormWidget> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PhoneInput(controller: _phoneController),
          const SizedBox(height: 20),
          _SubmitButton(
            onPressed: _onSubmit,
          ),
        ],
      ),
    );
  }

  void _onSubmit() {
    if (_formKey.currentState!.validate()) {
      final phone = _phoneController.text;
      debugPrint(phone);
    }
  }
}

class _PhoneInput extends StatefulWidget {
  final TextEditingController controller;

  const _PhoneInput({super.key, required this.controller});

  @override
  State<_PhoneInput> createState() => _PhoneInputState();
}

class _PhoneInputState extends State<_PhoneInput> {
  late FocusNode _focusNode;
  static const String _countryCode = '+7 ';

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();

    _focusNode.addListener(() {
      if (_focusNode.hasFocus && widget.controller.text.isEmpty) {
        _insertCountryCode();
      }
    });
  }

  void _insertCountryCode() {
    widget.controller.text = _countryCode;
    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: widget.controller.text.length),
    );
  }

  void _protectCountryCode(String value) {
    // если пользователь всё стёр — очищаем поле полностью
    if (value.isEmpty) {
      return;
    }

    // если пытается стереть +7 — возвращаем его
    if (!value.startsWith(_countryCode)) {
      _insertCountryCode();
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      keyboardType: TextInputType.phone,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: '+7 000 000 0000',
        hintStyle: const TextStyle(
          color: Color.fromRGBO(26, 23, 18, 0.298),
        ),
        filled: true,
        fillColor: const Color.fromRGBO(100, 130, 170, 0.100),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: _protectCountryCode,
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _SubmitButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final textStyleB = const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      letterSpacing: 3,
      color: Color.fromRGBO(252, 252, 252, 0.8),
    );

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        backgroundColor: const Color.fromRGBO(2, 141, 255, 1),
      ),
      child: Text('Продолжить', style: textStyleB),
    );
  }
}
 */
